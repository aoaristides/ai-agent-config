# frozen_string_literal: true

module SecondBrain
  # Adapta o contrato canônico ao subconjunto de JSON Schema do Codex CLI.
  # Esta transformação é de transporte; a resposta continua validada pelo
  # contrato canônico em CommandReasoningProvider.
  module CodexOutputSchema
    module_function

    def adapt(canonical_schema)
      schema = Marshal.load(Marshal.dump(canonical_schema))
      primary_type = schema.dig('properties', 'classification', 'properties', 'primary_type')

      unless primary_type.is_a?(Hash) && primary_type['oneOf'].is_a?(Array)
        raise ArgumentError, 'schema canônico sem oneOf esperado em classification.primary_type'
      end

      primary_type['anyOf'] = primary_type.delete('oneOf')
      schema
    end
  end
end
