# frozen_string_literal: true

require_relative 'reasoning_provider'

module SecondBrain
  # Implementação local e determinística; não envia conteúdo a serviços externos.
  class RuleBasedReasoningProvider
    include ReasoningProvider

    HEADINGS = {
      'decisão' => 'decision', 'decisao' => 'decision',
      'arquitetura' => 'architecture', 'aprendizado' => 'learning',
      'problema' => 'problem', 'solução' => 'solution', 'solucao' => 'solution'
    }.freeze

    def summarize(capture:, context: nil)
      extract_knowledge(capture: capture, context: context).first&.fetch('summary')
    end

    def classify(capture:, taxonomy:, context: nil)
      type = canonical_type(capture['type'])
      type = heading_sections(capture.fetch('content')).keys.first if type.nil?
      category = type && TYPE_MAP[type]
      category = nil unless taxonomy.include?(category)
      { 'type' => category, 'confidence' => category ? 'explicit' : 'unclassified' }
    end

    def extract_knowledge(capture:, context: nil)
      content = capture.fetch('content')
      sections = heading_sections(content)
      type = canonical_type(capture['type'])
      type ||= sections.keys.first
      return [] unless type

      relevant = sections[type]
      return [] unless relevant && !relevant.empty?
      summary = first_statement(relevant)
      return [] if summary.empty?

      [{
        'type' => TYPE_MAP.fetch(type),
        'title' => title_for(summary),
        'summary' => summary,
        'content' => summary,
        'project' => capture['project'] || 'transversal',
        'tags' => Array(capture['tags']).map(&:strip).reject(&:empty?).uniq
      }]
    end

    def find_relationships(knowledge:, existing_knowledge:, context: nil)
      text = "#{knowledge['title']} #{knowledge['summary']} #{knowledge['content']}".downcase
      existing_knowledge.each_with_object([]) do |note, relationships|
        title = note['title'].to_s
        next if title.empty? || title.downcase == knowledge['title'].downcase
        next unless text.include?(title.downcase)

        relationships << { 'path' => note.fetch('path'), 'title' => title }
      end
    end

    private

    TYPE_MAP = {
      'decision' => 'decisao', 'architecture' => 'decisao',
      'learning' => 'aprendizado', 'problem' => 'aprendizado',
      'solution' => 'padrao'
    }.freeze

    def canonical_type(value)
      return nil unless value
      return value if TYPE_MAP.key?(value)

      HEADINGS[value.downcase]
    end

    def heading_sections(content)
      sections = {}
      current = nil
      content.each_line do |line|
        clean_line = line.chomp
        if (match = clean_line.match(/\A\s{0,3}(?:\#{1,6}\s*)?(Decisão|Decisao|Arquitetura|Aprendizado|Problema|Solução|Solucao)\s*:\s*(.*)\z/i))
          current = HEADINGS.fetch(match[1].downcase)
          sections[current] = +''
          sections[current] << match[2] << "\n" unless match[2].empty?
        elsif line.match?(/\A\s{0,3}\#{1,6}\s+/)
          current = nil
        elsif current
          sections[current] << line
        end
      end
      sections.transform_values(&:strip)
    end

    def first_statement(text)
      text.lines.map(&:strip).reject(&:empty?).first.to_s
        .sub(/\A[-*]\s+/, '').sub(/\A\[[^\]]+\]\s*/, '').strip
    end

    def title_for(summary)
      phrase = summary.sub(/[.!?]+\z/, '').sub(/\A(?:usar|adotar|escolher)\s+/i, '')
      phrase = phrase.split(/\s+/).first(9).join(' ')
      phrase.empty? ? 'Conhecimento capturado' : phrase[0].upcase + phrase[1..]
    end
  end
end
