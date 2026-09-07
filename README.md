# AI Agent Config

Configuração compartilhada de skills usadas por diferentes agentes de IA.

## Estrutura

- `skills/arquiteto-solucoes`
- `skills/engenheiro-software-senior`

As skills são agnósticas ao agente.

Claude Code e Codex acessam essas skills por symlink:

- `~/.claude/skills/...`
- `~/.codex/skills/...`

A fonte canônica é:

`~/ai-agent-config/skills/`

## Segundo cérebro

O conhecimento persistente fica separado no Obsidian.

Vault:

`~/obsidian/claude-second-brain/`

O repositório `ai-agent-config` contém comportamento/configuração dos agentes,
não o conteúdo do segundo cérebro.

## Regra

Não editar cópias específicas em `.claude` ou `.codex`.

Editar sempre a fonte canônica em:

`~/ai-agent-config/skills/`
