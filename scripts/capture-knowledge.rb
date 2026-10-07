#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'
require 'securerandom'
require 'time'
require 'uri'
require_relative '../capture/adapters/chatgpt'
require_relative '../capture/adapters/generic_text'

module KnowledgeCapture
  SCHEMA_VERSION = '1.0'
  PROVIDER_SLUG = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
  DEFAULT_VAULT = File.expand_path('~/obsidian/claude-second-brain')
  ADAPTERS = [CaptureAdapters::ChatGPTCaptureAdapter].to_h { |adapter| [adapter.source, adapter] }.freeze

  def self.run(argv, stdin: $stdin, stdout: $stdout, stderr: $stderr, env: ENV)
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = <<~USAGE.strip
        Uso: ruby scripts/capture-knowledge.rb --source chatgpt [opções] [--file ARQUIVO | < captura.md]
        Grava um CanonicalCapture em <vault>/99-inbox sem sobrescrever arquivos existentes.
      USAGE
      opts.on('--source SLUG', 'Fonte de captura; ChatGPT tem adapter dedicado e demais usam texto genérico') { |value| options[:source] = value }
      opts.on('--provider SLUG', 'Alias legado para --source') { |value| options[:source] = value }
      opts.on('--file PATH', 'Arquivo de texto/Markdown; use - para stdin') { |value| options[:file] = value }
      opts.on('--title TÍTULO', 'Título opcional da conversa') { |value| options[:title] = value }
      opts.on('--conversation-id ID', 'Identificador da conversa na origem') { |value| options[:conversation_id] = value }
      opts.on('--source-url URL', 'URL da conversa, se disponível') { |value| options[:url] = value }
      opts.on('--project SLUG', 'Projeto associado à captura') { |value| options[:project] = value }
      opts.on('--type SLUG', 'Tipo provisório da captura') { |value| options[:type] = value }
      opts.on('--tags TAGS', 'Tags separadas por vírgula') { |value| options[:tags] = value }
      opts.on('--vault PATH', 'Caminho do vault; padrão: AI_AGENT_VAULT ou vault configurado') { |value| options[:vault] = value }
      opts.on('-h', '--help', 'Exibe esta ajuda') { stdout.puts(opts); return 0 }
    end
    parser.parse!(argv)
    raise ArgumentError, parser.banner unless argv.empty?
    raise ArgumentError, '--source é obrigatório' unless options[:source]
    adapter = ADAPTERS.fetch(options[:source], CaptureAdapters::GenericText)
    raise ArgumentError, '--source deve usar um slug em kebab-case' unless options[:source].match?(PROVIDER_SLUG)
    if (options[:file].nil? || options[:file] == '-') && stdin.tty?
      raise ArgumentError, 'forneça --file ARQUIVO ou envie conteúdo pela entrada padrão'
    end

    attributes = adapter.capture(options, stdin: stdin)
    capture = canonical_capture(options, attributes)

    validate(capture)
    vault = options[:vault] || env['AI_AGENT_VAULT'] || DEFAULT_VAULT
    inbox = File.join(File.expand_path(vault), '99-inbox')
    raise ArgumentError, "vault inexistente ou inacessível: #{File.expand_path(vault)}" unless File.directory?(File.expand_path(vault))
    raise ArgumentError, "inbox inexistente ou é symlink: #{inbox}" unless File.directory?(inbox) && !File.symlink?(inbox)

    path = File.join(inbox, "capture-#{capture.fetch('capture_id')}.json")
    write_exclusive(path, JSON.pretty_generate(capture) + "\n")
    stdout.puts(path)
    0
  rescue ArgumentError, OptionParser::ParseError, SystemCallError, IOError, JSON::GeneratorError => e
    stderr.puts("[capture-knowledge] #{e.message}")
    1
  end

  def self.canonical_capture(options, attributes)
    source = attributes.fetch(:source)
    source[:conversation_id] = options[:conversation_id] if options[:conversation_id]
    source[:url] = options[:url] if options[:url]
    capture = {
      'schema_version' => SCHEMA_VERSION,
      'capture_id' => SecureRandom.uuid,
      'captured_at' => Time.now.utc.iso8601,
      'source' => source.transform_keys(&:to_s),
      'content' => attributes.fetch(:content)
    }
    capture['project'] = options[:project] if options[:project]
    capture['type'] = options[:type] if options[:type]
    capture['tags'] = options[:tags].split(',').map(&:strip).reject(&:empty?).uniq if options[:tags]
    capture
  end

  def self.validate(capture)
    raise ArgumentError, 'schema_version inválida' unless capture['schema_version'] == SCHEMA_VERSION
    raise ArgumentError, 'capture_id deve ser UUID' unless capture['capture_id'].match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
    begin
      Time.iso8601(capture['captured_at'])
    rescue ArgumentError
      raise ArgumentError, 'captured_at deve ser uma data/hora ISO 8601 válida'
    end
    source = capture['source']
    raise ArgumentError, 'source.provider inválido' unless source['provider'].match?(PROVIDER_SLUG)
    raise ArgumentError, 'source.title não pode ficar vazio' if source['title'].strip.empty?
    if source['conversation_id'] && source['conversation_id'].strip.empty?
      raise ArgumentError, 'source.conversation_id não pode ficar vazio quando informado'
    end
    if source['url']
      uri = URI.parse(source['url'])
      raise ArgumentError, 'source.url deve ser uma URL absoluta HTTP(S)' unless %w[http https].include?(uri.scheme) && uri.host
    end
    raise ArgumentError, 'content não pode ficar vazio' if capture['content'].strip.empty?
    %w[project type].each do |field|
      next unless capture[field]
      raise ArgumentError, "#{field} deve ser um slug em kebab-case" unless capture[field].match?(PROVIDER_SLUG)
    end
    if capture['tags'] && (!capture['tags'].is_a?(Array) || capture['tags'].any? { |tag| !tag.is_a?(String) || tag.strip.empty? })
      raise ArgumentError, 'tags devem conter valores não vazios'
    end
  rescue URI::InvalidURIError
    raise ArgumentError, 'source.url inválida'
  end

  def self.write_exclusive(path, content)
    created = false
    File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) do |file|
      created = true
      file.write(content)
      file.flush
      file.fsync
    end
  rescue StandardError
    File.delete(path) if created && File.file?(path)
    raise
  end
end

exit KnowledgeCapture.run(ARGV) if $PROGRAM_NAME == __FILE__
