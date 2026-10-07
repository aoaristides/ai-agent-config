# frozen_string_literal: true

require_relative 'command_reasoning_provider'

module SecondBrain
  class FallbackReasoningProvider
    include ReasoningProvider

    TECHNICAL_ERRORS = [
      ProviderUnavailableError, ProviderTimeoutError,
      ProviderExecutionError, InvalidReasoningResponseError
    ].freeze

    attr_reader :fallback_error, :used_provider

    def initialize(primary:, fallback:)
      unless primary.is_a?(ReasoningProvider) && fallback.is_a?(ReasoningProvider)
        raise ArgumentError, 'primary e fallback devem implementar ReasoningProvider'
      end

      @primary = primary
      @fallback = fallback
      @used_provider = primary.respond_to?(:name) ? primary.name : primary.class.name
      @failed = false
    end

    %i[summarize classify extract_knowledge find_relationships].each do |operation|
      define_method(operation) do |**arguments|
        return @fallback.public_send(operation, **arguments) if @failed

        @primary.public_send(operation, **arguments)
      rescue *TECHNICAL_ERRORS => error
        @failed = true
        @fallback_error = error
        @used_provider = @fallback.respond_to?(:name) ? @fallback.name : @fallback.class.name
        @fallback.public_send(operation, **arguments)
      end
    end

    # Revisão semântica não usa fallback determinístico: um resultado ausente
    # faria o processor aplicar uma decisão de duplicidade sem evidência.
    def review_semantics(candidate:, related_notes:)
      return nil if @failed

      @primary.review_semantics(candidate: candidate, related_notes: related_notes)
    end
  end
end
