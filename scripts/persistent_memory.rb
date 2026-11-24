#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'pathname'
require 'yaml'

module PersistentMemory
  CONFIG = 'config/persistent-memory.yml'
  MODES = %w[ai-memory local].freeze

  class ConfigError < StandardError; end

  def self.load_config(root:, home: Dir.home)
    root = File.realpath(root)
    path = File.join(root, CONFIG)
    raise ConfigError, "configuração ausente: #{CONFIG}" unless File.file?(path)
    raise ConfigError, "configuração fora da raiz: #{CONFIG}" unless File.realpath(path).start_with?(root + File::SEPARATOR)

    source = File.read(path, encoding: 'UTF-8')
    document = Psych.parse(source)
    mapping = document&.root
    raise ConfigError, 'configuração deve ser um mapping' unless mapping.is_a?(Psych::Nodes::Mapping)

    keys = mapping.children.each_slice(2).map { |key, _value| key.value }
    raise ConfigError, 'chaves duplicadas na configuração de memória' unless keys.uniq == keys

    data = YAML.safe_load(source, permitted_classes: [], permitted_symbols: [], aliases: false)
    raise ConfigError, 'chaves inválidas na configuração de memória' unless data.is_a?(Hash) && data.keys.sort == %w[local_vault mode version]
    raise ConfigError, 'version deve ser 1' unless data['version'] == 1
    raise ConfigError, 'mode deve ser ai-memory ou local' unless MODES.include?(data['mode'])
    vault = data['local_vault']
    raise ConfigError, 'local_vault deve ser caminho absoluto ou ~/...' unless vault.is_a?(String) && (vault.start_with?('~/') || Pathname.new(vault).absolute?)

    { mode: data['mode'], local_vault: File.expand_path(vault.sub(/\A~(?=\/)/, home)) }
  rescue Psych::Exception => e
    raise ConfigError, "YAML inválido na configuração de memória: #{e.class}"
  rescue SystemCallError => e
    raise ConfigError, "configuração de memória inacessível: #{e.class}"
  end

  def self.resolve(root:, home: Dir.home, project_dir: Dir.pwd)
    config = load_config(root: root, home: home)
    integrations = ai_memory_integrations(home, project_dir: project_dir)
    effective = config[:mode] == 'local' && !integrations.empty? ? 'ai-memory' : config[:mode]
    {
      configured_mode: config[:mode], effective_mode: effective,
      local_vault: config[:local_vault], local_enabled: effective == 'local',
      ai_memory_integrations: integrations
    }
  end

  def self.ai_memory_integrations(home, project_dir:)
    found = []
    codex_config = File.join(home, '.codex/config.toml')
    if File.file?(codex_config) && File.read(codex_config, encoding: 'UTF-8').match?(/^\s*\[mcp_servers\.(?:"ai-memory"|ai-memory)\]/)
      found << 'codex-mcp'
    end
    found << 'codex-hooks' if hooks_include_ai_memory?(File.join(home, '.codex/hooks.json'))

    claude = read_json(File.join(home, '.claude.json'))
    if claude && (mcp_registered?(claude) || (claude['projects'].is_a?(Hash) && claude['projects'].values.any? { |project| mcp_registered?(project) }))
      found << 'claude-mcp'
    end
    found << 'claude-hooks' if hooks_include_ai_memory?(File.join(home, '.claude/settings.json'))

    antigravity = read_json(File.join(home, '.gemini/config/mcp_config.json'))
    found << 'antigravity-mcp' if mcp_registered?(antigravity)
    found << 'antigravity-hooks' if hooks_include_ai_memory?(File.join(home, '.gemini/config/hooks.json'))

    project_codex = File.join(project_dir, '.codex/config.toml')
    if File.file?(project_codex) && File.read(project_codex, encoding: 'UTF-8').match?(/^\s*\[mcp_servers\.(?:"ai-memory"|ai-memory)\]/)
      found << 'project-codex-mcp'
    end
    found << 'project-codex-hooks' if hooks_include_ai_memory?(File.join(project_dir, '.codex/hooks.json'))
    found << 'project-claude-mcp' if mcp_registered?(read_json(File.join(project_dir, '.mcp.json')))
    %w[settings.json settings.local.json].each do |name|
      found << 'project-claude-hooks' if hooks_include_ai_memory?(File.join(project_dir, '.claude', name))
    end
    found << 'project-antigravity-mcp' if mcp_registered?(read_json(File.join(project_dir, '.gemini/config/mcp_config.json')))
    found << 'project-antigravity-hooks' if hooks_include_ai_memory?(File.join(project_dir, '.gemini/config/hooks.json'))
    found.uniq
  rescue SystemCallError, JSON::ParserError => e
    raise ConfigError, "não foi possível verificar integrações ai-memory: #{e.class}"
  end

  def self.read_json(path)
    return nil unless File.file?(path)

    JSON.parse(File.read(path, encoding: 'UTF-8'))
  end

  def self.mcp_registered?(data)
    data.is_a?(Hash) && data['mcpServers'].is_a?(Hash) && data['mcpServers'].key?('ai-memory')
  end

  def self.hooks_include_ai_memory?(path)
    data = read_json(path)
    data.is_a?(Hash) && contains_ai_memory?(File.basename(path) == 'hooks.json' ? data : data['hooks'])
  end

  def self.contains_ai_memory?(value)
    case value
    when Hash then value.any? { |key, child| key.to_s.include?('ai-memory') || contains_ai_memory?(child) }
    when Array then value.any? { |child| contains_ai_memory?(child) }
    when String then value.include?('ai-memory')
    else false
    end
  end
end
