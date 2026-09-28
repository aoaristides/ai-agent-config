#!/usr/bin/env ruby
# frozen_string_literal: true

require 'pathname'
require 'yaml'

module ContextCompiler
  GENERATED_MARK = '<!-- generated-by: ai-agent-config/context-compiler -->'
  MANIFEST = 'config/context-manifest.yml'
  SLUG = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/

  class ConfigError < StandardError; end

  def self.load_config(root)
    root = File.realpath(root)
    manifest_path = existing_path(root, MANIFEST)
    data = YAML.safe_load(File.read(manifest_path, encoding: 'UTF-8'),
                          permitted_classes: [], permitted_symbols: [], aliases: false)
    raise ConfigError, 'manifesto deve ser um mapping' unless data.is_a?(Hash)
    raise ConfigError, 'version deve ser 1' unless data['version'] == 1

    max_bytes = data['max_bytes']
    raise ConfigError, 'max_bytes deve ser inteiro positivo' unless max_bytes.is_a?(Integer) && max_bytes.positive?

    modules = data['modules']
    raise ConfigError, 'modules deve ser uma lista não vazia' unless modules.is_a?(Array) && !modules.empty?
    modules.each { |relative| existing_path(root, relative) }
    raise ConfigError, 'modules contém duplicatas' unless modules.uniq == modules

    adapters = data['adapters']
    raise ConfigError, 'adapters deve ser um mapping não vazio' unless adapters.is_a?(Hash) && !adapters.empty?
    adapters.each do |name, adapter|
      raise ConfigError, "nome de adapter inválido: #{name}" unless name.is_a?(String) && name.match?(SLUG)
      raise ConfigError, "adapter #{name} deve ser um mapping" unless adapter.is_a?(Hash)
      existing_path(root, adapter['template'])
      relative_path(root, adapter['output'])
    end

    { 'root' => root, 'max_bytes' => max_bytes, 'modules' => modules, 'adapters' => adapters }
  rescue Psych::Exception => e
    raise ConfigError, "YAML inválido no manifesto: #{e.class}"
  rescue Errno::ENOENT, Errno::EACCES => e
    raise ConfigError, "manifesto ou recurso ilegível: #{e.message}"
  end

  def self.render(root:, adapter:, root_label: nil)
    config = load_config(root)
    adapter_config = config['adapters'][adapter]
    raise ConfigError, "adapter desconhecido: #{adapter}" unless adapter_config

    sections = config['modules'].map do |relative|
      content = File.read(existing_path(config['root'], relative), encoding: 'UTF-8').strip
      "<!-- source: #{relative} -->\n#{content}"
    end
    template = File.read(existing_path(config['root'], adapter_config['template']), encoding: 'UTF-8')
    rendered = template
      .gsub('{{AI_AGENT_CONFIG_ROOT}}', root_label || config['root'])
      .gsub('{{MANAGED_CONTEXT}}', sections.join("\n\n"))
    raise ConfigError, "placeholder não resolvido no adapter #{adapter}" if rendered.match?(/\{\{[A-Z0-9_]+\}\}/)
    rendered = rendered.rstrip + "\n"
    if rendered.bytesize > config['max_bytes']
      raise ConfigError, "adapter #{adapter} excede max_bytes: #{rendered.bytesize} > #{config['max_bytes']}"
    end
    rendered
  end

  def self.outputs(root)
    config = load_config(root)
    config['adapters'].to_h do |name, adapter|
      [name, relative_path(config['root'], adapter['output'])]
    end
  end

  def self.existing_path(root, relative)
    path = relative_path(root, relative)
    raise ConfigError, "arquivo ausente: #{relative}" unless File.file?(path)
    real = File.realpath(path)
    raise ConfigError, "recurso fora da raiz: #{relative}" unless inside?(root, real)
    real
  end

  def self.relative_path(root, relative)
    unless relative.is_a?(String) && !relative.empty?
      raise ConfigError, 'caminho deve ser string não vazia'
    end
    pathname = Pathname.new(relative)
    if pathname.absolute? || pathname.each_filename.any? { |part| part == '..' }
      raise ConfigError, "caminho inválido: #{relative}"
    end
    path = File.expand_path(relative, root)
    raise ConfigError, "caminho fora da raiz: #{relative}" unless inside?(root, path)
    path
  end

  def self.inside?(root, path)
    path == root || path.start_with?(root + File::SEPARATOR)
  end
end
