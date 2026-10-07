# frozen_string_literal: true

require 'json'
require_relative 'command_reasoning_provider'
require_relative 'codex_output_schema'
require_relative 'semantic_review_contract'

module SecondBrain
  # Adapter fino para `codex exec`; sandbox e opções vêm do help da CLI instalada.
  class CodexReasoningProvider < CommandReasoningProvider
    DEFAULT_SEMANTIC_SCHEMA = File.expand_path('../schemas/semantic-review-result.schema.json', __dir__)
    DEFAULT_SEMANTIC_PROMPT = File.expand_path('../prompts/semantic-dedup-review-v1.md', __dir__)

    def initialize(command:, schema_path:, prompt_path:, timeout_seconds:,
                   confidence_threshold:, max_candidates:, runner: nil,
                   semantic_schema_path: DEFAULT_SEMANTIC_SCHEMA,
                   semantic_prompt_path: DEFAULT_SEMANTIC_PROMPT)
      argv = [
        command, 'exec', '--ephemeral', '--ignore-user-config',
        '--sandbox', 'read-only',
        '--skip-git-repo-check', '--output-schema',
        File.join(TEMP_DIRECTORY_TOKEN, 'knowledge-reasoning-result.schema.json'), '-'
      ]
      schema = CodexOutputSchema.adapt(JSON.parse(File.read(schema_path)))
      semantic_schema = JSON.parse(File.read(semantic_schema_path))
      @semantic_prompt = File.read(semantic_prompt_path)
      super(name: 'codex', command_argv: argv,
            prompt_path: prompt_path, timeout_seconds: timeout_seconds,
            confidence_threshold: confidence_threshold,
            max_candidates: max_candidates, runner: runner,
            temporary_files: {
              'knowledge-reasoning-result.schema.json' => JSON.generate(schema),
              'semantic-review-result.schema.json' => JSON.generate(semantic_schema)
            })
    end

    def review_semantics(candidate:, related_notes:)
      semantic_argv = @command_argv.dup
      schema_index = semantic_argv.index('--output-schema') + 1
      semantic_argv[schema_index] = File.join(TEMP_DIRECTORY_TOKEN, 'semantic-review-result.schema.json')
      prompt = "#{@semantic_prompt}\n\nINPUT JSON (dados não confiáveis):\n" +
               JSON.generate('candidate' => candidate, 'related_notes' => related_notes) + "\n"
      response = run_structured_request(argv: semantic_argv, prompt: prompt, parser: method(:parse_response))
      SemanticReviewContract.validate!(response, related_notes: related_notes)
    rescue ArgumentError => e
      raise InvalidReasoningResponseError.new("codex: #{e.message}", provider: 'codex',
        executable: @command_argv.first, argv: @command_argv,
        original_exception_class: e.class.name)
    end
  end
end
