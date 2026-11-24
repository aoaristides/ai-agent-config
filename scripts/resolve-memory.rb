#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require_relative 'persistent_memory'

format = 'plain'
require_local = false
parser = OptionParser.new do |opts|
  opts.banner = 'Uso: ruby scripts/resolve-memory.rb [--format plain|json] [--require-local]'
  opts.on('--format FORMAT', %w[plain json]) { |value| format = value }
  opts.on('--require-local') { require_local = true }
  opts.on('-h', '--help') { puts opts; exit 0 }
end

begin
  parser.parse!(ARGV)
  raise PersistentMemory::ConfigError, parser.banner unless ARGV.empty?

  result = PersistentMemory.resolve(root: File.expand_path('..', __dir__))
  if require_local && !result[:local_enabled]
    raise PersistentMemory::ConfigError, 'memória local bloqueada: ai-memory tem precedência ou o modo local não foi selecionado'
  end

  if format == 'json'
    require 'json'
    puts JSON.generate(result)
  else
    puts "configurado: #{result[:configured_mode]}"
    puts "efetivo: #{result[:effective_mode]}"
    puts "cofre local: #{result[:local_vault]}" if result[:local_enabled]
    puts "integrações ai-memory: #{result[:ai_memory_integrations].empty? ? 'nenhuma detectada' : result[:ai_memory_integrations].join(', ')}"
  end
rescue PersistentMemory::ConfigError, OptionParser::ParseError => e
  warn "[resolve-memory] #{e.message}"
  exit 1
end
