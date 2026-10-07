# frozen_string_literal: true

module SecondBrain
  # Port usado pelo core para solicitar operações de raciocínio.
  # Implementações concretas devem traduzir entradas e saídas sem expor SDKs,
  # tipos ou semântica proprietários ao core.
  module ReasoningProvider
    # @param capture [Hash] CanonicalCapture serializado como dados Ruby.
    # @param context [Hash, nil] Contexto opcional e independente de provider.
    # @return [String] Síntese em texto simples.
    def summarize(capture:, context: nil)
      raise NotImplementedError, 'implement summarize(capture:, context:)'
    end

    # @param capture [Hash] CanonicalCapture serializado como dados Ruby.
    # @param taxonomy [Array<String>] Categorias aceitas pelo consumidor.
    # @param context [Hash, nil] Contexto opcional e independente de provider.
    # @return [Hash] Classificação estruturada no contrato do core.
    def classify(capture:, taxonomy:, context: nil)
      raise NotImplementedError, 'implement classify(capture:, taxonomy:, context:)'
    end

    # @param capture [Hash] CanonicalCapture serializado como dados Ruby.
    # @param context [Hash, nil] Contexto opcional e independente de provider.
    # @return [Array<Hash>] Candidatos de conhecimento estruturados.
    def extract_knowledge(capture:, context: nil)
      raise NotImplementedError, 'implement extract_knowledge(capture:, context:)'
    end

    # @param knowledge [Hash] Candidato a conhecimento em formato do core.
    # @param existing_knowledge [Array<Hash>] Notas candidatas a relacionamento.
    # @param context [Hash, nil] Contexto opcional e independente de provider.
    # @return [Array<Hash>] Relacionamentos sugeridos em formato do core.
    def find_relationships(knowledge:, existing_knowledge:, context: nil)
      raise NotImplementedError,
            'implement find_relationships(knowledge:, existing_knowledge:, context:)'
    end

    # @param candidate [Hash] Conhecimento novo já extraído.
    # @param related_notes [Array<Hash>] Notas relacionadas já selecionadas pelo core.
    # @return [Hash, nil] Decisão semântica estruturada; nil quando não suportada.
    def review_semantics(candidate:, related_notes:)
      nil
    end
  end
end
