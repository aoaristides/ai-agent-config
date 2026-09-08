#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'optparse'
require 'tempfile'
require_relative 'validate_structure'

module AgentInstallation
  BEGIN_MARK = '<!-- ai-agent-config:begin -->'
  END_MARK = '<!-- ai-agent-config:end -->'
  AGENTS = %w[codex claude cursor gemini antigravity].freeze

  def self.run(args)
    options = { apply: false, agents: AGENTS }
    parser = OptionParser.new do |opts|
      opts.banner = 'Uso: ruby scripts/install-agents.rb (--project DIR | --user) [--agents LISTA] [--apply]'
      opts.on('--project DIR') { |v| options[:project] = File.expand_path(v) }
      opts.on('--user') { options[:user] = true }
      opts.on('--agents LISTA', Array) { |v| options[:agents] = v }
      opts.on('--apply') { options[:apply] = true }
      opts.on('-h', '--help') { puts opts; return 0 }
    end
    parser.parse!(args)
    raise ArgumentError, parser.banner unless args.empty? && (!!options[:project] ^ !!options[:user])
    raise ArgumentError, 'agente desconhecido ou lista vazia' if options[:agents].empty? || (options[:agents] - AGENTS).any?
    root = File.realpath(File.join(__dir__, '..'))
    errors = StructureValidation.validate(root)
    raise ArgumentError, errors.join("\n") unless errors.empty?
    if options[:project] && !File.directory?(options[:project])
      raise ArgumentError, 'o projeto de destino deve existir'
    end
    base = options[:project] ? File.realpath(options[:project]) : Dir.home
    core = File.read(File.join(root, 'context/agent-core.md'))
    context = "#{BEGIN_MARK}\n#{core}\nRaiz local do contexto portátil: `#{root}`.\n" \
      "Destino padrão das trilhas pessoais: `#{root}/learning/`; o pedido do usuário prevalece.\n#{END_MARK}\n"
    edits = {}
    links = {}
    skills = Dir.children(File.join(root, 'skills')).sort.select { |n| File.directory?(File.join(root, 'skills', n)) }
    options[:agents].each do |agent|
      if options[:user]
        skill_path = { 'codex' => '.agents/skills', 'claude' => '.claude/skills',
                       'cursor' => '.agents/skills', 'gemini' => '.agents/skills',
                       'antigravity' => '.gemini/config/skills' }.fetch(agent)
        # Não crie uma segunda descoberta para os links legados já usados pelo Codex.
        if agent == 'codex' && skills.any? { |n| same_link?(File.join(base, '.codex/skills', n), File.join(root, 'skills', n)) }
          skill_path = '.codex/skills'
          puts '[install-agents] Codex: reutilizando diretório legado já conectado à fonte.'
        end
        rule_path = { 'codex' => '.codex/AGENTS.md', 'claude' => '.claude/CLAUDE.md',
                      'gemini' => '.gemini/GEMINI.md', 'antigravity' => '.gemini/GEMINI.md' }[agent]
        if agent == 'cursor'
          puts '[install-agents] Cursor: skills pessoais; use --project para instalar regras de projeto.'
        end
      else
        skill_path = agent == 'claude' ? '.claude/skills' : '.agents/skills'
        rule_path = { 'codex' => 'AGENTS.md', 'claude' => 'CLAUDE.md', 'cursor' => 'AGENTS.md',
                      'gemini' => 'GEMINI.md', 'antigravity' => '.agents/rules/ai-agent-config.md' }.fetch(agent)
      end
      skills.each { |name| links[File.join(base, skill_path, name)] = File.join(root, 'skills', name) }
      next unless rule_path
      target = File.join(base, rule_path)
      # Claude e Gemini recebem imports nativos; Codex/Cursor recebem o núcleo expandido.
      if options[:project] && %w[claude gemini].include?(agent)
        edits[File.join(base, 'AGENTS.md')] = context
        edits[target] = "#{BEGIN_MARK}\n@AGENTS.md\n#{END_MARK}\n"
      else
        edits[target] = context
      end
    end
    planned = []
    links.each do |target, source|
      next if same_link?(target, source)
      raise ArgumentError, "conflito, preservado: #{target}" if File.exist?(target) || File.symlink?(target)
      reject_symlink_ancestors!(target, base)
      planned << [:link, target, source, nil]
    end
    edits.each do |target, block|
      reject_symlink_ancestors!(target, base)
      raise ArgumentError, "arquivo de regras é symlink ou diretório, preservado: #{target}" if File.symlink?(target) || File.directory?(target)
      old = File.file?(target) ? File.read(target) : nil
      text = old || ''
      if text.include?(BEGIN_MARK) || text.include?(END_MARK)
        unless text.scan(BEGIN_MARK).length == 1 && text.scan(END_MARK).length == 1 && text.index(BEGIN_MARK) < text.index(END_MARK)
          raise ArgumentError, "bloco gerenciado ambíguo, preservado: #{target}"
        end
        updated = text.sub(/#{Regexp.escape(BEGIN_MARK)}.*?#{Regexp.escape(END_MARK)}\n?/m) { block }
      else
        updated = text + (text.empty? ? '' : "\n\n") + block
      end
      next if updated == text
      backup = target + '.ai-agent-config.bak'
      if old && (File.exist?(backup) || File.symlink?(backup))
        raise ArgumentError, "backup já existe, preservado: #{backup}"
      end
      planned << [:rules, target, updated, old]
    end
    planned.each { |kind, target, _value, _old| puts "[install-agents] #{kind}: #{target}" }
    puts "[install-agents] #{planned.length} alteração(ões); #{options[:apply] ? 'aplicando' : 'somente plano; use --apply'}."
    return 0 unless options[:apply]
    planned.each do |kind, target, value, old|
      FileUtils.mkdir_p(File.dirname(target))
      if kind == :link
        File.symlink(value, target) # Falha se outro processo criou o alvo após o plano.
      else
        current = File.file?(target) ? File.read(target) : nil
        raise ArgumentError, "mudança concorrente, interrompido: #{target}" unless current == old && !File.symlink?(target)
        if old
          backup = target + '.ai-agent-config.bak'
          raise ArgumentError, "backup já existe, preservado: #{backup}" if File.exist?(backup) || File.symlink?(backup)
          File.open(backup, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |f| f.write(old) }
        end
        Tempfile.create(['.ai-agent-config-', '.tmp'], File.dirname(target)) do |temp|
          temp.write(value)
          temp.flush
          File.chmod(old ? File.stat(target).mode & 0o777 : 0o644, temp.path)
          File.rename(temp.path, target)
        end
      end
    end
    if options[:agents].include?('antigravity') && options[:project]
      puts '[install-agents] Antigravity: confira a regra ai-agent-config na UI e selecione Always On; ativação não certificada por arquivo.'
    end
    puts '[install-agents] Concluído. Abra nova sessão e confira skills, regras e eventuais aliases duplicados do host.'
    0
  rescue ArgumentError, OptionParser::ParseError, SystemCallError => e
    warn "[install-agents] #{e.message}"
    1
  end

  def self.same_link?(target, source)
    File.symlink?(target) && File.realpath(target) == File.realpath(source)
  rescue Errno::ENOENT
    false
  end

  def self.reject_symlink_ancestors!(target, base)
    parent = File.dirname(target)
    while parent.start_with?(base + '/')
      raise ArgumentError, "diretório pai é symlink; revise o destino: #{parent}" if File.symlink?(parent)
      parent = File.dirname(parent)
    end
  end
end

exit AgentInstallation.run(ARGV) if $PROGRAM_NAME == __FILE__
