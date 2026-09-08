#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'digest'
require_relative 'validate_structure'

class IntegrationTest < Minitest::Test
  def setup
    @temp = Dir.mktmpdir('ai-agent-config-tests-')
    @root = File.join(@temp, 'source')
    FileUtils.mkdir_p(@root)
    source = File.expand_path('..', __dir__)
    %w[README.md AGENTS.md CLAUDE.md GEMINI.md profiles skills knowledge learning
       templates projects prompts scripts context docs tests].each do |name|
      FileUtils.cp_r(File.join(source, name), @root)
    end
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

  def install(project, *args)
    Open3.capture2e('ruby', File.join(@root, 'scripts', 'install-agents.rb'), '--project', project, *args)
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
    assert_includes File.read(File.join(project, 'CLAUDE.md')), '@AGENTS.md'
    assert_includes File.read(File.join(project, 'GEMINI.md')), '@AGENTS.md'
    assert_equal 6, Dir[File.join(project, '.agents', 'skills', '*')].length
    assert_equal File.realpath(File.join(@root, 'skills', 'mentor-tecnico')),
                 File.realpath(File.join(project, '.claude', 'skills', 'mentor-tecnico'))
    before = File.read(rules)
    _, status = install(project, '--apply')
    assert status.success?
    assert_equal before, File.read(rules)
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
end
