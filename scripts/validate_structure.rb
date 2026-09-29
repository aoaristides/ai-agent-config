#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'
require 'pathname'
require_relative 'context_compiler'

module StructureValidation
  SLUG = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  TOPIC_FILES = %w[context.md roadmap.md progress.md notes.md exercises.md].freeze
  REQUIRED_AGENTS = %w[orchestrator product-manager architect software-engineer tester
                       code-reviewer security-engineer performance-engineer].freeze
  AGENT_SECTIONS = ['Missão', 'Acione quando', 'Não acione quando', 'Contexto mínimo',
                    'Entradas obrigatórias', 'Saídas obrigatórias', 'Handoffs', 'Guardrails'].freeze
  HANDOFF_TEMPLATE_PARTS = {
    'task_id' => '# Handoff: <task_id>', 'from' => '**From:**', 'to' => '**To:**',
    'status' => '**Status:**', 'objective' => '**Objective:**', 'scope' => '**Scope:**',
    'out_of_scope' => '**Out of scope:**', 'authority' => '**Authority:**',
    'authority_source' => '**Authority source:**',
    'handoff_artifact' => '**Handoff artifact:**',
    'facts' => '## Facts', 'decisions' => '## Decisions', 'assumptions' => '## Assumptions',
    'acceptance_criteria' => '## Acceptance criteria', 'artifacts' => '## Artifacts',
    'open_questions' => '## Open questions', 'requested_action' => '## Requested action'
  }.freeze

  def self.validate(root)
    root = File.realpath(root)
    errors = []
    check_file = lambda do |relative|
      path = File.join(root, relative)
      unless File.file?(path) && !File.read(path, encoding: 'UTF-8').strip.empty?
        errors << "ausente, não regular ou vazio: #{relative}"
      end
    end
    required = JSON.parse(File.read(File.join(root, 'scripts/required-files.json'), encoding: 'UTF-8'))
    raise ArgumentError, 'manifesto deve ser uma lista' unless required.is_a?(Array)
    required.each do |relative|
      unless relative.is_a?(String) && !Pathname.new(relative).absolute? && !relative.split('/').include?('..')
        errors << 'caminho inválido no manifesto de arquivos'
        next
      end
      check_file.call(relative)
    end
    Dir.children(File.join(root, 'skills')).sort.each do |name|
      dir = File.join(root, 'skills', name)
      next unless File.directory?(dir)
      relative = "skills/#{name}/SKILL.md"
      check_file.call(relative)
      next unless File.file?(File.join(root, relative))
      content = File.read(File.join(root, relative), encoding: 'UTF-8')
      match = content.match(/\A---[ \t]*\r?\n(.*?)\r?\n---[ \t]*(?:\r?\n|\z)(.*)\z/m)
      unless match
        errors << "frontmatter ausente ou não delimitado: #{relative}"
        next
      end
      begin
        metadata = YAML.safe_load(match[1], permitted_classes: [], permitted_symbols: [], aliases: false)
        unless metadata.is_a?(Hash)
          errors << "frontmatter deve ser mapping: #{relative}"
          next
        end
        duplicates = duplicate_yaml_keys(match[1])
        errors << "chaves YAML duplicadas em #{relative}: #{duplicates.join(', ')}" unless duplicates.empty?
        skill_name = metadata['name']
        unless skill_name.is_a?(String) && skill_name.match?(SLUG) && skill_name.length <= 64 && skill_name == name
          errors << "name inválido ou diferente da pasta: #{relative}"
        end
        description = metadata['description']
        unless description.is_a?(String) && !description.strip.empty? && description.length <= 1024
          errors << "description deve conter 1–1024 caracteres: #{relative}"
        end
        compatibility = metadata['compatibility']
        if compatibility && (!compatibility.is_a?(String) || compatibility.length > 500)
          errors << "compatibility inválido: #{relative}"
        end
        errors << "corpo da skill vazio: #{relative}" if match[2].strip.empty?
      rescue Psych::Exception => e
        errors << "YAML inválido em #{relative}: #{e.class}"
      end
      content.scan(/\[[^\]]*\]\(([^\s)]+)(?:\s+[^)]*)?\)/).flatten.each do |target|
        next if target.match?(/\A(?:[a-z]+:|#)/i)
        target = target.split('#').first
        next if target.nil? || target.empty?
        path = File.expand_path(target, dir)
        unless packaged_file?(path, dir)
          errors << "recurso ausente ou fora do pacote #{name}: #{target}"
        end
      end
      content.scan(/`(references\/[a-zA-Z0-9_.\/-]+\.md)`/).flatten.each do |target|
        errors << "referência ausente ou fora do pacote em #{name}: #{target}" unless packaged_file?(File.join(dir, target), dir)
      end
    end
    Dir.children(File.join(root, 'learning')).sort.each do |name|
      next unless File.directory?(File.join(root, 'learning', name))
      errors << "nome de tópico inválido: #{name}" unless name.match?(SLUG)
      TOPIC_FILES.each { |file| check_file.call("learning/#{name}/#{file}") }
    end
    validate_agent_catalog(root, errors)
    validate_handoff_contract(root, errors)
    Dir.glob(File.join(root, '{agents,knowledge,profiles,templates,projects,prompts,core,roles,workflows,context-packs,adapters}', '**', '*.md')).each do |path|
      check_file.call(path.delete_prefix(root + '/'))
    end
    begin
      ContextCompiler.outputs(root).each do |adapter, output|
        expected = ContextCompiler.render(root: root, adapter: adapter, root_label: '<AI_AGENT_CONFIG_ROOT>')
        actual = File.file?(output) ? File.read(output, encoding: 'UTF-8') : nil
        errors << "adapter fora de sincronia: #{adapter}" unless actual == expected
      end
    rescue ContextCompiler::ConfigError => e
      errors << "compilador de contexto inválido: #{e.message}"
    end
    %w[package-skills.sh create-learning-topic.sh validate-structure.sh render-agent-context.rb
       check-context-drift.rb sync-platforms.rb].each do |name|
      errors << "script não executável: #{name}" unless File.executable?(File.join(root, 'scripts', name))
    end
    %w[CLAUDE.md].each do |file|
      path = File.join(root, file)
      unless File.file?(path) && File.read(path, encoding: 'UTF-8').match?(/^@(?:\.\/)?AGENTS\.md\s*$/)
        errors << "importação de AGENTS.md ausente: #{file}"
      end
    end
    errors
  rescue JSON::ParserError, Errno::ENOENT, ArgumentError => e
    ["estrutura ilegível: #{e.class}: #{e.message}"]
  end

  def self.validate_agent_catalog(root, errors)
    relative_catalog = 'agents/catalog.yml'
    catalog_path = File.join(root, relative_catalog)
    unless File.file?(catalog_path)
      errors << "ausente, não regular ou vazio: #{relative_catalog}"
      return
    end
    catalog = File.read(catalog_path, encoding: 'UTF-8')
    duplicates = duplicate_yaml_keys(catalog)
    errors << "chaves YAML duplicadas em #{relative_catalog}: #{duplicates.join(', ')}" unless duplicates.empty?
    data = YAML.safe_load(catalog,
                          permitted_classes: [], permitted_symbols: [], aliases: false)
    unless data.is_a?(Hash) && data['version'] == 1 && data['agents'].is_a?(Hash)
      errors << 'catálogo de agentes deve ter version 1 e agents como mapping'
      return
    end
    agents = data['agents']
    (REQUIRED_AGENTS - agents.keys).each { |name| errors << "agente obrigatório ausente: #{name}" }
    agents.each do |name, entry|
      unless name.is_a?(String) && name.match?(SLUG) && entry.is_a?(Hash)
        errors << "entrada inválida no catálogo de agentes: #{name.inspect}"
        next
      end
      validate_agent_path(root, errors, entry['definition'], 'definition', expected: "agents/#{name}/AGENT.md")
      definition = entry['definition']
      if definition.is_a?(String) && definition == "agents/#{name}/AGENT.md"
        path = File.join(root, definition)
        if File.file?(path)
          content = File.read(path, encoding: 'UTF-8')
          AGENT_SECTIONS.each do |section|
            match = content.match(/^## #{Regexp.escape(section)}\s*\r?\n(.*?)(?=^## |\z)/m)
            if match.nil?
              errors << "seção ausente em #{definition}: #{section}"
            elsif match[1].strip.empty?
              errors << "seção vazia em #{definition}: #{section}"
            end
          end
        end
      end
      role = entry['role']
      validate_agent_path(root, errors, role, 'role', prefix: 'roles/')
      workflows = entry['workflows']
      if !workflows.is_a?(Array) || workflows.empty? || workflows.uniq != workflows
        errors << "workflows inválidos no agente #{name}"
      else
        workflows.each { |path| validate_agent_path(root, errors, path, 'workflow', prefix: 'workflows/') }
      end
      skills = entry['skills']
      if !skills.is_a?(Array) || skills.uniq != skills
        errors << "skills inválidas no agente #{name}"
      else
        skills.each do |skill|
          unless skill.is_a?(String) && skill.match?(SLUG) && File.file?(File.join(root, 'skills', skill, 'SKILL.md'))
            errors << "skill inválida ou ausente no agente #{name}: #{skill.inspect}"
          end
        end
      end
    end
    validate_context_routes(root, agents, errors)
  rescue Psych::Exception => e
    errors << "YAML inválido no catálogo de agentes: #{e.class}"
  end

  def self.validate_context_routes(root, agents, errors)
    index = File.join(root, 'context-index.md')
    return unless File.file?(index)

    File.readlines(index, encoding: 'UTF-8').each do |line|
      next unless line.start_with?('|')

      cells = line.split('|', -1)[1..-2]&.map(&:strip)
      next unless cells&.length == 5

      agent = cells[1][/`([^`]+)`/, 1]
      next unless agent
      unless agents.key?(agent)
        errors << "rota referencia agente ausente no catálogo: #{agent}"
        next
      end

      entry = agents[agent]
      next unless entry.is_a?(Hash)

      role = cells[2][/`(roles\/[^`]+)`/, 1]
      if role && entry['role'] != role
        errors << "rota e catálogo divergem na role de #{agent}: #{role}"
      end

      workflow = cells[3][/`(workflows\/[^`]+)`/, 1]
      if workflow && !Array(entry['workflows']).include?(workflow)
        errors << "rota e catálogo divergem no workflow de #{agent}: #{workflow}"
      end
    end
  end

  def self.validate_handoff_contract(root, errors)
    protocol_path = File.join(root, 'agents/_shared/handoff-protocol.md')
    template_path = File.join(root, 'templates/agent-handoff.md')
    return unless File.file?(protocol_path) && File.file?(template_path)

    protocol = File.read(protocol_path, encoding: 'UTF-8')
    template = File.read(template_path, encoding: 'UTF-8')
    envelope = protocol[/^## Envelope obrigatório\s*$\n(.*?)(?=^## |\z)/m, 1].to_s
    HANDOFF_TEMPLATE_PARTS.each do |field, template_part|
      declared = envelope.lines.any? do |line|
        line.start_with?('- ') && line.include?("`#{field}`")
      end
      errors << "campo ausente no protocolo de handoff: #{field}" unless declared
      errors << "campo ausente no template de handoff: #{field}" unless template.include?(template_part)
    end
  end

  def self.duplicate_yaml_keys(yaml)
    duplicates = []
    visit = lambda do |node, path|
      case node
      when Psych::Nodes::Mapping
        seen = []
        node.children.each_slice(2) do |key, value|
          name = key.respond_to?(:value) ? key.value : key.to_s
          location = (path + [name]).join('.')
          duplicates << location if seen.include?(name)
          seen << name
          visit.call(value, path + [name])
        end
      when Psych::Nodes::Sequence
        node.children.each_with_index { |child, index| visit.call(child, path + [index.to_s]) }
      end
    end
    document = Psych.parse(yaml)
    visit.call(document.root, []) if document&.root
    duplicates.uniq
  end

  def self.validate_agent_path(root, errors, relative, field, expected: nil, prefix: nil)
    unless relative.is_a?(String) && !relative.empty? && !Pathname.new(relative).absolute? &&
           !relative.split('/').include?('..')
      errors << "caminho inválido no catálogo: #{field}"
      return
    end
    errors << "#{field} fora da convenção: #{relative}" if expected && relative != expected
    errors << "#{field} fora da convenção: #{relative}" if prefix && !relative.start_with?(prefix)
    path = File.expand_path(relative, root)
    unless File.file?(path)
      errors << "arquivo ausente no catálogo: #{relative}"
      return
    end
    real = File.realpath(path)
    errors << "recurso fora da raiz no catálogo: #{relative}" unless ContextCompiler.inside?(root, real)
  end

  def self.packaged_file?(path, dir)
    File.file?(path) && File.realpath(path).start_with?(File.realpath(dir) + '/')
  rescue SystemCallError
    false
  end
end

if $PROGRAM_NAME == __FILE__
  errors = StructureValidation.validate(ARGV.fetch(0, File.expand_path('..', __dir__)))
  if errors.empty?
    puts '[validate-structure] OK: manifesto, agentes, YAML, skills, referências, tópicos e imports.'
  else
    errors.each { |message| warn "[validate-structure] #{message}" }
    exit 1
  end
end
