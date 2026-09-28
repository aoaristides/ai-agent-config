#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'optparse'
require 'tempfile'
require_relative 'context_compiler'

module PlatformSync
  def self.run(args)
    options = { apply: false }
    parser = OptionParser.new do |opts|
      opts.banner = 'Uso: ruby scripts/sync-platforms.rb [--apply]'
      opts.on('--apply') { options[:apply] = true }
      opts.on('-h', '--help') { puts opts; return 0 }
    end
    parser.parse!(args)
    raise ContextCompiler::ConfigError, parser.banner unless args.empty?

    root = File.expand_path('..', __dir__)
    planned = ContextCompiler.outputs(root).each_with_object([]) do |(adapter, output), result|
      raise ContextCompiler::ConfigError, "saída é symlink ou diretório: #{output}" if File.symlink?(output) || File.directory?(output)
      old = File.file?(output) ? File.read(output, encoding: 'UTF-8') : nil
      rendered = ContextCompiler.render(root: root, adapter: adapter, root_label: '<AI_AGENT_CONFIG_ROOT>')
      next if old == rendered
      backup = old && !old.include?(ContextCompiler::GENERATED_MARK) ? output + '.ai-agent-config.bak' : nil
      if backup && (File.exist?(backup) || File.symlink?(backup))
        raise ContextCompiler::ConfigError, "backup já existe, preservado: #{backup}"
      end
      result << [adapter, output, old, rendered, backup]
    end

    planned.each { |adapter, output, _old, _rendered, _backup| puts "[sync-platforms] #{adapter}: #{output}" }
    puts "[sync-platforms] #{planned.length} alteração(ões); #{options[:apply] ? 'aplicando' : 'somente plano; use --apply'}."
    return 0 unless options[:apply]

    planned.each do |_adapter, output, old, rendered, backup|
      current = File.file?(output) ? File.read(output, encoding: 'UTF-8') : nil
      raise ContextCompiler::ConfigError, "mudança concorrente, interrompido: #{output}" unless current == old
      FileUtils.mkdir_p(File.dirname(output))
      if backup
        File.open(backup, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(old) }
      end
      Tempfile.create(['.context-adapter-', '.tmp'], File.dirname(output)) do |temp|
        temp.write(rendered)
        temp.flush
        File.chmod(old ? File.stat(output).mode & 0o777 : 0o644, temp.path)
        File.rename(temp.path, output)
      end
    end
    puts '[sync-platforms] Concluído.'
    0
  rescue ContextCompiler::ConfigError, OptionParser::ParseError, SystemCallError => e
    warn "[sync-platforms] #{e.message}"
    1
  end
end

exit PlatformSync.run(ARGV) if $PROGRAM_NAME == __FILE__
