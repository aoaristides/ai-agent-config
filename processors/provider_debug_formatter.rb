# frozen_string_literal: true

require 'json'

module SecondBrain
  module ProviderDebugFormatter
    SENSITIVE_FLAGS = %w[
      --api-key --token --password --authorization --auth-token --access-token --secret
      --system-prompt --append-system-prompt --json-schema
    ].freeze
    TOKEN_PATTERNS = [
      /\bBearer\s+[A-Za-z0-9._~+\/-]+=*/i,
      /\bBasic\s+[A-Za-z0-9+\/=]+/i,
      /\b(?:sk-(?:ant-|proj-)?|gh[pousr]_|xox[baprs]-|AIza)[A-Za-z0-9_-]{8,}/,
      /\beyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/,
      /\b[A-Z0-9_]*(?:API[_-]?KEY|TOKEN|PASSWORD|SECRET|CREDENTIALS|AUTHORIZATION)[A-Z0-9_]*\b(\s*[:=]\s*)(["']?)([^\s,"'&;]+)/i,
      /\b(api[_-]?key|token|access[_-]?token|auth[_-]?token|password|secret|authorization)\b(\s*[:=]\s*)(["']?)([^\s,"'&;]+)/i
    ].freeze
    MAX_DIAGNOSTIC_CHARS = 6000

    module_function

    def format(error)
      format_details(
        provider: error.provider, executable: error.executable, argv: error.argv,
        cwd: error.cwd, exit_status: error.exit_status, signal: error.signal,
        timeout_seconds: error.timeout_seconds, stderr: error.stderr,
        stdout: error.stdout, exception_class: error.original_exception_class || error.class.name,
        include_stdout: !error.stdout.empty?
      )
    end

    def format_details(provider:, executable:, argv:, cwd:, exit_status:, signal:,
                       timeout_seconds:, stderr: '', stdout: '', exception_class: nil,
                       include_stdout: false)
      lines = [
        "provider: #{redact(provider || 'desconhecido')}",
        "executable: #{redact(executable || 'desconhecido')}",
        "argv: #{JSON.generate(redact_argv(argv || []))}",
        "cwd: #{redact(cwd || 'desconhecido')}",
        "exit_status: #{exit_status.nil? ? 'indisponível' : exit_status}",
        "signal: #{signal.nil? ? 'nenhum' : signal}",
        "timeout_seconds: #{timeout_seconds || 'indisponível'}",
        "exception: #{exception_class || 'nenhuma'}"
      ]
      lines << "stderr:\n#{excerpt(stderr)}" unless stderr.to_s.empty?
      lines << "stdout:\n#{excerpt(stdout)}" if include_stdout && !stdout.to_s.empty?
      lines.join("\n")
    end

    def redact_argv(argv)
      redacted = []
      hide_next = false
      argv.each do |argument|
        if hide_next
          redacted << '[REDACTED]'
          hide_next = false
          next
        end

        value = argument.to_s
        flag, inline_value = value.split('=', 2)
        if SENSITIVE_FLAGS.include?(flag)
          redacted << (inline_value.nil? ? flag : "#{flag}=[REDACTED]")
          hide_next = inline_value.nil?
        else
          redacted << redact(value)
        end
      end
      redacted
    end

    def redact(value)
      safe_text = value.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
      TOKEN_PATTERNS.reduce(safe_text) do |text, pattern|
        if pattern.names.any?
          text.gsub(pattern) { "#{$1}#{$2}[REDACTED]" }
        else
          text.gsub(pattern, '[REDACTED]')
        end
      end
    end

    def excerpt(value)
      text = redact(value)
      return text if text.length <= MAX_DIAGNOSTIC_CHARS

      "#{text[0, MAX_DIAGNOSTIC_CHARS]}\n[saída truncada]"
    end
  end
end
