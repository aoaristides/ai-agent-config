# frozen_string_literal: true

require 'json'

module SecondBrain
  # Deriva o schema aceito por `claude --json-schema` sem alterar o contrato.
  module ClaudeSchemaAdapter
    Result = Struct.new(:schema, :removed_keywords, keyword_init: true)

    module_function

    def adapt(canonical_schema)
      schema = JSON.parse(JSON.generate(canonical_schema))
      removed_keywords = []
      removed_keywords << '$schema' if schema.key?('$schema') && schema.delete('$schema')

      Result.new(schema: schema, removed_keywords: removed_keywords.freeze)
    end
  end
end
