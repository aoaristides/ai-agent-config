#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'optparse'
require 'tempfile'
require_relative 'context_compiler'
require_relative 'validate_structure'

module AgentInstallation
  BEGIN_MARK = '<!-- ai-agent-config:begin -->'
  END_MARK = '<!-- ai-agent-config:end -->'
  AGENTS = %w[codex claude cursor antigravity].freeze

  def self.run(args)
    options = { apply: false, agents: AGENTS }
    parser = OptionParser.new do |opts|
      opts.banner = 'Uso: ruby scripts/install-agents.rb (--project DIR | --user) [--agents LISTA] [--apply]'
      opts.on('--project DIR') { |v| options[:project] = File.expand_path(v) }
      opts.on('--user') { options[:user] = true }
      opts.on('--agents LISTA', Array) { |v| options[:agents] = v }
      opts.on('--apply') { options[:apply] = true }
      opts.on('-h', '--help') { puts opts; return 0 }
    end
    parser.parse!(args)
    raise ArgumentError, parser.banner unless args.empty? && (!!options[:project] ^ !!options[:user])
    raise ArgumentError, 'agente desconhecido ou lista vazia' if options[:agents].empty? || (options[:agents] - AGENTS).any?
    root = File.realpath(File.join(__dir__, '..'))
    errors = StructureValidation.validate(root)
    raise ArgumentError, errors.join("\n") unless errors.empty?
    if options[:project] && !File.directory?(options[:project])
      raise ArgumentError, 'o projeto de destino deve existir'
    end
    base = options[:project] ? File.realpath(options[:project]) : File.realpath(Dir.home)
    context_for = lambda do |agent|
      adapter = { 'cursor' => 'codex' }.fetch(agent, agent)
      compiled = ContextCompiler.render(root: root, adapter: adapter, root_label: root)
      "#{BEGIN_MARK}\n#{compiled}\nDestino padrão das trilhas pessoais: `#{root}/learning/`; " \
        "o pedido do usuário prevalece.\n#{END_MARK}\n"
    end
    edits = {}
    links = {}
    skills = Dir.children(File.join(root, 'skills')).sort.select { |n| File.directory?(File.join(root, 'skills', n)) }
    options[:agents].each do |agent|
      if options[:user]
        skill_path = { 'codex' => '.agents/skills', 'claude' => '.claude/skills',
                       'cursor' => '.agents/skills',
                       'antigravity' => '.gemini/config/skills' }.fetch(agent)
        # Não crie uma segunda descoberta para os links legados já usados pelo Codex.
        if agent == 'codex' && skills.any? { |n| same_link?(File.join(base, '.codex/skills', n), File.join(root, 'skills', n)) }
          skill_path = '.codex/skills'
          puts '[install-agents] Codex: reutilizando diretório legado já conectado à fonte.'
        end
        rule_path = { 'codex' => '.codex/AGENTS.md', 'claude' => '.claude/CLAUDE.md',
                      'antigravity' => '.gemini/GEMINI.md' }[agent]
        if agent == 'cursor'
          puts '[install-agents] Cursor: skills pessoais; use --project para instalar regras de projeto.'
        end
      else
        skill_path = agent == 'claude' ? '.claude/skills' : '.agents/skills'
        rule_path = { 'codex' => 'AGENTS.md', 'claude' => 'CLAUDE.md', 'cursor' => 'AGENTS.md',
                      'antigravity' => '.agents/rules/ai-agent-config.md' }.fetch(agent)
      end
      skills.each { |name| links[File.join(base, skill_path, name)] = File.join(root, 'skills', name) }
      next unless rule_path
      target = File.join(base, rule_path)
      # Claude recebe import nativo; os demais recebem o núcleo expandido.
      if options[:project] && agent == 'claude'
        edits[File.join(base, 'AGENTS.md')] = context_for.call('codex')
        edits[target] = "#{BEGIN_MARK}\n@AGENTS.md\n#{END_MARK}\n"
      else
        edits[target] = context_for.call(agent)
      end
    end
    # Hooks e settings são do escopo pessoal do Claude: o link é absoluto e o settings.json de projeto é versionado.
    personal_claude = options[:user] && options[:agents].include?('claude')
    hooks = personal_claude ? StructureValidation.claude_hooks(root) : []
    defaults = personal_claude ? StructureValidation.claude_settings(root) : {}
    hooks.each do |hook|
      links[File.join(base, '.claude/hooks', hook['file'])] = File.join(root, 'adapters/claude/hooks', hook['file'])
    end
    planned = []
    links.each do |target, source|
      next if same_link?(target, source)
      raise ArgumentError, "conflito, preservado: #{target}" if File.exist?(target) || File.symlink?(target)
      reject_symlink_ancestors!(target, base)
      planned << [:link, target, source, nil, nil]
    end
    edits.each do |target, block|
      reject_symlink_ancestors!(target, base)
      raise ArgumentError, "arquivo de regras é symlink ou diretório, preservado: #{target}" if File.symlink?(target) || File.directory?(target)
      old = File.file?(target) ? File.read(target, encoding: 'UTF-8') : nil
      text = old || ''
      managed = text.include?(BEGIN_MARK) || text.include?(END_MARK)
      if managed
        unless text.scan(BEGIN_MARK).length == 1 && text.scan(END_MARK).length == 1 && text.index(BEGIN_MARK) < text.index(END_MARK)
          raise ArgumentError, "bloco gerenciado ambíguo, preservado: #{target}"
        end
        updated = text.sub(/#{Regexp.escape(BEGIN_MARK)}.*?#{Regexp.escape(END_MARK)}\n?/m) { block }
      else
        updated = text + (text.empty? ? '' : "\n\n") + block
      end
      next if updated == text
      backup = old && !managed ? target + '.ai-agent-config.bak' : nil
      if backup && (File.exist?(backup) || File.symlink?(backup))
        raise ArgumentError, "backup já existe, preservado: #{backup}"
      end
      planned << [:rules, target, updated, old, backup]
    end
    unless hooks.empty? && defaults.empty?
      target = File.join(base, '.claude/settings.json')
      reject_symlink_ancestors!(target, base)
      raise ArgumentError, "settings é symlink ou diretório, preservado: #{target}" if File.symlink?(target) || File.directory?(target)
      old = File.file?(target) ? File.read(target, encoding: 'UTF-8') : nil
      updated, overwritten = configure_settings(old, hooks, defaults, target)
      overwritten.each { |key| puts "[install-agents] settings: #{key} tem outro valor e será sobrescrito." }
      if updated
        # Sem bloco gerenciado em JSON: o backup guarda o estado anterior à primeira alteração e nunca é substituído.
        backup = target + '.ai-agent-config.bak'
        backup = nil if old.nil? || File.exist?(backup) || File.symlink?(backup)
        planned << [:settings, target, updated, old, backup]
      end
    end
    planned.each { |kind, target, _value, _old, _backup| puts "[install-agents] #{kind}: #{target}" }
    puts "[install-agents] #{planned.length} alteração(ões); #{options[:apply] ? 'aplicando' : 'somente plano; use --apply'}."
    return 0 unless options[:apply]
    planned.each do |kind, target, value, old, backup|
      FileUtils.mkdir_p(File.dirname(target))
      reject_symlink_ancestors!(target, base)
      if kind == :link
        File.symlink(value, target) # Falha se outro processo criou o alvo após o plano.
      else
        current = File.file?(target) ? File.read(target, encoding: 'UTF-8') : nil
        unless current == old && !File.symlink?(target) && !File.directory?(target)
          raise ArgumentError, "mudança concorrente, interrompido: #{target}"
        end
        if backup
          raise ArgumentError, "backup já existe, preservado: #{backup}" if File.exist?(backup) || File.symlink?(backup)
          File.open(backup, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(old) }
        end
        Tempfile.create(['.ai-agent-config-', '.tmp'], File.dirname(target)) do |temp|
          temp.set_encoding(Encoding::UTF_8)
          temp.write(value)
          temp.flush
          File.chmod(old ? File.stat(target).mode & 0o777 : 0o644, temp.path)
          File.rename(temp.path, target)
        end
      end
    end
    if options[:agents].include?('antigravity') && options[:project]
      puts '[install-agents] Antigravity: confira a regra ai-agent-config na UI e selecione Always On; ativação não certificada por arquivo.'
    end
    puts '[install-agents] Concluído. Abra nova sessão e confira skills, regras e eventuais aliases duplicados do host.'
    0
  rescue ArgumentError, ContextCompiler::ConfigError, OptionParser::ParseError, SystemCallError => e
    warn "[install-agents] #{e.message}"
    1
  end

  # Devolve [settings.json atualizado ou nil se nada muda, chaves existentes que serão sobrescritas].
  # Hooks só são acrescentados; as chaves de `defaults` são impostas; o restante é preservado.
  def self.configure_settings(text, hooks, defaults, target)
    data = text.nil? || text.strip.empty? ? {} : JSON.parse(text)
    raise ArgumentError, "settings com formato inesperado, preservado: #{target}" unless data.is_a?(Hash)

    overwritten = []
    changed = impose_settings(data, defaults, [], overwritten)
    changed = register_hooks(data, hooks, target) || changed
    return [nil, overwritten] unless changed

    [JSON.pretty_generate(data) + (text.nil? || text.end_with?("\n") ? "\n" : ''), overwritten]
  rescue JSON::ParserError
    raise ArgumentError, "settings não é JSON válido, preservado: #{target}"
  end

  def self.impose_settings(node, desired, path, overwritten)
    desired.reduce(false) do |changed, (key, value)|
      here = path + [key]
      if value.is_a?(Hash)
        unless node[key].is_a?(Hash)
          overwritten << here.join('.') if node.key?(key)
          node[key] = {}
          changed = true
        end
        impose_settings(node[key], value, here, overwritten) || changed
      elsif node.key?(key) && node[key] == value
        changed
      else
        overwritten << here.join('.') if node.key?(key)
        node[key] = value
        true
      end
    end
  end

  def self.register_hooks(data, hooks, target)
    return false if hooks.empty?

    registry = data['hooks'] ||= {}
    raise ArgumentError, "hooks com formato inesperado, preservado: #{target}" unless registry.is_a?(Hash)

    hooks.reduce(false) do |changed, hook|
      groups = registry[hook['event']] ||= []
      unless groups.is_a?(Array) && groups.all? { |g| g.is_a?(Hash) && (g['hooks'].nil? || g['hooks'].is_a?(Array)) }
        raise ArgumentError, "hooks.#{hook['event']} com formato inesperado, preservado: #{target}"
      end
      installed = "/.claude/hooks/#{hook['file']}"
      next changed if groups.any? { |g| Array(g['hooks']).any? { |h| h.is_a?(Hash) && h['command'].to_s.include?(installed) } }

      group = groups.find { |g| g['matcher'] == hook['matcher'] }
      groups << (group = { 'matcher' => hook['matcher'], 'hooks' => [] }) unless group
      (group['hooks'] ||= []) << { 'type' => 'command', 'command' => "$HOME#{installed}" }
      true
    end
  end

  def self.same_link?(target, source)
    File.symlink?(target) && File.realpath(target) == File.realpath(source)
  rescue Errno::ENOENT
    false
  end

  def self.reject_symlink_ancestors!(target, base)
    base = File.expand_path(base)
    parent = File.dirname(File.expand_path(target))
    loop do
      unless parent == base || parent.start_with?(base + File::SEPARATOR)
        raise ArgumentError, "diretório pai saiu da raiz de instalação: #{parent}"
      end
      raise ArgumentError, "diretório pai é symlink; revise o destino: #{parent}" if File.symlink?(parent)
      break if parent == base

      ancestor = File.dirname(parent)
      raise ArgumentError, "diretório pai inválido: #{parent}" if ancestor == parent
      parent = ancestor
    end
  end
end

exit AgentInstallation.run(ARGV) if $PROGRAM_NAME == __FILE__
