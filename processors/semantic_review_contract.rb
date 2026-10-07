# frozen_string_literal: true

module SecondBrain
  module SemanticReviewContract
    ACTIONS = %w[create update merge link skip].freeze
    module_function

    def validate!(result, related_notes:)
      required = %w[action confidence target reason novel_information]
      invalid!('raiz deve ser objeto') unless result.is_a?(Hash) && result.keys.sort == required.sort
      invalid!('action inválida') unless ACTIONS.include?(result['action'])
      confidence = result['confidence']
      invalid!('confidence inválida') unless confidence.is_a?(Numeric) && confidence.finite? && (0.0..1.0).cover?(confidence)
      invalid!('target inválido') unless result['target'].nil? || result['target'].is_a?(String)
      invalid!('reason vazio') unless result['reason'].is_a?(String) && !result['reason'].strip.empty?
      invalid!('novel_information inválido') unless result['novel_information'].is_a?(Array) &&
        result['novel_information'].all? { |item| item.is_a?(String) && !item.strip.empty? }

      action = result['action']
      target = result['target']
      if %w[update merge skip].include?(action)
        invalid!('target deve apontar para uma nota fornecida') unless related_notes.any? { |note| note['title'] == target }
      elsif !target.nil?
        invalid!('create/link não aceitam target')
      end
      result
    end

    def invalid!(message)
      raise ArgumentError, "SemanticReview inválido: #{message}"
    end
    private_class_method :invalid!
  end
end
