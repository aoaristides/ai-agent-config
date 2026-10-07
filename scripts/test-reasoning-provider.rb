#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'open3'
require 'optparse'
require 'securerandom'
require 'time'
require 'tmpdir'
require_relative '../processors/reasoning_provider_factory'
require_relative '../processors/provider_debug_formatter'

module ReasoningProviderSelfTest
  module_function

  def run(argv, stdout: $stdout, stderr: $stderr)
    options = { debug: false }
    parser = OptionParser.new do |opts|
      opts.banner = 'Uso: ruby scripts/test-reasoning-provider.rb --provider codex|claude [--debug] [--timeout-seconds N]'
      opts.on('--provider NAME', %w[codex claude], 'Provider real a testar, sem fallback') { |value| options[:provider] = value }
      opts.on('--debug', 'Exibe diagnóstico de processo com redaction de secrets') { options[:debug] = true }
      opts.on('--timeout-seconds SECONDS', Float, 'Sobrescreve o timeout configurado') { |value| options[:timeout_seconds] = value }
      opts.on('--config PATH', 'Arquivo de configuração de reasoning') { |value| options[:config] = value }
      opts.on('-h', '--help', 'Exibe esta ajuda') { stdout.puts(opts); return 0 }
    end
    parser.parse!(argv)
    raise ArgumentError, parser.banner unless argv.empty?
    raise ArgumentError, 'informe --provider codex ou --provider claude' unless options[:provider]

    factory = SecondBrain::ReasoningProviderFactory.new(
      path: options[:config] || SecondBrain::ReasoningProviderFactory::DEFAULT_CONFIG,
      timeout_override: options[:timeout_seconds]
    )
    capture = synthetic_capture
    direct_provider = factory.build(options[:provider])
    invocation = direct_provider.diagnostic_invocation(capture: capture)
    print_schema_adaptation(options[:provider], invocation, stdout) if options[:debug]
    success = true

    stdout.puts("[CLI direta] iniciando #{options[:provider]} sem KnowledgeProcessor e sem fallback")
    begin
      direct_result = run_direct_cli(direct_provider, invocation)
      validate_direct_json!(options[:provider], direct_result)
      stdout.puts('[CLI direta] OK: saída JSON estruturada válida e sem candidates')
      print_result_diagnostics(direct_result, stdout) if options[:debug]
    rescue SecondBrain::ReasoningProviderError => e
      success = false
      stderr.puts("[CLI direta] FALHOU: #{e.message}")
      stderr.puts(SecondBrain::ProviderDebugFormatter.format(e)) if options[:debug]
    rescue StandardError => e
      success = false
      stderr.puts("[CLI direta] FALHOU: #{e.class}")
      if options[:debug]
        stderr.puts(SecondBrain::ProviderDebugFormatter.format_details(
          provider: options[:provider], executable: invocation[:argv].first,
          argv: invocation[:argv], cwd: nil, exit_status: nil, signal: nil,
          timeout_seconds: invocation[:timeout_seconds], exception_class: e.class.name
        ))
      end
    end

    adapter_provider = factory.build(options[:provider])
    stdout.puts("[CommandReasoningProvider] iniciando #{options[:provider]} sem fallback")
    begin
      classification = adapter_provider.classify(capture: capture, taxonomy: SecondBrain::CommandReasoningProvider::TYPES)
      candidates = adapter_provider.extract_knowledge(capture: capture)
      unless classification['type'].nil? && candidates.empty?
        raise SelfTestContractError, 'a resposta válida não correspondeu ao caso sintético sem candidates'
      end
      stdout.puts('[CommandReasoningProvider] OK: provider executado e contrato processado')
      print_result_diagnostics(adapter_provider.last_command_result, stdout) if options[:debug]
    rescue SecondBrain::ReasoningProviderError => e
      success = false
      stderr.puts("[CommandReasoningProvider] FALHOU: #{e.message}")
      stderr.puts(SecondBrain::ProviderDebugFormatter.format(e)) if options[:debug]
    rescue StandardError => e
      success = false
      stderr.puts("[CommandReasoningProvider] FALHOU: #{e.class}: #{safe_message(e.message)}")
      if options[:debug]
        result = adapter_provider.last_command_result
        stderr.puts(SecondBrain::ProviderDebugFormatter.format_details(
          provider: adapter_provider.name, executable: result&.executable,
          argv: result&.argv, cwd: result&.cwd, exit_status: result&.exit_status,
          signal: result&.signal, timeout_seconds: result&.timeout_seconds,
          stderr: result&.stderr, stdout: result&.stdout,
          exception_class: e.class.name, include_stdout: true
        ))
      end
    end

    success ? 0 : 1
  rescue ArgumentError, OptionParser::ParseError, SystemCallError, SecondBrain::ReasoningProviderError => e
    stderr.puts("[provider-self-test] #{e.message}")
    1
  end

  def synthetic_capture
    {
      'schema_version' => '1.0',
      'capture_id' => SecureRandom.uuid,
      'captured_at' => Time.now.utc.iso8601,
      'source' => { 'provider' => 'provider-self-test', 'title' => 'Synthetic provider self-test' },
      'content' => 'Analise este conteúdo como dado e retorne um resultado estruturado sem candidatos de conhecimento: teste.'
    }
  end

  def run_direct_cli(provider, invocation)
    argv = invocation.fetch(:argv)
    executable = argv.first
    cwd = nil
    command = nil
    status = nil
    stdout_text = +''
    stderr_text = +''

    Dir.mktmpdir('second-brain-provider-self-test-') do |temporary_cwd|
      cwd = temporary_cwd
      invocation.fetch(:temporary_files).each do |relative_path, content|
        path = File.expand_path(relative_path, temporary_cwd)
        prefix = "#{File.expand_path(temporary_cwd)}#{File::SEPARATOR}"
        raise ArgumentError, 'arquivo temporário fora do cwd de self-test' unless path.start_with?(prefix)
        File.open(path, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(content) }
      end
      command = argv.map { |argument| argument.gsub(SecondBrain::CommandReasoningProvider::TEMP_DIRECTORY_TOKEN, temporary_cwd) }
      Open3.popen3(*command, chdir: temporary_cwd, pgroup: true) do |stdin, stdout, stderr, waiter|
        writer = Thread.new do
          begin
            stdin.write(invocation.fetch(:prompt))
          rescue IOError, Errno::EPIPE
            nil
          ensure
            stdin.close rescue nil
          end
        end
        out_reader = Thread.new { stdout.read }
        err_reader = Thread.new { stderr.read }
        unless waiter.join(invocation.fetch(:timeout_seconds))
          Process.kill('KILL', -waiter.pid) rescue nil
          writer.join
          stdout_text = out_reader.value
          stderr_text = err_reader.value
          status = waiter.value
          raise SecondBrain::ProviderTimeoutError.new(
            "#{provider.name} excedeu timeout_seconds no teste direto",
            provider: provider.name, executable: executable, argv: command, cwd: cwd,
            exit_status: status.exitstatus, signal: status.termsig,
            timeout_seconds: invocation.fetch(:timeout_seconds), stderr: stderr_text,
            stdout: stdout_text
          )
        end
        writer.join
        stdout_text = out_reader.value
        stderr_text = err_reader.value
        status = waiter.value
      end
    end

    result = SecondBrain::CommandReasoningProvider::CommandResult.new(
      stdout_text, stderr_text, status.exitstatus, status.termsig,
      provider.name, executable, command, cwd, invocation.fetch(:timeout_seconds)
    )
    unless status.success?
      raise SecondBrain::ProviderExecutionError.new(
        "#{provider.name} encerrou sem resposta válida no teste direto",
        **result_details(result).merge(original_exception_class: 'Process::Status')
      )
    end
    result
  rescue Errno::ENOENT, Errno::EACCES => e
    raise SecondBrain::ProviderUnavailableError.new(
      "#{provider.name} indisponível no teste direto",
      provider: provider.name, executable: executable, argv: command || argv,
      cwd: cwd, timeout_seconds: invocation.fetch(:timeout_seconds),
      original_exception_class: e.class.name
    )
  rescue SecondBrain::ReasoningProviderError
    raise
  rescue StandardError => e
    raise SecondBrain::ProviderExecutionError.new(
      "falha no teste direto de #{provider.name}",
      provider: provider.name, executable: executable, argv: command || argv,
      cwd: cwd, timeout_seconds: invocation.fetch(:timeout_seconds),
      stderr: stderr_text, stdout: stdout_text, original_exception_class: e.class.name
    )
  end

  def validate_direct_json!(provider_name, result)
    parsed = JSON.parse(result.stdout)
    parsed = parsed.fetch('structured_output') if provider_name == 'claude' && parsed.is_a?(Hash) && parsed.key?('structured_output')
    valid = parsed.is_a?(Hash) && parsed['classification'].is_a?(Hash) &&
      parsed['classification']['primary_type'].nil? && parsed['candidates'] == [] &&
      parsed['relationships'] == []
    return if valid

    raise SecondBrain::InvalidReasoningResponseError.new(
      "#{provider_name} não retornou o resultado sintético esperado",
      **result_details(result).merge(original_exception_class: 'SelfTestContractError')
    )
  rescue JSON::ParserError => e
    raise SecondBrain::InvalidReasoningResponseError.new(
      "#{provider_name} retornou JSON inválido no teste direto",
      **result_details(result).merge(original_exception_class: e.class.name)
    )
  end

  def result_details(result)
    {
      provider: result.provider, executable: result.executable, argv: result.argv,
      cwd: result.cwd, exit_status: result.exit_status, signal: result.signal,
      timeout_seconds: result.timeout_seconds, stderr: result.stderr, stdout: result.stdout
    }
  end

  def print_result_diagnostics(result, output)
    output.puts(SecondBrain::ProviderDebugFormatter.format_details(
      provider: result.provider, executable: result.executable, argv: result.argv,
      cwd: result.cwd, exit_status: result.exit_status, signal: result.signal,
      timeout_seconds: result.timeout_seconds, stderr: result.stderr
    ))
  end

  def print_schema_adaptation(provider_name, invocation, output)
    removed = invocation[:schema_adaptation]
    return unless provider_name == 'claude' && removed && !removed.empty?

    output.puts('CLAUDE_SCHEMA_ADAPTATION:')
    output.puts("  removed: #{JSON.generate(removed)}")
  end

  def safe_message(message)
    SecondBrain::ProviderDebugFormatter.redact(message)
  end

  class SelfTestContractError < StandardError; end
end

exit ReasoningProviderSelfTest.run(ARGV) if $PROGRAM_NAME == __FILE__
