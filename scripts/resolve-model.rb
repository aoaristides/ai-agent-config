#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'
require 'yaml'

module ModelResolver
  class ConfigError < StandardError; end

  RUNTIMES = %w[codex claude antigravity].freeze

  def self.resolve(root:, runtime:, profile: nil, agent: nil, unavailable: [])
    raise ConfigError, 'informe exatamente um de --profile ou --agent' unless [profile, agent].compact.length == 1
    raise ConfigError, "runtime desconhecido: #{runtime}" unless RUNTIMES.include?(runtime)

    root = File.realpath(root)
    catalog = load_yaml(File.join(root, 'agents/catalog.yml'), 'catálogo de agentes')
    profiles = load_yaml(File.join(root, 'models/profiles.yaml'), 'perfis de modelo')
    mapping = load_yaml(File.join(root, 'adapters', runtime, 'models.yaml'), "mapping de #{runtime}")

    if agent
      entry = catalog.fetch('agents', {})[agent]
      raise ConfigError, "agente desconhecido: #{agent}" unless entry.is_a?(Hash)

      profile = entry['model_profile']
    end

    unless profiles.fetch('profiles', {}).key?(profile)
      raise ConfigError, "perfil desconhecido: #{profile.inspect}"
    end

    runtime_profile = mapping.fetch('profiles', {})[profile]
    raise ConfigError, "perfil #{profile} sem mapping para #{runtime}" unless runtime_profile.is_a?(Hash)

    capabilities = mapping['capabilities']
    unless capabilities.is_a?(Hash)
      raise ConfigError, "capabilities ausentes para #{runtime}"
    end
    selection_mode = capabilities['model_selection']
    materializable = capabilities['subagent_materialization']
    unless %w[exact alias advisory].include?(selection_mode) && [true, false].include?(materializable)
      raise ConfigError, "capabilities inválidas para #{runtime}"
    end
    if (selection_mode == 'advisory') == materializable
      raise ConfigError, "capabilities incompatíveis para #{runtime}"
    end

    primary = runtime_profile['primary']
    candidates = [primary, *Array(runtime_profile['fallbacks'])]
    selected = candidates.find { |model| !unavailable.include?(model) }
    raise ConfigError, "nenhum modelo disponível para #{profile} em #{runtime}" unless selected

    host_selector = case selection_mode
                    when 'exact'
                      selected
                    when 'alias'
                      mapping.fetch('selectors', {})[selected] ||
                        raise(ConfigError, "modelo #{selected} sem selector para #{runtime}")
                    end

    {
      'runtime' => runtime,
      'agent' => agent,
      'profile' => profile,
      'model' => selected,
      'host_selector' => host_selector,
      'selection_mode' => selection_mode,
      'materializable' => materializable,
      'fallback' => selected != primary
    }.compact
  rescue Errno::ENOENT, Psych::Exception, TypeError, KeyError => e
    raise ConfigError, "configuração de modelos ilegível: #{e.class}: #{e.message}"
  end

  def self.load_yaml(path, label)
    data = YAML.safe_load(File.read(path, encoding: 'UTF-8'),
                          permitted_classes: [], permitted_symbols: [], aliases: false)
    raise ConfigError, "#{label} deve ser mapping" unless data.is_a?(Hash)

    data
  end
end

if $PROGRAM_NAME == __FILE__
  options = { root: File.expand_path('..', __dir__), unavailable: [], format: 'plain' }
  parser = OptionParser.new do |opts|
    opts.banner = 'Uso: ruby scripts/resolve-model.rb --runtime NOME (--profile PERFIL | --agent AGENTE) [opções]'
    opts.on('--runtime NOME') { |value| options[:runtime] = value }
    opts.on('--profile PERFIL') { |value| options[:profile] = value }
    opts.on('--agent AGENTE') { |value| options[:agent] = value }
    opts.on('--unavailable LISTA', Array) { |value| options[:unavailable].concat(value) }
    opts.on('--format FORMATO', %w[plain json yaml]) { |value| options[:format] = value }
    opts.on('-h', '--help') { puts opts; exit 0 }
  end

  begin
    parser.parse!(ARGV)
    raise ModelResolver::ConfigError, parser.banner unless ARGV.empty? && options[:runtime]

    result = ModelResolver.resolve(**options.reject { |key, _| key == :format })
    case options[:format]
    when 'json' then puts JSON.generate(result)
    when 'yaml' then puts YAML.dump(result)
    else puts result.fetch('model')
    end
  rescue ModelResolver::ConfigError, OptionParser::ParseError => e
    warn "[resolve-model] #{e.message}"
    exit 1
  end
end
