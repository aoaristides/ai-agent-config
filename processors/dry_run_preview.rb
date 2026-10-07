# frozen_string_literal: true

require_relative 'provider_debug_formatter'

module SecondBrain
  # Apresenta somente o plano de candidatos, sem invocar operações de escrita.
  module DryRunPreview
    module_function

    def print(candidate_results, output:)
      candidate_results.each_with_index do |item, index|
        candidate = item.fetch(:candidate)
        output.puts("CANDIDATE ##{index + 1}")
        output.puts("  type: #{safe(candidate['type'])}")
        confidence = candidate.key?('confidence') ? candidate['confidence'] : 'não fornecida'
        output.puts("  confidence: #{safe(confidence)}")
        output.puts("  title: #{safe(candidate['title'])}")
        print_block(output, 'summary', candidate['summary'])
        print_block(output, 'content', candidate['content'])
        output.puts('  evidence:')
        evidence = Array(candidate['evidence'])
        if evidence.empty?
          output.puts('    - nenhuma')
        else
          evidence.each { |entry| print_list_item(output, entry) }
        end
        output.puts('  relationships:')
        relationships = item.fetch(:relationships)
        if relationships.empty?
          output.puts('    - nenhuma')
        else
          relationships.each do |relationship|
            output.puts("    - #{safe(relationship['title'])} (#{safe(relationship['path'])})")
          end
        end
        output.puts("  destination: #{safe(item.fetch(:destination))}")
        output.puts("  exact_dedup: #{item.fetch(:existing) ? 'capture_id/destination' : 'none'}")
        if (review = item[:semantic_review])
          output.puts('  semantic_review:')
          output.puts("    action: #{safe(review.fetch('action').upcase)}")
          output.puts("    confidence: #{safe(review.fetch('confidence'))}")
          output.puts("    target: #{safe(review['target'] || 'null')}")
          output.puts("    reason: #{safe(review.fetch('conservative_reason', review.fetch('reason')))}")
          output.puts('    novel_information:')
          novel = Array(review['novel_information'])
          if novel.empty?
            output.puts('      - nenhuma')
          else
            novel.each { |entry| print_list_item(output, entry, indent: '      ') }
          end
        else
          output.puts('  semantic_review: não executada')
        end
        output.puts("  action: #{item.fetch(:action)}")
        output.puts("  final_action: #{item.fetch(:final_action, item.fetch(:action))}")
      end
    end

    def print_block(output, label, value)
      output.puts("  #{label}:")
      safe(value).lines(chomp: true).each { |line| output.puts("    #{line}") }
    end
    private_class_method :print_block

    def print_list_item(output, value, indent: '    ')
      lines = safe(value).lines(chomp: true)
      output.puts("#{indent}- #{lines.shift}")
      lines.each { |line| output.puts("#{indent}  #{line}") }
    end
    private_class_method :print_list_item

    def safe(value)
      ProviderDebugFormatter.redact(value)
    end
    private_class_method :safe
  end
end
