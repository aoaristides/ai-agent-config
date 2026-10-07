# frozen_string_literal: true

require 'json'
require_relative 'command_reasoning_provider'
require_relative 'claude_schema_adapter'
require_relative 'semantic_review_contract'

module SecondBrain
  # Adapter fino para `claude --print`, sem ferramentas nem persistência de sessão.
  class ClaudeReasoningProvider < CommandReasoningProvider
    DEFAULT_SEMANTIC_SCHEMA = File.expand_path('../schemas/semantic-review-result.schema.json', __dir__)
    DEFAULT_SEMANTIC_PROMPT = File.expand_path('../prompts/semantic-dedup-review-v1.md', __dir__)
    attr_reader :schema_adaptation

    def initialize(command:, schema_path:, prompt_path:, timeout_seconds:,
                   confidence_threshold:, max_candidates:, runner: nil,
                   semantic_schema_path: DEFAULT_SEMANTIC_SCHEMA,
                   semantic_prompt_path: DEFAULT_SEMANTIC_PROMPT)
      prompt = File.read(prompt_path)
      schema_result = ClaudeSchemaAdapter.adapt(JSON.parse(File.read(schema_path)))
      @schema_adaptation = schema_result.removed_keywords
      semantic_schema_result = ClaudeSchemaAdapter.adapt(JSON.parse(File.read(semantic_schema_path)))
      @semantic_schema = semantic_schema_result.schema
      @semantic_prompt = File.read(semantic_prompt_path)
      argv = [
        command, '--print', '--output-format', 'json', '--json-schema', JSON.generate(schema_result.schema),
        '--tools', '', '--safe-mode', '--no-session-persistence',
        '--system-prompt', prompt
      ]
      super(name: 'claude', command_argv: argv,
            prompt_path: prompt_path, timeout_seconds: timeout_seconds,
            confidence_threshold: confidence_threshold,
            max_candidates: max_candidates, runner: runner)
    end

    protected

    def parse_response(stdout)
      envelope = JSON.parse(stdout)
      return envelope.fetch('structured_output') if envelope.is_a?(Hash) && envelope.key?('structured_output')

      # Compatibilidade com versões que entreguem o objeto estruturado diretamente.
      envelope
    end

    def request_prompt(capture:, context:)
      input_json(capture: capture, context: context)
    end

    public

    def diagnostic_invocation(capture:, context: nil)
      super.merge(schema_adaptation: @schema_adaptation.dup)
    end

    def review_semantics(candidate:, related_notes:)
      semantic_argv = @command_argv.dup
      schema_index = semantic_argv.index('--json-schema') + 1
      semantic_argv[schema_index] = JSON.generate(@semantic_schema)
      prompt_index = semantic_argv.index('--system-prompt') + 1
      semantic_argv[prompt_index] = @semantic_prompt
      input = JSON.generate('candidate' => candidate, 'related_notes' => related_notes)
      response = run_structured_request(argv: semantic_argv, prompt: input, parser: method(:parse_response))
      SemanticReviewContract.validate!(response, related_notes: related_notes)
    rescue ArgumentError => e
      raise InvalidReasoningResponseError.new("claude: #{e.message}", provider: 'claude',
        executable: @command_argv.first, argv: @command_argv,
        original_exception_class: e.class.name)
    end
  end
end
