# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'stringio'
require 'tmpdir'
require 'yaml'
require_relative '../processors/knowledge_processor'
require_relative '../processors/rule_based_reasoning_provider'

class KnowledgeProcessorTest < Minitest::Test
  class PreviewProvider
    include SecondBrain::ReasoningProvider

    attr_reader :semantic_calls

    def initialize(candidate:, relationships: [], semantic_result: nil, semantic_error: nil)
      @candidate = candidate
      @relationships = relationships
      @semantic_result = semantic_result
      @semantic_error = semantic_error
      @semantic_calls = []
    end

    def classify(capture:, taxonomy:, context: nil)
      { 'type' => 'decisao', 'confidence' => 0.94 }
    end

    def extract_knowledge(capture:, context: nil)
      [@candidate]
    end

    def find_relationships(knowledge:, existing_knowledge:, context: nil)
      @relationships.select { |relationship| existing_knowledge.any? { |note| note['path'] == relationship['path'] } }
    end

    def review_semantics(candidate:, related_notes:)
      @semantic_calls << { candidate: candidate, related_notes: related_notes }
      raise @semantic_error if @semantic_error

      @semantic_result
    end
  end

  def setup
    @tmp = Dir.mktmpdir('second-brain-processor')
    @vault = File.join(@tmp, 'vault')
    FileUtils.mkdir_p([File.join(@vault, '99-inbox'), File.join(@vault, '02-decisoes'),
                       File.join(@vault, '01-padroes'), File.join(@vault, '06-aprendizados')])
    File.write(File.join(@vault, '00-indice-mestre.md'), <<~INDEX)
      # Índice mestre
      - [01-padroes/](01-padroes/)
      - [02-decisoes/](02-decisoes/)
      - [06-aprendizados/](06-aprendizados/)
    INDEX
    @stdout = StringIO.new
    @processor = SecondBrain::KnowledgeProcessor.new(
      vault: @vault, reasoning_provider: SecondBrain::RuleBasedReasoningProvider.new,
      stdout: @stdout, today: Date.new(2026, 10, 7)
    )
  end

  def teardown
    FileUtils.remove_entry(@tmp)
  end

  def test_valid_decision_is_distilled_persisted_indexed_and_archived
    path = write_capture(type: 'decision', content: "Decisão: usar pipeline agnóstico.\nContexto adicional da conversa não deve virar nota.\n\nArquitetura: Adapter -> Inbox")
    result = @processor.process(path)

    assert_equal :processed, result.status
    assert File.file?(result.destination)
    assert_includes File.read(result.destination), 'usar pipeline agnóstico'
    refute_includes File.read(result.destination), 'Adapter -> Inbox'
    refute_includes File.read(result.destination), 'Contexto adicional da conversa'
    assert_includes File.read(result.destination), 'capture_id: 11111111-1111-4111-8111-111111111111'
    assert_includes File.read(File.join(@vault, '00-indice-mestre.md')), '[[02-decisoes/2026-10-pipeline-agnostico|Pipeline agnóstico]]'
    assert File.file?(archive_path)
    refute File.exist?(path)
  end

  def test_created_and_updated_use_local_date_policy_and_capture_timestamp_is_preserved
    path = write_capture(type: 'decision', content: 'Decisão: manter timestamp original.')
    capture_timestamp = JSON.parse(File.read(path)).fetch('captured_at')
    expected_created = Time.iso8601(capture_timestamp).localtime.strftime('%Y-%m-%d')
    expected_updated = @processor.instance_variable_get(:@today).iso8601

    result = @processor.process(path)
    frontmatter = YAML.safe_load(File.read(result.destination).split(/^---\s*$/)[1], aliases: false)

    assert_equal expected_created, frontmatter.fetch('criado')
    assert_equal expected_updated, frontmatter.fetch('atualizado')
    assert_equal capture_timestamp, frontmatter.fetch('captured_at')
  end

  def test_frontmatter_is_valid_yaml_and_preserves_required_protocol_fields
    path = write_capture(type: 'decision', content: 'Decisão: preservar metadados.')

    result = @processor.process(path)
    frontmatter = YAML.safe_load(File.read(result.destination).split(/^---\s*$/)[1], aliases: false)

    assert_equal %w[tipo projeto tags criado atualizado status capture_id captured_at source_provider].sort,
                 frontmatter.keys.sort
    assert_equal 'decisao', frontmatter.fetch('tipo')
    assert_equal 'ai-agent-config', frontmatter.fetch('projeto')
    assert_equal %w[second-brain test chatgpt capture], frontmatter.fetch('tags')
  end

  def test_invalid_capture_stays_in_inbox
    path = write_capture(type: 'decision', content: '  ')
    assert_raises(ArgumentError) { @processor.process(path) }
    assert File.file?(path)
    refute File.exist?(archive_path)
  end

  def test_architecture_and_learning_are_classified_by_local_provider
    provider = SecondBrain::RuleBasedReasoningProvider.new
    architecture = capture(type: 'architecture', content: "Arquitetura: usar módulos coesos.\nComponentes locais.")
    learning = capture(type: 'learning', content: 'Aprendizado: normalizar antes de comparar.')

    assert_equal 'decisao', provider.classify(capture: architecture, taxonomy: SecondBrain::KnowledgeProcessor::CATEGORIES)['type']
    assert_equal 'aprendizado', provider.classify(capture: learning, taxonomy: SecondBrain::KnowledgeProcessor::CATEGORIES)['type']
    assert_equal 'decisao', provider.extract_knowledge(capture: architecture).first['type']
    assert_equal 'aprendizado', provider.extract_knowledge(capture: learning).first['type']
  end

  def test_unstructured_capture_is_not_promoted_as_a_full_note
    path = write_capture(type: 'decision', content: 'Discussão longa sem marcador de decisão.')

    result = @processor.process(path)
    assert_equal :no_knowledge, result.status
    assert File.file?(path)
    assert_empty Dir.glob(File.join(@vault, '02-decisoes', '*.md'))
  end

  def test_relationships_link_only_to_existing_notes
    existing = File.join(@vault, '01-padroes', 'pipeline-canonico.md')
    File.write(existing, "---\ntipo: padrao\n---\n\n# Pipeline canônico\n")
    path = write_capture(type: 'decision', content: 'Decisão: integrar com Pipeline canônico.')

    result = @processor.process(path)

    assert_equal 1, result.relationships.length
    assert_includes File.read(result.destination), '[[01-padroes/pipeline-canonico|Pipeline canônico]]'
  end

  def test_dry_run_does_not_write_note_index_or_archive
    path = write_capture(type: 'decision', content: 'Decisão: usar captura manual.')
    before_index = File.read(File.join(@vault, '00-indice-mestre.md'))
    FileUtils.remove_entry(File.join(@vault, '02-decisoes'))

    result = @processor.process(path, dry_run: true)

    assert_equal :dry_run, result.status
    assert File.file?(path)
    refute File.exist?(result.destination)
    refute File.exist?(File.join(@vault, '02-decisoes'))
    refute File.exist?(File.join(@vault, '99-inbox', 'processed'))
    assert_equal before_index, File.read(File.join(@vault, '00-indice-mestre.md'))
  end

  def test_dry_run_prints_candidate_preview_without_writing_anything
    related_path = File.join(@vault, '01-padroes', 'existing-concept.md')
    File.write(related_path, "---\ntipo: padrao\n---\n\n# Existing Concept\n")
    capture_path = write_capture(type: 'decision', content: 'Decisão: preview detalhado.')
    candidate = {
      'type' => 'decisao', 'title' => 'Idempotency Preview',
      'summary' => 'Resumo do candidato.', 'content' => 'Conteúdo candidato em detalhe.',
      'confidence' => 0.94, 'tags' => [],
      'evidence' => ['Trecho que fundamenta a decisão.', 'Authorization: Bearer sk-ant-testfixture123456789']
    }
    relationships = [{ 'title' => 'Existing Concept', 'path' => related_path }]
    provider = PreviewProvider.new(candidate: candidate, relationships: relationships)
    processor = SecondBrain::KnowledgeProcessor.new(vault: @vault, reasoning_provider: provider, stdout: @stdout,
                                                    today: Date.new(2026, 10, 7))
    before = vault_snapshot

    result = processor.process(capture_path, dry_run: true)

    assert_equal :dry_run, result.status
    assert_includes @stdout.string, 'CANDIDATE #1'
    assert_includes @stdout.string, 'confidence: 0.94'
    assert_includes @stdout.string, 'Trecho que fundamenta a decisão.'
    assert_includes @stdout.string, 'Existing Concept'
    assert_includes @stdout.string, "destination: #{File.join(@vault, '02-decisoes', '2026-10-idempotency-preview.md')}"
    assert_includes @stdout.string, 'action: LINK'
    assert_includes @stdout.string, '[REDACTED]'
    refute_includes @stdout.string, 'sk-ant-testfixture123456789'
    refute_includes @stdout.string, 'stderr:'
    refute_includes @stdout.string, 'argv:'
    assert_equal before, vault_snapshot, 'dry-run não deve criar, alterar ou remover nenhum arquivo ou diretório'
  end

  def test_dry_run_reports_destination_conflict_without_writing
    capture_path = write_capture(type: 'decision', content: 'Decisão: detectar conflito no preview.')
    conflict_path = File.join(@vault, '02-decisoes', '2026-10-conflicting-note.md')
    File.write(conflict_path, <<~NOTE)
      ---
      tipo: decisao
      capture_id: 22222222-2222-4222-8222-222222222222
      ---

      # Conflicting Note
    NOTE
    candidate = {
      'type' => 'decisao', 'title' => 'Conflicting Note', 'summary' => 'Resumo.',
      'content' => 'Conteúdo.', 'confidence' => 0.9, 'evidence' => ['Evidência.'], 'tags' => []
    }
    processor = SecondBrain::KnowledgeProcessor.new(
      vault: @vault, reasoning_provider: PreviewProvider.new(candidate: candidate), stdout: @stdout,
      today: Date.new(2026, 10, 7)
    )
    before = vault_snapshot

    result = processor.process(capture_path, dry_run: true)

    assert_equal :dry_run, result.status
    assert_includes @stdout.string, 'action: CONFLICT'
    assert_includes @stdout.string, 'manteria captura na inbox'
    refute_includes @stdout.string, 'arquivaria captura'
    assert_equal before, vault_snapshot
  end

  def test_no_relationship_skips_semantic_call_and_keeps_create
    capture_path = write_capture(type: 'decision', content: 'Decisão: conceito novo sem relação.')
    provider = PreviewProvider.new(candidate: semantic_candidate)
    processor = processor_for(provider)

    processor.process(capture_path, dry_run: true)

    assert_empty provider.semantic_calls
    assert_includes @stdout.string, 'final_action: CREATE'
  end

  def test_semantic_skip_does_not_create_and_keeps_capture_in_inbox
    related = existing_note('concept.md', 'Existing Concept', "# Existing Concept\n\nIdeia já registrada.\n")
    provider = semantic_provider('skip', target: 'Existing Concept')
    path = write_capture(type: 'decision', content: 'Decisão: repetir conceito existente.')

    result = processor_for(provider).process(path)

    assert_equal :no_knowledge, result.status
    assert File.file?(path)
    refute File.exist?(archive_path)
    refute File.exist?(destination_for('Novo conceito'))
    assert_equal 1, provider.semantic_calls.length
    assert_equal 'Ideia já registrada.', provider.semantic_calls.first[:related_notes].first['content']
    assert File.file?(related)
  end

  def test_update_and_merge_are_proposals_and_never_write
    %w[update merge].each do |action|
      reset_capture
      existing_note('concept.md', 'Existing Concept', "# Existing Concept\n\nNota atual.\n")
      provider = semantic_provider(action, target: 'Existing Concept', novel_information: ['Detalhe adicional'])
      path = write_capture(type: 'decision', content: 'Decisão: acrescentar detalhe.')
      before = vault_snapshot

      error = assert_raises(ArgumentError) { processor_for(provider).process(path) }

      assert_includes error.message, 'revisão manual'
      assert File.file?(path)
      assert_equal before, vault_snapshot
      @stdout = StringIO.new
      processor_for(provider).process(path, dry_run: true)
      assert_includes @stdout.string, "final_action: #{action.upcase}_REVIEW_REQUIRED"
      assert_includes @stdout.string, 'Detalhe adicional'
    end
  end

  def test_link_creates_separate_note_and_preserves_relationship
    existing_note('related.md', 'Related Concept', "# Related Concept\n\nConceito próximo.\n")
    provider = semantic_provider('link')
    path = write_capture(type: 'decision', content: 'Decisão: conceito relacionado independente.')

    result = processor_for(provider).process(path)

    assert_equal :processed, result.status
    assert File.file?(result.destination)
    assert_includes File.read(result.destination), '[[01-padroes/related|Related Concept]]'
    assert File.file?(archive_path)
  end

  def test_create_semantic_decision_creates_a_new_note
    existing_note('unrelated.md', 'Related Candidate', "# Related Candidate\n\nContexto fornecido pelo resolver.\n")
    provider = semantic_provider('create', related_title: 'Related Candidate')
    path = write_capture(type: 'decision', content: 'Decisão: novo conceito apesar da relação contextual.')

    result = processor_for(provider).process(path)

    assert_equal :processed, result.status
    assert File.file?(result.destination)
    assert File.file?(archive_path)
  end

  def test_low_confidence_uses_link_as_conservative_action
    existing_note('related.md', 'Related Concept', "# Related Concept\n\nContexto.\n")
    provider = semantic_provider('merge', confidence: 0.2, target: 'Related Concept')
    path = write_capture(type: 'decision', content: 'Decisão: avaliação sem confiança suficiente.')
    processor = processor_for(provider)

    result = processor.process(path, dry_run: true)

    assert_equal :dry_run, result.status
    assert_includes @stdout.string, 'final_action: LINK'
    assert File.file?(path)
    refute File.exist?(archive_path)
  end

  def test_semantic_review_failure_keeps_capture_recoverable
    existing_note('related.md', 'Related Concept', "# Related Concept\n\nContexto.\n")
    provider = PreviewProvider.new(candidate: semantic_candidate,
      relationships: [{ 'title' => 'Related Concept', 'path' => File.join(@vault, '01-padroes', 'related.md') }],
      semantic_error: IOError.new('provider failure'))
    path = write_capture(type: 'decision', content: 'Decisão: falha técnica durante review.')

    assert_raises(IOError) { processor_for(provider).process(path) }
    assert File.file?(path)
    refute File.exist?(archive_path)
    refute File.exist?(destination_for('Semantic candidate'))
  end

  def test_semantic_review_receives_only_configured_number_of_related_notes
    paths = 1.upto(3).map do |index|
      existing_note("related-#{index}.md", "Related #{index}", "# Related #{index}\n\nNota #{index}.\n")
    end
    relationships = paths.map.with_index do |path, index|
      { 'title' => "Related #{index + 1}", 'path' => path }
    end
    provider = PreviewProvider.new(candidate: semantic_candidate, relationships: relationships,
      semantic_result: semantic_result('link'))
    path = write_capture(type: 'decision', content: 'Decisão: limitar notas comparadas.')

    processor_for(provider, max_semantic_candidates: 2).process(path, dry_run: true)

    assert_equal 1, provider.semantic_calls.length
    assert_equal ['Related 1', 'Related 2'], provider.semantic_calls.first[:related_notes].map { |note| note['title'] }
  end

  def test_destination_conflict_prevents_semantic_review
    conflict = File.join(@vault, '02-decisoes', '2026-10-semantic-candidate.md')
    File.write(conflict, "---\ntipo: decisao\n---\n\n# Semantic candidate\n")
    related_path = existing_note('related.md', 'Related Concept', "# Related Concept\n\nContexto.\n")
    provider = PreviewProvider.new(candidate: semantic_candidate,
      relationships: [{ 'title' => 'Related Concept', 'path' => related_path }],
      semantic_result: semantic_result('merge', target: 'Related Concept'))
    path = write_capture(type: 'decision', content: 'Decisão: destino conflitante.')

    processor_for(provider).process(path, dry_run: true)

    assert_empty provider.semantic_calls
    assert_includes @stdout.string, 'final_action: CONFLICT'
  end

  def test_repeat_with_same_capture_id_is_idempotent
    path = write_capture(type: 'decision', content: 'Decisão: usar processamento idempotente.')
    first = @processor.process(path)
    # Simula redelivery antes do archive, como ocorreria se uma falha acontecesse após o write.
    FileUtils.cp(archive_path, path)

    second = @processor.process(path)

    assert_equal first.destination, second.destination
    assert_equal :duplicate, second.status
    assert_includes second.message, 'duplicate/skip'
    assert_equal 1, Dir.glob(File.join(@vault, '02-decisoes', '*.md')).length
    assert File.file?(archive_path)
  end

  def test_existing_capture_id_is_detected_before_classification
    path = write_capture(type: 'decision', content: 'Decisão: criar nota existente.')
    first = @processor.process(path)
    FileUtils.cp(archive_path, path)
    capture = JSON.parse(File.read(path))
    capture['content'] = 'texto sem seção reconhecida'
    File.write(path, JSON.pretty_generate(capture))
    FileUtils.rm_f(archive_path)

    result = @processor.process(path)

    assert_equal :duplicate, result.status
    assert_equal first.destination, result.destination
    assert File.file?(archive_path)
    refute File.exist?(path)
    assert_equal 1, Dir.glob(File.join(@vault, '02-decisoes', '*.md')).length
  end

  def test_different_capture_id_at_same_destination_is_a_conflict
    first_path = write_capture(type: 'decision', content: 'Decisão: título conflitante.')
    first = @processor.process(first_path)
    second_path = File.join(@vault, '99-inbox', 'capture-22222222-2222-4222-8222-222222222222.json')
    second_capture = capture(type: 'decision', content: 'Decisão: título conflitante.')
    second_capture['capture_id'] = '22222222-2222-4222-8222-222222222222'
    File.write(second_path, JSON.pretty_generate(second_capture))
    before = File.read(first.destination)

    error = assert_raises(ArgumentError) { @processor.process(second_path) }

    assert_includes error.message, 'destino já existe'
    assert_equal before, File.read(first.destination)
    assert File.file?(second_path)
    refute File.exist?(File.join(@vault, '99-inbox', 'processed', 'capture-22222222-2222-4222-8222-222222222222.json'))
  end

  def test_processed_capture_is_rejected
    processed = File.join(@vault, '99-inbox', 'processed')
    FileUtils.mkdir_p(processed)
    path = File.join(processed, 'capture-11111111-1111-4111-8111-111111111111.json')
    File.write(path, JSON.pretty_generate(capture(type: 'decision', content: 'Decisão: não processar archive.')))

    error = assert_raises(ArgumentError) { @processor.process(path) }

    assert_includes error.message, 'fora da inbox ativa'
    assert File.file?(path)
  end

  def test_file_outside_active_inbox_is_rejected
    path = File.join(@tmp, 'capture.json')
    File.write(path, JSON.pretty_generate(capture(type: 'decision', content: 'Decisão: caminho inválido.')))

    assert_raises(ArgumentError) { @processor.process(path) }
    assert File.file?(path)
  end

  def test_traversal_and_symlink_to_file_outside_inbox_are_rejected
    inbox = File.join(@vault, '99-inbox')
    outside = File.join(@tmp, 'outside.json')
    File.write(outside, JSON.pretty_generate(capture(type: 'decision', content: 'Decisão: não seguir link.')))
    traversal = File.join(inbox, '..', 'outside.json')
    FileUtils.cp(outside, File.join(@vault, 'outside.json'))
    symlink = File.join(inbox, 'capture-link.json')
    File.symlink(outside, symlink)

    assert_raises(ArgumentError) { @processor.process(traversal) }
    assert_raises(ArgumentError) { @processor.process(symlink) }
    assert File.file?(outside)
    assert File.symlink?(symlink)
  end

  def test_write_failure_keeps_capture_recoverable
    path = write_capture(type: 'decision', content: 'Decisão: manter a origem recuperável.')
    KnowledgeCapture.stub(:write_exclusive, ->(*) { raise IOError, 'simulated write failure' }) do
      assert_raises(IOError) { @processor.process(path) }
    end
    assert File.file?(path)
    refute File.exist?(archive_path)
  end

  def test_render_failure_keeps_capture_in_active_inbox
    path = write_capture(type: 'decision', content: 'Decisão: falha antes da gravação.')
    @processor.stub(:render, ->(*) { raise ArgumentError, 'simulated render failure' }) do
      assert_raises(ArgumentError) { @processor.process(path) }
    end
    assert File.file?(path)
    refute File.exist?(archive_path)
    refute File.exist?(File.join(@vault, '02-decisoes', '2026-10-falha-antes-da-gravacao.md'))
  end

  def test_invalid_json_is_not_archived
    path = File.join(@vault, '99-inbox', 'capture-11111111-1111-4111-8111-111111111111.json')
    File.write(path, '{ invalid json')

    assert_raises(JSON::ParserError) { @processor.process(path) }
    assert File.file?(path)
    refute File.exist?(archive_path)
  end

  def test_archive_conflict_keeps_active_capture
    path = write_capture(type: 'decision', content: 'Decisão: manter capture após conflito de archive.')
    FileUtils.mkdir_p(File.dirname(archive_path))
    File.write(archive_path, '{"different":"capture"}')

    error = assert_raises(ArgumentError) { @processor.process(path) }

    assert_includes error.message, 'archive já existe com conteúdo diferente'
    assert File.file?(path)
    assert File.file?(archive_path)
  end

  def test_missing_master_index_keeps_capture_in_inbox_after_note_write
    path = write_capture(type: 'decision', content: 'Decisão: registrar nota antes do índice.')
    File.delete(File.join(@vault, '00-indice-mestre.md'))

    assert_raises(ArgumentError) { @processor.process(path) }
    assert File.file?(path)
    assert_equal 1, Dir.glob(File.join(@vault, '02-decisoes', '*.md')).length
    refute File.exist?(archive_path)
  end

  private

  def capture(type:, content:)
    {
      'schema_version' => '1.0',
      'capture_id' => '11111111-1111-4111-8111-111111111111',
      'captured_at' => '2026-10-07T02:35:14Z',
      'source' => { 'provider' => 'chatgpt', 'title' => 'Teste de captura' },
      'content' => content, 'project' => 'ai-agent-config', 'type' => type,
      'tags' => ['second-brain', 'test']
    }
  end

  def write_capture(type:, content:)
    path = File.join(@vault, '99-inbox', 'capture-11111111-1111-4111-8111-111111111111.json')
    File.write(path, JSON.pretty_generate(capture(type: type, content: content)))
    path
  end

  def semantic_candidate
    { 'type' => 'decisao', 'title' => 'Semantic Candidate', 'summary' => 'Resumo semântico.',
      'content' => 'Conteúdo semântico novo.', 'confidence' => 0.94, 'evidence' => ['Evidência.'], 'tags' => [] }
  end

  def semantic_result(action, confidence: 0.96, target: nil, novel_information: [])
    target ||= 'Related Concept' if %w[update merge skip].include?(action)
    { 'action' => action, 'confidence' => confidence, 'target' => target,
      'reason' => 'Decisão semântica de teste.', 'novel_information' => novel_information }
  end

  def semantic_provider(action, confidence: 0.96, target: nil, related_title: nil, novel_information: [])
    title = related_title || target || 'Related Concept'
    note_path = Dir.glob(File.join(@vault, '**', '*.md')).find do |candidate_path|
      File.read(candidate_path).match?(/^#\s+#{Regexp.escape(title)}\s*$/)
    end
    raise "nota relacionada ausente: #{title}" unless note_path

    PreviewProvider.new(candidate: semantic_candidate,
      relationships: [{ 'title' => title, 'path' => note_path }],
      semantic_result: semantic_result(action, confidence: confidence, target: target,
                                       novel_information: novel_information))
  end

  def processor_for(provider, max_semantic_candidates: 5)
    SecondBrain::KnowledgeProcessor.new(vault: @vault, reasoning_provider: provider, stdout: @stdout,
      today: Date.new(2026, 10, 7), max_semantic_candidates: max_semantic_candidates)
  end

  def existing_note(filename, title, content)
    path = File.join(@vault, '01-padroes', filename)
    File.write(path, "---\ntipo: padrao\n---\n\n#{content}")
    path
  end

  def destination_for(title)
    File.join(@vault, '02-decisoes', "2026-10-#{title.downcase.gsub(/[^a-z0-9]+/, '-')}.md")
  end

  def reset_capture
    FileUtils.rm_f(File.join(@vault, '99-inbox', 'capture-11111111-1111-4111-8111-111111111111.json'))
    FileUtils.rm_f(File.join(@vault, '01-padroes', 'concept.md'))
    @stdout = StringIO.new
  end

  def archive_path
    File.join(@vault, '99-inbox', 'processed', 'capture-11111111-1111-4111-8111-111111111111.json')
  end

  def vault_snapshot
    Dir.glob(File.join(@vault, '**', '*'), File::FNM_DOTMATCH).sort.each_with_object({}) do |path, snapshot|
      next if %w[. ..].include?(File.basename(path))

      relative = path.delete_prefix("#{@vault}/")
      snapshot[relative] = if File.symlink?(path)
                             [:symlink, File.readlink(path)]
                           elsif File.directory?(path)
                             :directory
                           else
                             [:file, File.binread(path)]
                           end
    end
  end
end
