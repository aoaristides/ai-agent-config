#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require_relative 'context_compiler'

options = { root: File.expand_path('..', __dir__) }
parser = OptionParser.new do |opts|
  opts.banner = 'Uso: ruby scripts/render-agent-context.rb --adapter NOME [--root-label CAMINHO]'
  opts.on('--adapter NOME') { |value| options[:adapter] = value }
  opts.on('--root-label CAMINHO') { |value| options[:root_label] = value }
  opts.on('-h', '--help') { puts opts; exit 0 }
end

begin
  parser.parse!(ARGV)
  raise ContextCompiler::ConfigError, parser.banner unless ARGV.empty? && options[:adapter]
  print ContextCompiler.render(root: options[:root], adapter: options[:adapter], root_label: options[:root_label])
rescue ContextCompiler::ConfigError, OptionParser::ParseError => e
  warn "[render-agent-context] #{e.message}"
  exit 1
end
