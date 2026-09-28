#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'context_compiler'

root = File.expand_path('..', __dir__)
begin
  drift = ContextCompiler.outputs(root).each_with_object([]) do |(adapter, output), result|
    expected = ContextCompiler.render(root: root, adapter: adapter, root_label: '<AI_AGENT_CONFIG_ROOT>')
    actual = File.file?(output) ? File.read(output, encoding: 'UTF-8') : nil
    result << adapter unless actual == expected
  end

  if drift.empty?
    puts '[check-context-drift] OK: adaptadores sincronizados.'
  else
    warn "[check-context-drift] divergência: #{drift.join(', ')}"
    exit 1
  end
rescue ContextCompiler::ConfigError, SystemCallError => e
  warn "[check-context-drift] #{e.message}"
  exit 1
end
