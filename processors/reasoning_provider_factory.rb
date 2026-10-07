# frozen_string_literal: true

require 'json'
require 'yaml'
require_relative 'rule_based_reasoning_provider'
require_relative 'codex_reasoning_provider'
require_relative 'claude_reasoning_provider'
require_relative 'fallback_reasoning_provider'

module SecondBrain
  class ReasoningProviderFactory
    DEFAULT_CONFIG = File.expand_path('../config/reasoning.yml', __dir__)
    PROMPT_PATH = File.expand_path('../prompts/knowledge-extraction-v1.md', __dir__)
    SCHEMA_PATH = File.expand_path('../schemas/knowledge-reasoning-result.schema.json', __dir__)
    SEMANTIC_PROMPT_PATH = File.expand_path('../prompts/semantic-dedup-review-v1.md', __dir__)
    SEMANTIC_SCHEMA_PATH = File.expand_path('../schemas/semantic-review-result.schema.json', __dir__)

    attr_reader :config

    def initialize(path: DEFAULT_CONFIG, timeout_override: nil, runner: nil)
      @config = YAML.safe_load(File.read(path), aliases: false)
      raise ProviderConfigurationError, 'config de reasoning deve ser um objeto' unless @config.is_a?(Hash)
      @timeout_override = timeout_override
      @runner = runner
      @confidence_threshold = @config.fetch('confidence_threshold')
      @max_candidates = @config.fetch('max_candidates')
      unless @confidence_threshold.is_a?(Numeric) && (0.0..1.0).cover?(@confidence_threshold)
        raise ProviderConfigurationError, 'confidence_threshold inválido na configuração'
      end
      unless @max_candidates.is_a?(Integer) && @max_candidates.positive?
        raise ProviderConfigurationError, 'max_candidates deve ser inteiro positivo'
      end
    rescue Psych::Exception => e
      raise ProviderConfigurationError, "config de reasoning inválida: #{e.message}"
    end

    def default_provider
      @config.fetch('default_provider', 'rule-based')
    end

    def fallback_provider
      @config.fetch('fallback_provider', 'rule-based')
    end

    def build(name)
      case name
      when 'rule-based'
        RuleBasedReasoningProvider.new
      when 'codex', 'claude'
        provider_config = @config.fetch('providers', {}).fetch(name) do
          raise ProviderConfigurationError, "config ausente para provider #{name}"
        end
        timeout = @timeout_override || provider_config['timeout_seconds']
        raise ProviderConfigurationError, "timeout_seconds obrigatório para #{name}; informe na config ou CLI" unless timeout

        klass = name == 'codex' ? CodexReasoningProvider : ClaudeReasoningProvider
        klass.new(
          command: provider_config.fetch('command'), schema_path: SCHEMA_PATH,
          prompt_path: PROMPT_PATH, timeout_seconds: timeout,
          confidence_threshold: @confidence_threshold,
          max_candidates: @max_candidates, runner: @runner,
          semantic_schema_path: SEMANTIC_SCHEMA_PATH,
          semantic_prompt_path: SEMANTIC_PROMPT_PATH
        )
      else
        raise ProviderConfigurationError, "provider desconhecido: #{name}"
      end
    end

    def build_selected(name: nil, fallback_name: nil)
      primary_name = name || default_provider
      fallback_name ||= fallback_provider
      primary = build(primary_name)
      return primary if fallback_name == 'none' || primary_name == fallback_name

      FallbackReasoningProvider.new(primary: primary, fallback: build(fallback_name))
    end
  end
end
