#!/usr/bin/env ruby
# encoding: UTF-8
# frozen_string_literal: true

Encoding.default_external = Encoding::UTF_8
Encoding.default_internal = Encoding::UTF_8

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'digest'
require_relative 'context_compiler'
require_relative 'validate_structure'

class IntegrationTest < Minitest::Test
  def setup
    @temp = Dir.mktmpdir('ai-agent-config-tests-')
    @root = File.join(@temp, 'source')
    FileUtils.mkdir_p(@root)
    source = File.expand_path('..', __dir__)
    %w[README.md AGENTS.md CLAUDE.md GEMINI.md profiles skills knowledge learning capture processors schemas
       templates projects prompts scripts context docs tests adapters config core agents
       roles workflows context-packs models context-index.md].each do |name|
      FileUtils.cp_r(File.join(source, name), @root)
    end
    Dir[File.join(@root, '**', '*.ai-agent-config.bak')].each { |path| FileUtils.rm_f(path) }
  end

  def teardown
    # Somente o diretório exclusivo criado pelo próprio teste é descartado.
    FileUtils.remove_entry(@temp) if @temp && File.directory?(@temp)
  end

  def errors
    StructureValidation.validate(@root)
  end

  def extra_skill(body)
    dir = File.join(@root, 'skills', 'fixture')
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, 'SKILL.md'), body)
  end

  def test_valid_source
    assert_empty errors
  end

  def test_validation_is_independent_of_process_locale
    output, status = Open3.capture2e(
      { 'LANG' => 'C', 'LC_ALL' => 'C' },
      'ruby', File.join(@root, 'scripts/validate_structure.rb'), @root
    )

    assert status.success?, output
  end

  def test_context_compiler_renders_deterministically
    first = ContextCompiler.render(root: @root, adapter: 'codex', root_label: '/portable/root')
    second = ContextCompiler.render(root: @root, adapter: 'codex', root_label: '/portable/root')
    assert_equal first, second
    assert_includes first, ContextCompiler::GENERATED_MARK
    assert_includes first, '/portable/root'
    assert_includes first, '<!-- source: core/kernel.md -->'
    assert_includes first, '<!-- source: core/agent-platform.md -->'
    assert_includes first, '<!-- source: context-index.md -->'
  end

  def test_agent_catalog_rejects_traversal
    catalog = File.join(@root, 'agents/catalog.yml')
    File.write(catalog, File.read(catalog).sub(
      'definition: agents/orchestrator/AGENT.md',
      'definition: ../outside.md'
    ))
    assert errors.any? { |error| error.include?('caminho inválido no catálogo') }
  end

  def test_agent_catalog_rejects_duplicate_keys
    catalog = File.join(@root, 'agents/catalog.yml')
    File.write(catalog, File.read(catalog).sub(
      '    role: roles/senior-engineer.brief.md',
      "    role: roles/senior-engineer.brief.md\n    role: roles/senior-engineer.brief.md"
    ))
    assert errors.any? { |error| error.include?('chaves YAML duplicadas em agents/catalog.yml') }
  end

  def test_agent_catalog_requires_role
    catalog = File.join(@root, 'agents/catalog.yml')
    File.write(catalog, File.read(catalog, encoding: 'UTF-8').sub(
      "    role: roles/product-manager.brief.md\n",
      ''
    ))

    assert errors.any? { |error| error.include?('caminho inválido no catálogo: role') }
  end

  def test_agent_catalog_requires_all_mandatory_agents
    catalog = File.join(@root, 'agents/catalog.yml')
    text = File.read(catalog, encoding: 'UTF-8').sub(/^  performance-engineer:.*\z/m, '')
    File.write(catalog, text, encoding: 'UTF-8')

    assert errors.any? { |error| error.include?('agente obrigatório ausente: performance-engineer') }
  end

  def test_agent_catalog_definition_must_match_agent
    catalog = File.join(@root, 'agents/catalog.yml')
    text = File.read(catalog, encoding: 'UTF-8').sub(
      'definition: agents/product-manager/AGENT.md',
      'definition: agents/tester/AGENT.md'
    )
    File.write(catalog, text, encoding: 'UTF-8')

    assert errors.any? { |error| error.include?('definition fora da convenção') }
  end

  def test_agent_catalog_requires_non_empty_workflows_and_existing_skills
    catalog = File.join(@root, 'agents/catalog.yml')
    text = File.read(catalog, encoding: 'UTF-8')
      .sub("    workflows:\n      - workflows/product-discovery.md\n", "    workflows: []\n")
      .sub('      - troubleshooting', '      - skill-inexistente')
    File.write(catalog, text, encoding: 'UTF-8')

    validation_errors = errors
    assert validation_errors.any? { |error| error.include?('workflows inválidos no agente product-manager') }
    assert validation_errors.any? { |error| error.include?('skill inválida ou ausente no agente software-engineer') }
  end

  def test_agent_catalog_rejects_duplicate_workflows_and_skills
    catalog = File.join(@root, 'agents/catalog.yml')
    text = File.read(catalog, encoding: 'UTF-8')
      .sub(
        '      - workflows/security-review.md',
        "      - workflows/security-review.md\n      - workflows/security-review.md"
      )
      .sub(
        '      - architecture-review',
        "      - architecture-review\n      - architecture-review"
      )
    File.write(catalog, text, encoding: 'UTF-8')

    validation_errors = errors
    assert validation_errors.any? { |error| error.include?('workflows inválidos no agente security-engineer') }
    assert validation_errors.any? { |error| error.include?('skills inválidas no agente architect') }
  end

  def test_agent_catalog_requires_known_model_profile
    catalog = File.join(@root, 'agents/catalog.yml')
    text = File.read(catalog, encoding: 'UTF-8')
      .sub("    model_profile: analysis-medium\n", '')
      .sub('    model_profile: review-high', '    model_profile: profile-inexistente')
    File.write(catalog, text, encoding: 'UTF-8')

    validation_errors = errors
    assert validation_errors.any? { |error| error.include?('model_profile inválido no agente product-manager') }
    assert validation_errors.any? { |error| error.include?('model_profile inválido no agente code-reviewer') }
  end

  def test_model_mappings_cover_profiles_and_reject_duplicate_fallbacks
    antigravity = File.join(@root, 'adapters/antigravity/models.yaml')
    data = YAML.safe_load(File.read(antigravity, encoding: 'UTF-8'), aliases: false)
    data['profiles'].delete('review-high')
    data['profiles']['coding-high']['fallbacks'] << data['profiles']['coding-high']['fallbacks'].first
    File.write(antigravity, YAML.dump(data), encoding: 'UTF-8')

    validation_errors = errors
    assert validation_errors.any? { |error| error.include?('perfil review-high sem mapping para antigravity') }
    assert validation_errors.any? { |error| error.include?('fallbacks inválidos para coding-high em antigravity') }
  end

  def test_model_mappings_require_coherent_runtime_capabilities
    codex = File.join(@root, 'adapters/codex/models.yaml')
    data = YAML.safe_load(File.read(codex, encoding: 'UTF-8'), aliases: false)
    data['capabilities']['model_selection'] = 'advisory'
    File.write(codex, YAML.dump(data), encoding: 'UTF-8')

    assert errors.any? { |error| error.include?('capabilities incompatíveis para codex') }
  end

  def test_alias_runtime_requires_selector_for_every_candidate
    claude = File.join(@root, 'adapters/claude/models.yaml')
    data = YAML.safe_load(File.read(claude, encoding: 'UTF-8'), aliases: false)
    data['selectors'].delete('claude-sonnet-5-5')
    File.write(claude, YAML.dump(data), encoding: 'UTF-8')

    assert errors.any? { |error| error.include?('selector ausente para claude-sonnet-5-5 em claude') }
  end

  def test_model_resolver_uses_agent_profile_and_ordered_fallback
    script = File.join(@root, 'scripts/resolve-model.rb')
    output, status = Open3.capture2e('ruby', script, '--runtime', 'codex', '--agent',
                                    'software-engineer', '--unavailable', 'gpt-6.1-sol',
                                    '--format', 'json')

    assert status.success?, output
    result = JSON.parse(output)
    assert_equal 'coding-high', result.fetch('profile')
    assert_equal 'gpt-6-astra', result.fetch('model')
    assert_equal 'gpt-6-astra', result.fetch('host_selector')
    assert_equal 'exact', result.fetch('selection_mode')
    assert_equal true, result.fetch('materializable')
    assert_equal true, result.fetch('fallback')
  end

  def test_model_resolver_translates_claude_model_to_host_alias
    script = File.join(@root, 'scripts/resolve-model.rb')
    output, status = Open3.capture2e('ruby', script, '--runtime', 'claude', '--agent',
                                    'software-engineer', '--unavailable', 'claude-opus-5-5',
                                    '--format', 'json')

    assert status.success?, output
    result = JSON.parse(output)
    assert_equal 'claude-sonnet-5-5', result.fetch('model')
    assert_equal 'sonnet', result.fetch('host_selector')
    assert_equal 'alias', result.fetch('selection_mode')
    assert_equal true, result.fetch('materializable')
    assert_equal true, result.fetch('fallback')
  end

  def test_model_resolver_marks_antigravity_selection_as_advisory
    script = File.join(@root, 'scripts/resolve-model.rb')
    output, status = Open3.capture2e('ruby', script, '--runtime', 'antigravity', '--agent',
                                    'software-engineer', '--unavailable', 'gemini-3.1-pro-high',
                                    '--format', 'json')

    assert status.success?, output
    result = JSON.parse(output)
    assert_equal 'gemini-3.8-flash-high', result.fetch('model')
    refute result.key?('host_selector')
    assert_equal 'advisory', result.fetch('selection_mode')
    assert_equal false, result.fetch('materializable')
    assert_equal true, result.fetch('fallback')
  end

  def test_model_resolver_fails_closed_when_candidates_are_exhausted
    script = File.join(@root, 'scripts/resolve-model.rb')
    output, status = Open3.capture2e(
      'ruby', script, '--runtime', 'antigravity', '--profile', 'analysis-medium',
      '--unavailable', 'gemini-3.8-flash-medium,gemini-3.7-flash-medium,gemini-3.6-flash-medium'
    )

    refute status.success?
    assert_includes output, 'nenhum modelo disponível para analysis-medium em antigravity'
  end

  def test_context_route_must_match_agent_catalog
    catalog = File.join(@root, 'agents/catalog.yml')
    File.write(catalog, File.read(catalog).sub("      - workflows/incident-debug.md\n", ''))
    assert errors.any? { |error| error.include?('rota e catálogo divergem no workflow de software-engineer') }
  end

  def test_context_route_rejects_unknown_agent_and_role_mismatch
    index = File.join(@root, 'context-index.md')
    text = File.read(index, encoding: 'UTF-8')
      .sub(
        '| feature ou alteração de código | `software-engineer`',
        '| feature ou alteração de código | `agente-inexistente`'
      )
      .sub(
        '| problema, valor, escopo ou aceite ambíguo | `product-manager` | `roles/product-manager.brief.md`',
        '| problema, valor, escopo ou aceite ambíguo | `product-manager` | `roles/architect.brief.md`'
      )
    File.write(index, text, encoding: 'UTF-8')

    validation_errors = errors
    assert validation_errors.any? { |error| error.include?('rota referencia agente ausente no catálogo') }
    assert validation_errors.any? { |error| error.include?('rota e catálogo divergem na role de product-manager') }
  end

  def test_agent_contract_requires_all_sections
    contract = File.join(@root, 'agents/tester/AGENT.md')
    File.write(contract, File.read(contract).sub('## Guardrails', '## Limites'))
    assert errors.any? { |error| error.include?('seção ausente em agents/tester/AGENT.md: Guardrails') }
  end

  def test_agent_contract_rejects_empty_required_section
    contract = File.join(@root, 'agents/tester/AGENT.md')
    File.write(contract, File.read(contract).sub(/## Guardrails\s*\n.*\z/m, "## Guardrails\n"))
    assert errors.any? { |error| error.include?('seção vazia em agents/tester/AGENT.md: Guardrails') }
  end

  def test_handoff_contract_requires_authority_field
    protocol = File.join(@root, 'agents/_shared/handoff-protocol.md')
    File.write(protocol, File.read(protocol).sub(/^- `authority`:.*\n(?:  .*\n)*/m, ''))
    assert errors.any? { |error| error.include?('campo ausente no protocolo de handoff: authority') }
  end

  def test_handoff_contract_requires_authority_source_and_artifact_location
    protocol = File.join(@root, 'agents/_shared/handoff-protocol.md')
    text = File.read(protocol, encoding: 'UTF-8')
      .sub(/^- `authority_source`:.*\n(?:  .*\n)*/, '')
      .sub(/^- `handoff_artifact`:.*\n(?:  .*\n)*/, '')
    File.write(protocol, text, encoding: 'UTF-8')

    assert errors.any? { |error| error.include?('campo ausente no protocolo de handoff: authority_source') }
    assert errors.any? { |error| error.include?('campo ausente no protocolo de handoff: handoff_artifact') }
  end

  def test_handoff_template_requires_every_declared_field
    template = File.join(@root, 'templates/agent-handoff.md')
    original = File.read(template, encoding: 'UTF-8')

    StructureValidation::HANDOFF_TEMPLATE_PARTS.each do |field, marker|
      File.write(template, original.sub(marker, ''), encoding: 'UTF-8')
      assert errors.any? { |error| error.include?("campo ausente no template de handoff: #{field}") }, field
    end
  end

  def test_handoff_contract_fails_closed_when_required_content_is_missing
    protocol = File.read(
      File.join(@root, 'agents/_shared/handoff-protocol.md'),
      encoding: 'UTF-8'
    )
    template = File.read(
      File.join(@root, 'templates/agent-handoff.md'),
      encoding: 'UTF-8'
    )

    assert_includes protocol, '`ready` exige'
    assert_includes protocol, 'não fornece seu conteúdo'
    assert_includes protocol, 'não inventa'
    assert_includes protocol, 'o status é `blocked`'
    assert_includes template, 'não substitui o conteúdo verificável'
    assert_includes template, 'Não invente valores'
    assert_includes template, 'use `blocked`'
    assert_includes template, '<não fornecido>'
  end

  def test_context_compiler_rejects_unknown_adapter_and_traversal
    assert_raises(ContextCompiler::ConfigError) do
      ContextCompiler.render(root: @root, adapter: 'unknown')
    end
    manifest = File.join(@root, 'config/context-manifest.yml')
    File.write(manifest, File.read(manifest).sub('output: adapters/codex/AGENTS.md', 'output: ../outside.md'))
    assert errors.any? { |error| error.include?('caminho inválido') }
  end

  def test_context_drift_is_detected
    script = File.join(@root, 'scripts/check-context-drift.rb')
    _, status = Open3.capture2e('ruby', script)
    assert status.success?
    File.open(File.join(@root, 'core/kernel.md'), 'a') { |file| file.write("\nMudança de teste.\n") }
    output, status = Open3.capture2e('ruby', script)
    refute status.success?
    assert_includes output, 'divergência'
  end

  def test_platform_sync_is_dry_run_non_destructive_and_idempotent
    output_file = File.join(@root, 'adapters/codex/AGENTS.md')
    File.write(output_file, '# Conteúdo manual')
    script = File.join(@root, 'scripts/sync-platforms.rb')

    _, status = Open3.capture2e('ruby', script)
    assert status.success?
    assert_equal '# Conteúdo manual', File.read(output_file)
    refute File.exist?(output_file + '.ai-agent-config.bak')

    _, status = Open3.capture2e('ruby', script, '--apply')
    assert status.success?
    assert_equal '# Conteúdo manual', File.read(output_file + '.ai-agent-config.bak')
    assert_includes File.read(output_file), ContextCompiler::GENERATED_MARK

    before = File.read(output_file)
    sync_output, status = Open3.capture2e('ruby', script, '--apply')
    assert status.success?
    assert_equal before, File.read(output_file)
    assert_includes sync_output, '0 alteração(ões)'
  end

  def test_platform_sync_rejects_symlink_ancestor
    codex_dir = File.join(@root, 'adapters/codex')
    FileUtils.remove_entry(codex_dir)
    outside = File.join(@temp, 'outside-adapter')
    FileUtils.mkdir_p(outside)
    File.symlink(outside, codex_dir)

    output, status = Open3.capture2e('ruby', File.join(@root, 'scripts/sync-platforms.rb'), '--apply')

    refute status.success?
    assert_includes output, 'diretório ancestral é symlink'
    refute File.exist?(File.join(outside, 'AGENTS.md'))
  end

  def test_rejects_malformed_yaml_previously_accepted
    extra_skill("---\nname: [unterminated\ndescription: >-\n---\n# Teste\n")
    assert errors.any? { |e| e.include?('YAML inválido') }
  end

  def test_rejects_lines_without_frontmatter
    extra_skill("name: fixture\ndescription: texto\n# Teste\n")
    assert errors.any? { |e| e.include?('frontmatter ausente') }
  end

  def test_rejects_empty_folded_description
    extra_skill("---\nname: fixture\ndescription: >-\n---\n# Teste\n")
    assert errors.any? { |e| e.include?('description deve') }
  end

  def test_rejects_wrong_field_types
    extra_skill("---\nname: [fixture]\ndescription: 42\n---\n# Teste\n")
    assert errors.any? { |e| e.include?('name inválido') }
    assert errors.any? { |e| e.include?('description deve') }
  end

  def test_rejects_mismatched_name
    extra_skill("---\nname: another-name\ndescription: texto\n---\n# Teste\n")
    assert errors.any? { |e| e.include?('diferente da pasta') }
  end

  def test_rejects_duplicate_keys
    extra_skill("---\nname: fixture\nname: fixture\ndescription: texto\n---\n# Teste\n")
    assert errors.any? { |e| e.include?('duplicadas') }
  end

  def test_rejects_long_description
    extra_skill("---\nname: fixture\ndescription: #{'a' * 1025}\n---\n# Teste\n")
    assert errors.any? { |e| e.include?('description deve') }
  end

  def test_rejects_empty_body
    extra_skill("---\nname: fixture\ndescription: texto\n---\n")
    assert errors.any? { |e| e.include?('corpo da skill vazio') }
  end

  def test_rejects_skill_without_entrypoint
    FileUtils.mkdir_p(File.join(@root, 'skills', 'incomplete'))
    assert errors.any? { |e| e.include?('skills/incomplete/SKILL.md') }
  end

  def test_rejects_missing_resource
    extra_skill("---\nname: fixture\ndescription: texto\n---\nLeia [recurso](references/missing.md).\n")
    assert errors.any? { |e| e.include?('recurso ausente') }
  end

  def test_rejects_required_resource_outside_package
    extra_skill("---\nname: fixture\ndescription: texto\n---\nLeia [critério](../engenheiro-software-senior/SKILL.md).\n")
    assert errors.any? { |e| e.include?('fora do pacote') }
  end

  def test_rejects_additional_incomplete_topic
    FileUtils.mkdir_p(File.join(@root, 'learning', 'extra'))
    File.write(File.join(@root, 'learning', 'extra', 'context.md'), '# Contexto')
    assert errors.any? { |e| e.include?('learning/extra/notes.md') }
  end

  def test_rejects_symlink_resource_outside_package
    extra_skill("---\nname: fixture\ndescription: texto\n---\nLeia [recurso](external.md).\n")
    File.symlink(File.join(@root, 'README.md'), File.join(@root, 'skills/fixture/external.md'))
    assert errors.any? { |e| e.include?('fora do pacote') }
  end

  def test_rejects_non_array_manifest
    File.write(File.join(@root, 'scripts/required-files.json'), '{}')
    assert errors.any? { |e| e.include?('manifesto deve ser uma lista') }
  end

  def test_packaging_rejects_any_symlink_inside_skill
    skill = File.join(@root, 'skills/mentor-tecnico')
    marker = File.join(@temp, 'synthetic-external.txt')
    File.write(marker, 'SYNTHETIC_EXTERNAL_MARKER')
    File.symlink(marker, File.join(skill, 'external.txt'))

    output, status = Open3.capture2e('bash', File.join(@root, 'scripts/package-skills.sh'))

    refute status.success?
    assert_includes output, 'contém symlink não permitido'
    refute File.exist?(File.join(@root, 'dist/mentor-tecnico.zip'))
  end

  def test_packaging_rejects_dist_symlink_without_writing_outside
    outside = File.join(@temp, 'outside-dist')
    FileUtils.mkdir_p(outside)
    File.symlink(outside, File.join(@root, 'dist'))

    output, status = Open3.capture2e('bash', File.join(@root, 'scripts/package-skills.sh'))

    refute status.success?
    assert_includes output, 'Destino de pacotes não confinado'
    assert_empty Dir.children(outside)
  end

  def test_packaging_rejects_stale_symlink_without_moving_outside
    dist = File.join(@root, 'dist')
    outside = File.join(@temp, 'outside-stale')
    FileUtils.mkdir_p(dist)
    FileUtils.mkdir_p(outside)
    File.write(File.join(dist, 'removed-skill.zip'), 'artefato antigo')
    File.symlink(outside, File.join(dist, '.stale'))

    output, status = Open3.capture2e('bash', File.join(@root, 'scripts/package-skills.sh'))

    refute status.success?
    assert_includes output, 'Quarentena de pacotes não confinada'
    assert_empty Dir.children(outside)
    assert File.file?(File.join(dist, 'removed-skill.zip'))
  end

  def test_packaging_rejects_symlinked_skill_entrypoint
    skill_file = File.join(@root, 'skills/mentor-tecnico/SKILL.md')
    external = File.join(@temp, 'external-skill.md')
    File.write(external, File.read(skill_file, encoding: 'UTF-8'), encoding: 'UTF-8')
    FileUtils.rm(skill_file)
    File.symlink(external, skill_file)

    output, status = Open3.capture2e('bash', File.join(@root, 'scripts/package-skills.sh'))

    refute status.success?
    assert_includes output, 'possui SKILL.md como symlink'
  end

  def test_packaging_rejects_symlinked_skill_directory
    external = File.join(@temp, 'external-skill')
    FileUtils.mkdir_p(external)
    File.write(File.join(external, 'SKILL.md'), "---\nname: external\ndescription: fixture\n---\n# Fixture\n")
    File.symlink(external, File.join(@root, 'skills/external'))

    output, status = Open3.capture2e('bash', File.join(@root, 'scripts/package-skills.sh'))

    refute status.success?
    assert_includes output, 'Entrada em skills é symlink não permitido'
  end

  def test_packaging_rejects_potentially_sensitive_hidden_file
    sensitive = File.join(@root, 'skills/mentor-aprendizado/.env')
    File.write(sensitive, "SYNTHETIC_ONLY=fixture\n")

    output, status = Open3.capture2e('bash', File.join(@root, 'scripts/package-skills.sh'))

    refute status.success?
    assert_includes output, 'contém arquivo potencialmente sensível'
    refute File.exist?(File.join(@root, 'dist/mentor-aprendizado.zip'))
  end

  def test_packaging_quarantines_orphan_zip
    dist = File.join(@root, 'dist')
    FileUtils.mkdir_p(dist)
    File.write(File.join(dist, 'removed-skill.zip'), 'artefato antigo')

    _output, status = Open3.capture2e('bash', File.join(@root, 'scripts/package-skills.sh'))

    assert status.success?
    refute File.exist?(File.join(dist, 'removed-skill.zip'))
    assert_equal 1, Dir[File.join(dist, '.stale/run.*/removed-skill.zip')].length
  end

  def test_rejects_directory_instead_of_file
    file = File.join(@root, 'learning', 'kafka', 'notes.md')
    File.rename(file, file + '.fixture')
    FileUtils.mkdir_p(file)
    assert errors.any? { |e| e.include?('learning/kafka/notes.md') }
  end

  def test_rejects_missing_native_import
    File.write(File.join(@root, 'CLAUDE.md'), '# Apenas menciona AGENTS.md')
    assert errors.any? { |e| e.include?('importação de AGENTS.md ausente: CLAUDE.md') }
  end

  def test_creator_preserves_existing_and_rejects_traversal
    script = File.join(@root, 'scripts', 'create-learning-topic.sh')
    _, status = Open3.capture2e('bash', script, 'new-topic')
    assert status.success?
    paths = Dir[File.join(@root, 'learning', 'new-topic', '*.md')].sort
    assert_equal 5, paths.length
    before = paths.map { |p| Digest::SHA256.file(p).hexdigest }
    _, status = Open3.capture2e('bash', script, 'new-topic')
    refute status.success?
    assert_equal before, paths.map { |p| Digest::SHA256.file(p).hexdigest }
    _, status = Open3.capture2e('bash', script, '../outside')
    refute status.success?
    refute File.exist?(File.join(@root, 'outside'))
  end

  def test_concurrent_creation_has_one_winner
    script = File.join(@root, 'scripts', 'create-learning-topic.sh')
    runs = 4.times.map { Thread.new { Open3.capture2e('bash', script, 'concurrent').last.success? } }
    assert_equal 1, runs.map(&:value).count(true)
    assert_equal 5, Dir[File.join(@root, 'learning', 'concurrent', '*.md')].length
  end

  def attribution_guard(command)
    payload = JSON.generate('tool_name' => 'Bash', 'tool_input' => { 'command' => command })
    Open3.capture2e(File.join(@root, 'adapters/claude/hooks/attribution-guard.sh'), stdin_data: payload)
  end

  def test_attribution_guard_blocks_ai_attribution_in_commit_and_pr
    trailer = 'Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>'
    [
      "git commit -m \"$(cat <<'EOF'\nfeat: x\n\n#{trailer}\nEOF\n)\"",
      "git -C /tmp/r commit -m 'feat: x' -m '#{trailer}'",
      "git commit -m 'x' --trailer 'co-authored-by: Claude <a@b.c>'",
      "gh pr create --title t --body 'Resumo\n\nGenerated with [Claude Code](https://claude.com/claude-code)'",
      "curl -X POST https://api.bitbucket.org/2.0/repositories/a/b/pullrequests -d 'Generated with Claude Code'"
    ].each do |command|
      output, status = attribution_guard(command)
      assert_equal 2, status.exitstatus, command
      assert_includes output, 'attribution-guard'
    end
  end

  def test_attribution_guard_allows_clean_writes_human_coauthor_and_reads
    [
      "git commit -m 'feat(catalog): grupo de cores na PDP'",
      "git commit -m 'x' -m 'Co-Authored-By: Maria Silva <maria@exemplo.com>'",
      "git log --all -i --grep='Co-Authored-By: Claude' --format=%h",
      "gh pr create --title t --body 'corpo'",
      'ls -la'
    ].each do |command|
      output, status = attribution_guard(command)
      assert status.success?, "#{command}: #{output}"
    end
  end

  def test_rejects_non_executable_adapter_hook
    FileUtils.chmod(0o644, File.join(@root, 'adapters/claude/hooks/attribution-guard.sh'))
    assert_includes errors, 'hook não executável: adapters/claude/hooks/attribution-guard.sh'
  end

  def test_rejects_adapter_hook_missing_from_manifest
    extra = File.join(@root, 'adapters/claude/hooks/sem-entrada.sh')
    File.write(extra, "#!/usr/bin/env bash\nexit 0\n")
    FileUtils.chmod(0o755, extra)
    assert_includes errors, 'hook sem entrada em adapters/claude/hooks.yaml: adapters/claude/hooks/sem-entrada.sh'
  end

  def test_rejects_invalid_hook_manifest_entry
    File.write(File.join(@root, 'adapters/claude/hooks.yaml'),
               "version: 1\nruntime: claude\nhooks:\n  - file: ../fora.sh\n    event: PreToolUse\n    matcher: Bash\n")
    assert(errors.any? { |error| error.start_with?('hook inválido em adapters/claude/hooks.yaml') })
  end

  def install_user(home, *args)
    Open3.capture2e({ 'HOME' => home }, 'ruby', File.join(@root, 'scripts/install-agents.rb'),
                    '--user', '--agents', 'claude', *args)
  end

  def test_user_installation_links_and_registers_claude_hook_preserving_settings
    home = File.join(@temp, 'personal-hooks')
    settings = File.join(home, '.claude/settings.json')
    FileUtils.mkdir_p(File.dirname(settings))
    original = JSON.pretty_generate(
      'hooks' => { 'PreToolUse' => [{ 'matcher' => 'Bash',
                                      'hooks' => [{ 'type' => 'command', 'command' => '$HOME/.claude/hooks/outro.sh' }] }],
                   'Stop' => [{ 'hooks' => [{ 'type' => 'command', 'command' => 'true' }] }] },
      'theme' => 'dark', 'attribution' => { 'commit' => '', 'pr' => '' }
    ) + "\n"
    File.write(settings, original)
    FileUtils.chmod(0o600, settings)
    link = File.join(home, '.claude/hooks/attribution-guard.sh')

    output, status = install_user(home)
    assert status.success?
    assert_includes output, "settings: #{File.realpath(settings)}"
    assert_equal original, File.read(settings)
    refute File.symlink?(link)

    _, status = install_user(home, '--apply')
    assert status.success?
    assert_equal File.realpath(File.join(@root, 'adapters/claude/hooks/attribution-guard.sh')), File.realpath(link)
    data = JSON.parse(File.read(settings))
    assert_equal 'dark', data['theme']
    assert_equal({ 'commit' => '', 'pr' => '', 'sessionUrl' => false }, data['attribution'])
    assert_equal JSON.parse(original)['hooks']['Stop'], data['hooks']['Stop']
    assert_equal 1, data['hooks']['PreToolUse'].length
    assert_equal ['$HOME/.claude/hooks/outro.sh', '$HOME/.claude/hooks/attribution-guard.sh'],
                 data['hooks']['PreToolUse'][0]['hooks'].map { |hook| hook['command'] }
    assert_equal original, File.read(settings + '.ai-agent-config.bak')
    assert_equal 0o600, File.stat(settings).mode & 0o777

    applied = File.read(settings)
    output, status = install_user(home, '--apply')
    assert status.success?
    assert_includes output, '0 alteração(ões)'
    assert_equal applied, File.read(settings)
  end

  def test_user_installation_creates_settings_when_absent
    home = File.join(@temp, 'personal-new')
    FileUtils.mkdir_p(home)
    _, status = install_user(home, '--apply')
    assert status.success?
    settings = File.join(home, '.claude/settings.json')
    assert_equal({ 'attribution' => { 'commit' => '', 'pr' => '', 'sessionUrl' => false },
                   'hooks' => { 'PreToolUse' => [{ 'matcher' => 'Bash', 'hooks' => [
                     { 'type' => 'command', 'command' => '$HOME/.claude/hooks/attribution-guard.sh' }
                   ] }] } }, JSON.parse(File.read(settings)))
    refute File.exist?(settings + '.ai-agent-config.bak')
  end

  def test_user_installation_imposes_attribution_and_reports_overwrites
    { 'custom' => { 'commit' => 'Assistido por IA', 'pr' => '', 'extra' => 'fica' }, 'boolean' => false }.each do |name, value|
      home = File.join(@temp, "personal-attribution-#{name}")
      settings = File.join(home, '.claude/settings.json')
      FileUtils.mkdir_p(File.dirname(settings))
      original = JSON.pretty_generate('attribution' => value, 'theme' => 'dark') + "\n"
      File.write(settings, original)

      output, status = install_user(home)
      assert status.success?
      assert_includes output, name == 'custom' ? 'settings: attribution.commit tem outro valor' : 'settings: attribution tem outro valor'
      assert_equal original, File.read(settings)

      _, status = install_user(home, '--apply')
      assert status.success?
      data = JSON.parse(File.read(settings))
      expected = { 'commit' => '', 'pr' => '', 'sessionUrl' => false }
      expected = { 'commit' => '', 'pr' => '', 'extra' => 'fica', 'sessionUrl' => false } if name == 'custom'
      assert_equal expected, data['attribution']
      assert_equal 'dark', data['theme']
      assert_equal original, File.read(settings + '.ai-agent-config.bak')

      output, status = install_user(home, '--apply')
      assert status.success?
      assert_includes output, '0 alteração(ões)'
      refute_includes output, 'será sobrescrito'
    end
  end

  def test_rejects_hooks_and_unsupported_values_in_settings_manifest
    File.write(File.join(@root, 'adapters/claude/settings.yaml'),
               "version: 1\nruntime: claude\nsettings:\n  hooks: {}\n  permissions:\n    allow: [Bash]\n")
    assert_includes errors, 'hooks pertencem a adapters/claude/hooks.yaml, não a adapters/claude/settings.yaml'
    assert_includes errors, 'valor não suportado em adapters/claude/settings.yaml: permissions.allow'
  end

  def test_user_installation_refuses_unreadable_settings_before_writes
    home = File.join(@temp, 'personal-broken')
    settings = File.join(home, '.claude/settings.json')
    FileUtils.mkdir_p(File.dirname(settings))
    File.write(settings, '{ "hooks": ')
    output, status = install_user(home, '--apply')
    refute status.success?
    assert_includes output, 'settings não é JSON válido, preservado'
    assert_equal '{ "hooks": ', File.read(settings)
    refute File.exist?(File.join(home, '.claude/hooks'))
    refute File.exist?(File.join(home, '.claude/CLAUDE.md'))
  end

  def test_project_installation_does_not_install_hooks
    project = File.join(@temp, 'consumer-hooks')
    FileUtils.mkdir_p(project)
    _, status = install(project, '--agents', 'claude', '--apply')
    assert status.success?
    refute File.exist?(File.join(project, '.claude/hooks'))
    refute File.exist?(File.join(project, '.claude/settings.json'))
  end

  def install(project, *args)
    Open3.capture2e('ruby', File.join(@root, 'scripts', 'install-agents.rb'), '--project', project, *args)
  end

  def source_skill_names
    Dir.children(File.join(@root, 'skills')).sort.select do |name|
      File.file?(File.join(@root, 'skills', name, 'SKILL.md'))
    end
  end

  def test_installation_dry_run_and_preservation_and_idempotence
    project = File.join(@temp, 'consumer with spaces')
    FileUtils.mkdir_p(project)
    rules = File.join(project, 'AGENTS.md')
    File.write(rules, '# Regra original do consumidor')
    _, status = install(project)
    assert status.success?
    refute File.exist?(File.join(project, '.agents'))
    _, status = install(project, '--apply')
    assert status.success?
    assert File.read(rules).start_with?('# Regra original do consumidor')
    assert_equal '# Regra original do consumidor', File.read(rules + '.ai-agent-config.bak')
    assert_includes File.read(rules), ContextCompiler::GENERATED_MARK
    assert_includes File.read(rules), '## Modos de contexto'
    assert_includes File.read(File.join(project, 'CLAUDE.md')), '@AGENTS.md'
    refute File.exist?(File.join(project, 'GEMINI.md'))
    assert File.file?(File.join(project, '.agents/rules/ai-agent-config.md'))
    assert_equal source_skill_names.length, Dir[File.join(project, '.agents', 'skills', '*')].length
    assert_equal File.realpath(File.join(@root, 'skills', 'mentor-tecnico')),
                 File.realpath(File.join(project, '.claude', 'skills', 'mentor-tecnico'))
    assert_equal File.realpath(File.join(@root, 'skills', 'mentor-aprendizado')),
                 File.realpath(File.join(project, '.agents', 'skills', 'mentor-aprendizado'))
    before = File.read(rules)
    _, status = install(project, '--apply')
    assert status.success?
    assert_equal before, File.read(rules)
  end

  def test_gemini_cli_is_rejected_without_writes
    project = File.join(@temp, 'unsupported')
    FileUtils.mkdir_p(project)
    output, status = install(project, '--agents', 'gemini', '--apply')
    refute status.success?
    assert_includes output, 'agente desconhecido'
    assert_empty Dir.children(project)
  end

  def test_antigravity_global_paths_are_preserved
    home = File.join(@temp, 'personal')
    FileUtils.mkdir_p(home)
    rules = File.join(home, '.gemini/GEMINI.md')
    FileUtils.mkdir_p(File.dirname(rules))
    File.write(rules, '# Regra pessoal existente')
    _, status = Open3.capture2e({ 'HOME' => home }, 'ruby',
      File.join(@root, 'scripts/install-agents.rb'), '--user', '--agents', 'antigravity', '--apply')
    assert status.success?
    assert File.read(rules).start_with?('# Regra pessoal existente')
    assert_equal source_skill_names.length, Dir[File.join(home, '.gemini/config/skills/*')].length
    assert_equal File.realpath(File.join(@root, 'skills', 'mentor-aprendizado')),
                 File.realpath(File.join(home, '.gemini/config/skills/mentor-aprendizado'))
    refute File.exist?(File.join(home, '.agents'))
  end

  def test_user_installation_rejects_symlink_ancestor_with_trailing_home_separator
    home = File.join(@temp, 'personal-trailing')
    outside = File.join(@temp, 'outside-home')
    FileUtils.mkdir_p(home)
    FileUtils.mkdir_p(outside)
    File.symlink(outside, File.join(home, '.gemini'))

    output, status = Open3.capture2e(
      { 'HOME' => home + File::SEPARATOR },
      'ruby', File.join(@root, 'scripts/install-agents.rb'),
      '--user', '--agents', 'antigravity', '--apply'
    )

    refute status.success?
    assert_includes output, 'diretório pai é symlink'
    assert_empty Dir.children(outside)
  end

  def test_installation_refuses_conflicting_skill_before_writes
    project = File.join(@temp, 'conflict')
    conflict = File.join(project, '.agents', 'skills', 'mentor-tecnico')
    FileUtils.mkdir_p(conflict)
    File.write(File.join(conflict, 'owned.txt'), 'conteúdo do usuário')
    output, status = install(project, '--apply')
    refute status.success?
    assert_includes output, 'conflito, preservado'
    refute File.exist?(File.join(project, 'AGENTS.md'))
    assert_equal 'conteúdo do usuário', File.read(File.join(conflict, 'owned.txt'))
  end

  def test_installation_refuses_existing_backup_before_writes
    project = File.join(@temp, 'backup-conflict')
    FileUtils.mkdir_p(project)
    rules = File.join(project, 'AGENTS.md')
    File.write(rules, '# Regras existentes')
    File.write(rules + '.ai-agent-config.bak', '# Backup anterior')
    output, status = install(project, '--apply')
    refute status.success?
    assert_includes output, 'backup já existe'
    refute File.exist?(File.join(project, '.agents'))
    assert_equal '# Regras existentes', File.read(rules)
    assert_equal '# Backup anterior', File.read(rules + '.ai-agent-config.bak')
  end

  def test_installation_updates_managed_block_without_replacing_original_backup
    project = File.join(@temp, 'managed-update')
    FileUtils.mkdir_p(project)
    rules = File.join(project, 'AGENTS.md')
    File.write(rules, '# Regras existentes')

    _, status = install(project, '--agents', 'codex', '--apply')
    assert status.success?
    backup = rules + '.ai-agent-config.bak'
    original_backup = File.read(backup)

    File.open(File.join(@root, 'core/kernel.md'), 'a') { |file| file.write("\nMudança gerenciada de teste.\n") }
    _, sync_status = Open3.capture2e('ruby', File.join(@root, 'scripts/sync-platforms.rb'), '--apply')
    assert sync_status.success?
    _, status = install(project, '--agents', 'codex', '--apply')

    assert status.success?
    assert_equal original_backup, File.read(backup)
    assert_includes File.read(rules), 'Mudança gerenciada de teste.'
  end
end
