#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require_relative '../processors/knowledge_processor'
require_relative '../processors/reasoning_provider_factory'
require_relative '../processors/provider_debug_formatter'

module KnowledgeProcessingCommand
  DEFAULT_VAULT = File.expand_path('~/obsidian/claude-second-brain')

  def self.run(argv, stdout: $stdout, stderr: $stderr, env: ENV)
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = 'Uso: ruby scripts/process-knowledge.rb (--file CAPTURE.json | --all) [--dry-run] [--vault PATH] [--provider rule-based|codex|claude] [--fallback-provider rule-based|none] [--timeout-seconds N]'
      opts.on('--file PATH', 'Processa uma captura específica da inbox') { |value| options[:file] = value }
      opts.on('--all', 'Processa as capturas JSON diretamente na inbox') { options[:all] = true }
      opts.on('--dry-run', 'Mostra o plano sem gravar, arquivar ou criar diretórios') { options[:dry_run] = true }
      opts.on('--vault PATH', 'Vault; padrão: AI_AGENT_VAULT ou vault configurado') { |value| options[:vault] = value }
      opts.on('--provider NAME', 'Provider de raciocínio; padrão: config/reasoning.yml') { |value| options[:provider] = value }
      opts.on('--fallback-provider NAME', 'Fallback técnico: rule-based ou none') { |value| options[:fallback_provider] = value }
      opts.on('--timeout-seconds SECONDS', Float, 'Timeout obrigatório para providers externos') { |value| options[:timeout_seconds] = value }
      opts.on('--config PATH', 'Arquivo de configuração de reasoning') { |value| options[:config] = value }
      opts.on('--provider-debug', 'Exibe diagnóstico seguro do provider externo em caso de falha') { options[:provider_debug] = true }
      opts.on('-h', '--help', 'Exibe esta ajuda') { stdout.puts(opts); return 0 }
    end
    parser.parse!(argv)
    raise ArgumentError, parser.banner unless argv.empty?
    raise ArgumentError, 'informe exatamente um entre --file e --all' unless !!options[:file] ^ !!options[:all]

    vault = File.expand_path(options[:vault] || env['AI_AGENT_VAULT'] || DEFAULT_VAULT)
    inbox = File.join(vault, '99-inbox')
    raise ArgumentError, "inbox inexistente ou symlink: #{inbox}" unless File.directory?(inbox) && !File.symlink?(inbox)
    paths = if options[:all]
              Dir.glob(File.join(inbox, 'capture-*.json')).sort
            else
              [File.expand_path(options[:file], inbox)]
            end
    raise ArgumentError, 'nenhuma captura encontrada' if paths.empty?

    factory = SecondBrain::ReasoningProviderFactory.new(
      path: options[:config] || SecondBrain::ReasoningProviderFactory::DEFAULT_CONFIG,
      timeout_override: options[:timeout_seconds]
    )
    provider = factory.build_selected(name: options[:provider], fallback_name: options[:fallback_provider])
    processor = SecondBrain::KnowledgeProcessor.new(
      vault: vault, reasoning_provider: provider, stdout: stdout,
      max_semantic_candidates: factory.config.fetch('max_semantic_candidates', 5),
      semantic_confidence_threshold: factory.config.fetch('confidence_threshold')
    )
    failures = 0
    paths.each do |path|
      begin
        result = processor.process(path, dry_run: options[:dry_run])
        if provider.is_a?(SecondBrain::FallbackReasoningProvider) && provider.fallback_error
          stderr.puts("[process-knowledge] provider primário falhou tecnicamente (#{provider.fallback_error.class}); fallback em uso: #{provider.used_provider}")
          if options[:provider_debug] && provider.fallback_error.is_a?(SecondBrain::ReasoningProviderError)
            stderr.puts(SecondBrain::ProviderDebugFormatter.format(provider.fallback_error))
          end
        end
        stdout.puts("REASONING_PROVIDER: #{provider.respond_to?(:used_provider) ? provider.used_provider : (provider.respond_to?(:name) ? provider.name : provider.class.name)}")
        stdout.puts("CANDIDATES: #{result.candidates.map { |item| "#{item['type']}: #{item['title']}" }.join('; ')}")
        stdout.puts("RELATIONSHIPS: #{result.relationships.empty? ? 'nenhuma' : result.relationships.map { |item| item['title'] }.join('; ')}")
        stdout.puts("RESULT: #{result.status} — #{result.message}")
      rescue StandardError => e
        failures += 1
        stderr.puts("[process-knowledge] #{path}: #{e.message}")
        if options[:provider_debug] && e.is_a?(SecondBrain::ReasoningProviderError)
          stderr.puts(SecondBrain::ProviderDebugFormatter.format(e))
        end
      end
    end
    failures.zero? ? 0 : 1
  rescue ArgumentError, OptionParser::ParseError, SystemCallError, SecondBrain::ReasoningProviderError => e
    stderr.puts("[process-knowledge] #{e.message}")
    1
  end
end

exit KnowledgeProcessingCommand.run(ARGV) if $PROGRAM_NAME == __FILE__
