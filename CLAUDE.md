@AGENTS.md

# CLAUDE.md — Contexto do repositório

Use este repositório como configuração portátil compartilhada. Preserve as instruções existentes e aplique as regras de `AGENTS.md` como contexto do projeto.

## Roteamento

- Perfil do usuário: `profiles/`.
- Comportamento especializado: `skills/<nome>/SKILL.md`.
- Conhecimento técnico reutilizável: `knowledge/`.
- Mentorias persistentes: `learning/`.
- Contexto de projeto: `projects/<projeto>/`.
- Modelos reutilizáveis: `templates/`.
- Prompts curtos de entrada: `prompts/`.

Carregue somente os arquivos necessários à tarefa. Não trate exemplos como fatos do ambiente atual e não replique automaticamente conteúdo do cofre Obsidian.

## Compatibilidade

As skills existentes `engenheiro-software-senior` e `arquiteto-solucoes` são canônicas e não devem ser substituídas por versões resumidas. As skills especializadas novas complementam essas duas e devem evitar duplicar guardrails globais.

Valide mudanças com `./scripts/validate-structure.sh`; para distribuição das skills, use o `package-skills.sh` já existente.
