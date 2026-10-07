# frozen_string_literal: true

require 'date'
require 'fileutils'
require 'json'
require 'pathname'
require 'time'
require 'yaml'
require_relative '../scripts/capture-knowledge'
require_relative 'reasoning_provider'
require_relative 'dry_run_preview'
require_relative 'semantic_review_contract'

module SecondBrain
  class KnowledgeProcessor
    CATEGORIES = %w[padrao decisao preferencia projeto stack aprendizado].freeze
    CATEGORY_DIRECTORIES = {
      'padrao' => '01-padroes', 'decisao' => '02-decisoes',
      'preferencia' => '03-preferencias', 'projeto' => '04-projetos',
      'stack' => '05-stack', 'aprendizado' => '06-aprendizados'
    }.freeze
    ARCHIVE_DIRECTORY = 'processed'

    Result = Struct.new(:status, :capture_path, :destination, :capture_id,
                        :classification, :candidates, :relationships, :message,
                        keyword_init: true)

    def initialize(vault:, reasoning_provider:, stdout: $stdout, today: nil,
                   max_semantic_candidates: 5, semantic_confidence_threshold: 0.75)
      unless reasoning_provider.is_a?(ReasoningProvider)
        raise ArgumentError, 'reasoning_provider deve implementar SecondBrain::ReasoningProvider'
      end

      @vault = File.expand_path(vault)
      @vault_real = File.realpath(@vault)
      @provider = reasoning_provider
      @stdout = stdout
      @today = today
      unless max_semantic_candidates.is_a?(Integer) && max_semantic_candidates.positive?
        raise ArgumentError, 'max_semantic_candidates deve ser inteiro positivo'
      end
      unless semantic_confidence_threshold.is_a?(Numeric) && (0.0..1.0).cover?(semantic_confidence_threshold)
        raise ArgumentError, 'semantic_confidence_threshold deve ficar entre 0 e 1'
      end
      @max_semantic_candidates = max_semantic_candidates
      @semantic_confidence_threshold = semantic_confidence_threshold.to_f
    end

    def process(path, dry_run: false)
      capture_path = File.expand_path(path)
      inbox = File.join(@vault, '99-inbox')
      raise ArgumentError, "inbox inválida ou symlink: #{inbox}" unless File.directory?(inbox) && !File.symlink?(inbox)
      raise ArgumentError, "captura fora da inbox ativa: #{capture_path}" unless File.dirname(capture_path) == inbox
      raise ArgumentError, "captura inválida ou symlink: #{capture_path}" unless File.file?(capture_path) && !File.symlink?(capture_path)
      ensure_vault_path!(capture_path)

      capture = JSON.parse(File.read(capture_path))
      validate_shape(capture)
      KnowledgeCapture.validate(capture)
      log('VALIDATED', capture.fetch('capture_id'))
      normalized = normalize(capture)

      notes = existing_notes
      capture_notes = notes.select { |note| note['capture_id'] == capture['capture_id'] }
      archived_path = archive_path(capture)
      expected_candidates = capture_notes.map { |note| note['candidate_count'] }.compact.max
      complete_capture = expected_candidates.nil? || capture_notes.length >= expected_candidates
      if !capture_notes.empty? && (File.file?(archived_path) || complete_capture)
        capture_note = capture_notes.first
        log('DEDUPLICATED', "duplicate/skip: capture_id já persistido em #{capture_note['path']}")
        capture_notes.each { |note| ensure_index_link(note, dry_run: dry_run) }
        return finish_duplicate(capture_path, capture, capture_note, dry_run)
      end

      provider_context = {
        'capture_id' => capture.fetch('capture_id'),
        'existing_knowledge' => notes.map { |note| { 'title' => note['title'] } }
      }
      classification = @provider.classify(capture: normalized, taxonomy: CATEGORIES, context: provider_context)
      category = classification['type']
      log('CLASSIFIED', category || 'sem classificação')

      candidates = @provider.extract_knowledge(capture: normalized, context: provider_context)
      if candidates.empty?
        log('NO_KNOWLEDGE', 'nenhum candidato acima dos critérios; captura permanece na inbox')
        return Result.new(status: :no_knowledge, capture_path: capture_path, capture_id: capture['capture_id'],
                          classification: classification, candidates: [], relationships: [],
                          message: 'nenhum conhecimento durável identificado; captura mantida na inbox')
      end
      candidates.each do |candidate|
        unless CATEGORY_DIRECTORIES.key?(candidate['type'])
          raise ArgumentError, "candidato com categoria inválida: #{candidate['type'].inspect}; captura permanece na inbox"
        end
        raise ArgumentError, 'candidato sem título, resumo ou conteúdo; captura permanece na inbox' unless
          %w[title summary content].all? { |field| candidate[field].is_a?(String) && !candidate[field].strip.empty? }
      end
      log('EXTRACTED', "#{candidates.length} candidato(s)")

      destinations = candidates.map { |candidate| destination_for(candidate, normalized) }
      if destinations.uniq.length != destinations.length
        raise ArgumentError, 'dois candidatos apontam para o mesmo destino; captura mantida na inbox'
      end
      prior_paths = capture_notes.map { |note| note['path'] }
      unless (prior_paths - destinations).empty?
        raise ArgumentError, 'saída do provider diverge de notas parciais já gravadas; captura mantida na inbox para revisão'
      end

      candidate_results = candidates.zip(destinations).map do |candidate, destination|
        ensure_vault_path!(destination)
        existing = notes.find { |note| note['path'] == destination }
        existing_conflict = existing && existing['capture_id'] != capture['capture_id']
        untracked_file_conflict = !existing && (File.exist?(destination) || File.symlink?(destination))
        conflict = existing_conflict || untracked_file_conflict
        if conflict
          log('DEDUPLICATED', "conflict: destino ocupado por outra nota: #{destination}")
          unless dry_run
            raise ArgumentError, "destino já existe sem capture_id correspondente: #{destination}; captura mantida na inbox"
          end
        end
        relationships = if conflict || existing
                          []
                        else
                          @provider.find_relationships(
                            knowledge: candidate,
                            existing_knowledge: notes.map { |note| { 'title' => note['title'], 'path' => note['path'] } },
                            context: provider_context
                          ).select { |relationship| notes.any? { |note| note['path'] == relationship['path'] } }
                            .uniq { |relationship| relationship['path'] }
                        end
        semantic_review = nil
        if !conflict && !existing && !relationships.empty?
          related_notes = relationships.first(@max_semantic_candidates).map do |relationship|
            note = notes.find { |item| item['path'] == relationship['path'] }
            { 'title' => note.fetch('title'), 'content' => semantic_note_content(note.fetch('path')) }
          end
          semantic_review = @provider.review_semantics(candidate: candidate, related_notes: related_notes)
          semantic_review ||= {
            'action' => 'link', 'confidence' => 0.0, 'target' => nil,
            'reason' => 'provider não oferece revisão semântica; mantido como conceito relacionado',
            'novel_information' => []
          }
          SemanticReviewContract.validate!(semantic_review, related_notes: related_notes)
          semantic_action = semantic_review.fetch('action').upcase
          if semantic_review.fetch('confidence') < @semantic_confidence_threshold &&
             %w[CREATE UPDATE MERGE SKIP].include?(semantic_action)
            semantic_action = 'LINK'
            semantic_review = semantic_review.merge(
              'applied_action' => 'link',
              'conservative_reason' => 'confiança abaixo do limite existente; preservada como nota relacionada'
            )
          end
        end
        action = if conflict
                   'CONFLICT'
                 elsif existing
                   'SKIP'
                 elsif semantic_review
                   semantic_review['applied_action']&.upcase || semantic_review.fetch('action').upcase
                 else
                   'CREATE'
                 end
        final_action = case action
                       when 'UPDATE', 'MERGE' then "#{action}_REVIEW_REQUIRED"
                       else action
                       end
        { candidate: candidate, destination: destination, relationships: relationships,
          semantic_review: semantic_review, action: action, final_action: final_action,
          markdown: %w[CREATE LINK].include?(action) ? render(capture, candidate, relationships, candidate_count: candidates.length) : nil,
          existing: existing }
      end
      log('DEDUPLICATED', candidate_results.any? { |item| item[:action] == 'CONFLICT' } ? 'conflito detectado' : 'sem duplicata encontrada')
      candidate_results.each { |item| log('RENDERED', item[:destination]) if item[:markdown] }
      if dry_run
        DryRunPreview.print(candidate_results, output: @stdout)
        blocked_write = candidate_results.any? { |item| %w[CONFLICT UPDATE MERGE].include?(item[:action]) }
        unless blocked_write
          candidate_results.each do |item|
            @stdout.puts("DRY-RUN: gravaria nota em #{item[:destination]}") if %w[CREATE LINK].include?(item[:action])
          end
        end
        if blocked_write
          @stdout.puts('DRY-RUN: manteria captura na inbox para revisão manual')
        elsif candidate_results.all? { |item| item[:action] == 'SKIP' }
          @stdout.puts('DRY-RUN: manteria captura na inbox; nenhum conhecimento novo')
        else
          @stdout.puts("DRY-RUN: arquivaria captura em #{archive_path(capture)}")
        end
        return Result.new(status: :dry_run, capture_path: capture_path, destination: destinations.first,
                          capture_id: capture['capture_id'], classification: classification,
                          candidates: candidates, relationships: candidate_results.flat_map { |item| item[:relationships] },
                          message: 'nenhuma gravação realizada')
      end

      if candidate_results.any? { |item| %w[UPDATE MERGE].include?(item[:action]) }
        raise ArgumentError, 'semantic review exige revisão manual (UPDATE/MERGE); captura mantida na inbox'
      end
      if candidate_results.any? { |item| item[:action] == 'CONFLICT' }
        raise ArgumentError, 'conflito de destino; captura mantida na inbox'
      end
      if candidate_results.all? { |item| item[:action] == 'SKIP' }
        log('NO_KNOWLEDGE', 'revisão semântica não identificou conhecimento novo; captura permanece na inbox')
        return Result.new(status: :no_knowledge, capture_path: capture_path, capture_id: capture['capture_id'],
                          classification: classification, candidates: candidates, relationships: [],
                          message: 'revisão semântica indicou ausência de conhecimento novo; captura mantida na inbox')
      end

      candidate_results.each do |item|
        if item[:markdown]
          FileUtils.mkdir_p(File.dirname(item[:destination]))
          KnowledgeCapture.write_exclusive(item[:destination], item[:markdown])
          log('WRITTEN', item[:destination])
          note = { 'path' => item[:destination], 'title' => item[:candidate].fetch('title'),
                   'capture_id' => capture['capture_id'] }
          ensure_index_link(note, dry_run: false)
        end
      end
      archive_capture(capture_path, capture)
      all_relationships = candidate_results.flat_map { |item| item[:relationships] }.uniq
      Result.new(status: :processed, capture_path: capture_path, destination: destinations.first,
                 capture_id: capture['capture_id'], classification: classification,
                 candidates: candidates, relationships: all_relationships, message: 'processada')
    end

    private

    def validate_shape(capture)
      required = %w[schema_version capture_id captured_at source content]
      allowed = required + %w[project type tags]
      raise ArgumentError, 'CanonicalCapture deve ser um objeto JSON' unless capture.is_a?(Hash)
      raise ArgumentError, "campos obrigatórios ausentes: #{(required - capture.keys).join(', ')}" unless (required - capture.keys).empty?
      raise ArgumentError, "campos não reconhecidos: #{(capture.keys - allowed).join(', ')}" unless (capture.keys - allowed).empty?
      raise ArgumentError, 'source deve ser um objeto' unless capture['source'].is_a?(Hash)
      raise ArgumentError, 'source.provider/title e content devem ser texto' unless
        %w[provider title].all? { |key| capture['source'][key].is_a?(String) } && capture['content'].is_a?(String)
      source_fields = %w[provider title conversation_id url]
      raise ArgumentError, "campos source não reconhecidos: #{(capture['source'].keys - source_fields).join(', ')}" unless
        (capture['source'].keys - source_fields).empty?
      %w[schema_version capture_id captured_at].each do |field|
        raise ArgumentError, "#{field} deve ser texto" unless capture[field].is_a?(String)
      end
      %w[project type].each do |field|
        raise ArgumentError, "#{field} deve ser texto" if capture.key?(field) && !capture[field].is_a?(String)
      end
      if capture.key?('tags') && (!capture['tags'].is_a?(Array) || capture['tags'].any? { |tag| !tag.is_a?(String) })
        raise ArgumentError, 'tags devem ser uma lista de textos'
      end
    end

    def normalize(capture)
      capture.merge(
        'content' => capture.fetch('content').gsub("\r\n", "\n").strip,
        'source' => capture.fetch('source').transform_values { |value| value.is_a?(String) ? value.strip : value },
        'tags' => Array(capture['tags']).map { |tag| tag.strip.downcase }.uniq.sort
      )
    end

    def destination_for(candidate, capture)
      folder = CATEGORY_DIRECTORIES.fetch(candidate.fetch('type'))
      if candidate['type'] == 'projeto'
        folder = File.join(folder, slug(capture['project'] || candidate['project']))
      end
      date = Time.iso8601(capture.fetch('captured_at')).utc.strftime('%Y-%m')
      filename = %w[padrao decisao aprendizado].include?(candidate['type']) ? "#{date}-#{slug(candidate.fetch('title'))}.md" : "#{slug(candidate.fetch('title'))}.md"
      File.join(@vault, folder, filename)
    end

    def semantic_note_content(path)
      text = File.read(path)
      text = text.sub(/\A---\s*\n.*?\n---\s*\n/m, '')
      text.sub(/\A\s*#\s+[^\n]+\n?/, '').strip
    end

    def render(capture, candidate, relationships, candidate_count: 1)
      created = Time.iso8601(capture.fetch('captured_at')).localtime.strftime('%Y-%m-%d')
      tags = (candidate['tags'] + [capture.dig('source', 'provider'), 'capture']).uniq
      related = relationships.map do |item|
        relative = Pathname.new(item.fetch('path')).relative_path_from(Pathname.new(@vault)).to_s.sub(/\.md\z/, '')
        "[[#{relative}|#{item.fetch('title')}]]"
      end
      body = case candidate.fetch('type')
             when 'decisao'
               "## Contexto\n[fato] Captura #{capture.fetch('capture_id')} (#{capture.dig('source', 'provider')}); título de origem: #{capture.dig('source', 'title')}.\n\n## Decisão\n#{candidate.fetch('content')}\n\n## Alternativas descartadas\nNão registradas na captura.\n\n## Trade-offs aceitos\nNão registrados na captura.\n\n## Relacionadas\n#{related.empty? ? 'Sem relação confirmada com notas existentes.' : related.join(' · ')}"
             when 'padrao'
               "## Problema que resolve\n#{candidate.fetch('summary')}\n\n## Forma\n#{candidate.fetch('content')}\n\n## Armadilhas\nNão registradas na captura.\n\n## Onde está em uso\n#{related.empty? ? 'Não informado.' : related.join(' · ')}"
             else
               "## Sintoma\n#{candidate.fetch('summary')}\n\n## Causa raiz\nNão informada na captura.\n\n## O que não era\nNão informado na captura.\n\n## Correção\n#{candidate.fetch('content')}"
             end
      frontmatter = {
        'tipo' => candidate.fetch('type'),
        'projeto' => candidate['project'] || 'transversal',
        'tags' => tags,
        'criado' => created,
        'atualizado' => (@today || Date.today).iso8601,
        'status' => 'ativo',
        'capture_id' => capture.fetch('capture_id'),
        'captured_at' => capture.fetch('captured_at'),
        'source_provider' => capture.dig('source', 'provider')
      }
      frontmatter['candidate_count'] = candidate_count if candidate_count > 1
      yaml = YAML.dump(frontmatter).sub(/\A---\s*\n/, '')
      "---\n#{yaml}---\n\n# #{candidate.fetch('title')}\n\n#{body}\n"
    end

    def existing_notes
      Dir.glob(File.join(@vault, '**', '*.md')).each_with_object([]) do |path, notes|
        next if File.symlink?(path)
        ensure_vault_path!(path)
        text = File.read(path)
        frontmatter = text.match(/\A---\s*\n(.*?)\n---\s*\n/m)&.captures&.first
        title = text[/^#\s+(.+)$/, 1]
        next unless frontmatter && title

        notes << { 'path' => path, 'title' => title.strip,
                   'capture_id' => frontmatter[/^capture_id:\s*['"]?([^'"\n]+)['"]?\s*$/, 1],
                   'candidate_count' => frontmatter[/^candidate_count:\s*(\d+)\s*$/, 1]&.to_i }
      end
    end

    def ensure_index_link(note, dry_run:)
      index = File.join(@vault, '00-indice-mestre.md')
      raise ArgumentError, "índice mestre ausente: #{index}" unless File.file?(index)
      raise ArgumentError, "índice mestre é symlink: #{index}" if File.symlink?(index)
      ensure_vault_path!(index)
      relative = Pathname.new(note.fetch('path')).relative_path_from(Pathname.new(@vault)).to_s.sub(/\.md\z/, '')
      link = "    - [[#{relative}|#{note.fetch('title')}]]"
      text = File.read(index)
      return if text.include?("[[#{relative}|")

      area = relative.split(File::SEPARATOR).first
      marker = "- [#{area}/](#{area}/)"
      line_index = text.lines.index { |line| line.start_with?(marker) }
      raise ArgumentError, "área #{area} ausente no índice mestre; captura mantida na inbox" unless line_index
      lines = text.lines
      insertion = line_index + 1
      insertion += 1 while insertion < lines.length && lines[insertion].start_with?('    - [[')
      lines.insert(insertion, link + "\n")
      return if dry_run

      File.write(index, lines.join)
    end

    def finish_duplicate(capture_path, capture, note, dry_run)
      if dry_run
        @stdout.puts("DRY-RUN: arquivaria captura em #{archive_path(capture)}")
        return Result.new(status: :dry_run, capture_path: capture_path, destination: note.fetch('path'),
                          capture_id: capture['capture_id'], candidates: [], relationships: [],
                          message: 'duplicate/skip por capture_id; nenhuma gravação realizada')
      end
      archive_capture(capture_path, capture)
      Result.new(status: :duplicate, capture_path: capture_path, destination: note.fetch('path'),
                 capture_id: capture['capture_id'], candidates: [], relationships: [],
                 message: 'duplicate/skip por capture_id; capture arquivado como já processado')
    end

    def archive_path(capture)
      File.join(@vault, '99-inbox', ARCHIVE_DIRECTORY, "capture-#{capture.fetch('capture_id')}.json")
    end

    def archive_capture(capture_path, capture)
      destination = archive_path(capture)
      archive_directory = File.dirname(destination)
      raise ArgumentError, "diretório de archive é symlink: #{archive_directory}" if File.symlink?(archive_directory)
      ensure_vault_path!(destination)
      FileUtils.mkdir_p(archive_directory)
      if File.exist?(destination)
        raise ArgumentError, "arquivo de archive é symlink: #{destination}" if File.symlink?(destination)
        unless File.binread(destination) == File.binread(capture_path)
          raise ArgumentError, "arquivo de archive já existe com conteúdo diferente: #{destination}; captura mantida na inbox"
        end
        File.delete(capture_path)
        log('ARCHIVED', "#{destination} (cópia idêntica já arquivada; duplicate removido da inbox)")
      else
        File.link(capture_path, destination)
        File.delete(capture_path)
        log('ARCHIVED', destination)
      end
    end

    def ensure_vault_path!(path)
      expanded = File.expand_path(path)
      lexical_prefix = "#{@vault}#{File::SEPARATOR}"
      raise ArgumentError, "caminho fora do vault: #{expanded}" unless expanded == @vault || expanded.start_with?(lexical_prefix)

      existing = expanded
      until File.exist?(existing) || File.symlink?(existing)
        parent = File.dirname(existing)
        break if parent == existing
        existing = parent
      end
      resolved = File.realpath(existing)
      real_prefix = "#{@vault_real}#{File::SEPARATOR}"
      raise ArgumentError, "caminho resolve para fora do vault: #{expanded}" unless
        resolved == @vault_real || resolved.start_with?(real_prefix)
    end

    def log(stage, detail)
      @stdout.puts("#{stage}: #{detail}")
    end

    def slug(text)
      value = text.to_s.downcase.unicode_normalize(:nfkd).gsub(/\p{Mn}/, '')
      value.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
    end

  end
end
