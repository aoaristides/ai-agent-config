#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'
require 'shellwords'
require 'yaml'

module ModelResolver
  class ConfigError < StandardError; end

  RUNTIMES = %w[codex claude antigravity].freeze
  PHASE_PROFILES = { 'plan' => 'planning', 'execute' => 'execution' }.freeze

  def self.resolve(root:, runtime:, profile: nil, agent: nil, unavailable: [], phase: nil, model: nil)
    if (profile && (agent || phase)) || !(profile || agent || phase)
      raise ConfigError, 'informe --profile, --agent ou --phase; combine apenas --agent com --phase'
    end
    raise ConfigError, "runtime desconhecido: #{runtime}" unless RUNTIMES.include?(runtime)
    phase_profile = PHASE_PROFILES.fetch(phase) { raise ConfigError, "fase desconhecida: #{phase}" } if phase
    raise ConfigError, '--model exige --phase' if model && !phase

    root = File.realpath(root)
    catalog = load_yaml(File.join(root, 'agents/catalog.yml'), 'catálogo de agentes')
    profiles = load_yaml(File.join(root, 'models/profiles.yaml'), 'perfis de modelo')
    mapping = load_yaml(File.join(root, 'adapters', runtime, 'models.yaml'), "mapping de #{runtime}")

    agent_profile = nil
    if agent
      entry = catalog.fetch('agents', {})[agent]
      raise ConfigError, "agente desconhecido: #{agent}" unless entry.is_a?(Hash)

      agent_profile = entry['model_profile']
      unless profiles.fetch('profiles', {}).key?(agent_profile)
        raise ConfigError, "perfil do agente desconhecido: #{agent_profile.inspect}"
      end
    end
    profile = phase_profile || agent_profile || profile

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
    unless candidates.all? { |candidate| candidate.is_a?(String) && !candidate.strip.empty? }
      raise ConfigError, "lista de modelos inválida para #{profile} em #{runtime}"
    end
    if model && (!candidates.include?(model) || unavailable.include?(model))
      raise ConfigError, "modelo #{model} não está entre as opções disponíveis de #{phase} para #{runtime}"
    end
    selected = model || candidates.find { |candidate| !unavailable.include?(candidate) }
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
      'phase' => phase,
      'agent_profile' => phase ? agent_profile : nil,
      'profile' => profile,
      'model' => selected,
      'host_selector' => host_selector,
      'selection_mode' => selection_mode,
      'materializable' => materializable,
      'fallback' => !model && selected != primary,
      'explicit_model' => model
    }.compact
  rescue Errno::ENOENT, Psych::Exception, TypeError, KeyError => e
    raise ConfigError, "configuração de modelos ilegível: #{e.class}: #{e.message}"
  end

  def self.session_command(result)
    phase = result['phase']
    raise ConfigError, 'abrir ou exibir uma sessão exige --phase' unless phase

    cli, plan_flags = case result.fetch('runtime')
                      when 'codex' then ['codex', %w[--sandbox read-only]]
                      when 'claude' then ['claude', %w[--permission-mode plan]]
                      when 'antigravity' then ['agy', %w[--mode plan]]
                      end
    command = [cli, "--model=#{result.fetch('model')}"]
    command.concat(plan_flags) if phase == 'plan'
    command
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
  launch = false
  parser = OptionParser.new do |opts|
    opts.banner = 'Uso: ruby scripts/resolve-model.rb --runtime NOME (--profile PERFIL | --agent AGENTE | --phase FASE) [opções]'
    opts.on('--runtime NOME') { |value| options[:runtime] = value }
    opts.on('--profile PERFIL') { |value| options[:profile] = value }
    opts.on('--agent AGENTE') { |value| options[:agent] = value }
    opts.on('--phase FASE', ModelResolver::PHASE_PROFILES.keys, 'plan ou execute; pode combinar com --agent') { |value| options[:phase] = value }
    opts.on('--model ID', 'Modelo declarado na fase para esta sessão') { |value| options[:model] = value }
    opts.on('--unavailable LISTA', Array) { |value| options[:unavailable].concat(value) }
    opts.on('--format FORMATO', %w[plain json yaml command]) { |value| options[:format] = value }
    opts.on('--launch', 'Abre uma nova sessão interativa a partir do diretório atual') { launch = true }
    opts.on('-h', '--help') { puts opts; exit 0 }
  end

  begin
    parser.parse!(ARGV)
    raise ModelResolver::ConfigError, parser.banner unless ARGV.empty? && options[:runtime]

    result = ModelResolver.resolve(**options.reject { |key, _| key == :format })
    if launch
      raise ModelResolver::ConfigError, '--launch não pode ser combinado com --format diferente de plain' if options[:format] != 'plain'

      exec(*ModelResolver.session_command(result))
    end
    case options[:format]
    when 'json' then puts JSON.generate(result)
    when 'yaml' then puts YAML.dump(result)
    when 'command' then puts Shellwords.join(ModelResolver.session_command(result))
    else puts result.fetch('model')
    end
  rescue ModelResolver::ConfigError, OptionParser::ParseError, SystemCallError => e
    warn "[resolve-model] #{e.message}"
    exit 1
  end
end
