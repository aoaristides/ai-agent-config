#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'
require 'pathname'

module StructureValidation
  SLUG = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  TOPIC_FILES = %w[context.md roadmap.md progress.md notes.md exercises.md].freeze

  def self.validate(root)
    root = File.realpath(root)
    errors = []
    check_file = lambda do |relative|
      path = File.join(root, relative)
      unless File.file?(path) && !File.read(path, encoding: 'UTF-8').strip.empty?
        errors << "ausente, não regular ou vazio: #{relative}"
      end
    end
    required = JSON.parse(File.read(File.join(root, 'scripts/required-files.json')))
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
        tree = Psych.parse(match[1]).root
        keys = tree.children.each_slice(2).map { |pair| pair.first.value }
        errors << "chaves YAML duplicadas: #{relative}" unless keys.uniq == keys
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
    Dir.glob(File.join(root, '{knowledge,profiles,templates,projects,prompts}', '**', '*.md')).each do |path|
      check_file.call(path.delete_prefix(root + '/'))
    end
    %w[package-skills.sh create-learning-topic.sh validate-structure.sh].each do |name|
      errors << "script não executável: #{name}" unless File.executable?(File.join(root, 'scripts', name))
    end
    %w[CLAUDE.md GEMINI.md].each do |file|
      path = File.join(root, file)
      unless File.file?(path) && File.read(path).match?(/^@(?:\.\/)?AGENTS\.md\s*$/)
        errors << "importação de AGENTS.md ausente: #{file}"
      end
    end
    errors
  rescue JSON::ParserError, Errno::ENOENT, ArgumentError => e
    ["estrutura ilegível: #{e.class}: #{e.message}"]
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
    puts '[validate-structure] OK: manifesto, YAML, skills, referências, tópicos e imports.'
  else
    errors.each { |message| warn "[validate-structure] #{message}" }
    exit 1
  end
end
