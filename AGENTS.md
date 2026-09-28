# AGENTS.md — Contexto compartilhado

Este repositório é a fonte versionada de configuração portátil para agentes de IA.

Em tarefa não trivial, comece por [core/kernel.md](core/kernel.md) e
[context-index.md](context-index.md). O núcleo canônico de comportamento e
consulta ao cofre permanece em [context/agent-core.md](context/agent-core.md).
Este arquivo contém instruções de manutenção específicas do repositório; não o
instale como regra global de projetos alheios. O compilador distribui somente o
contexto compartilhado selecionado no manifesto.

## Idioma e postura

- Responda em PT-BR; preserve termos técnicos consagrados em inglês.
- Seja direto, cético e explícito sobre premissas e trade-offs.
- Separe evidência, inferência e suposição com `[fato]`, `[inferência]` e `[suposição]` quando essa distinção importar.
- Não invente APIs, versões, flags ou comportamentos; verifique na fonte oficial quando houver risco de desatualização.

## Como usar este repositório

1. Leia `profiles/technical-profile.md`, `profiles/preferences.md` e `profiles/current-focus.md` quando a tarefa depender de contexto pessoal.
2. Carregue apenas as skills pertinentes em `skills/`; o `SKILL.md` de cada pasta define seus gatilhos.
3. Consulte `knowledge/` para modelos mentais e checklists reutilizáveis.
4. Consulte `projects/` somente quando houver um projeto identificável.
5. Em mentoria, continue a partir de `learning/<tema>/` e registre progresso observável.
6. Gere adaptadores a partir de `config/context-manifest.yml`; não mantenha
   versões independentes das mesmas regras por host.

## Limites e fontes de verdade

- `skills/` é a fonte canônica das skills distribuídas por este repositório.
- `knowledge/` contém conhecimento curado e reutilizável, não fatos voláteis sem fonte.
- O cofre Obsidian `~/obsidian/claude-second-brain/` continua canônico para decisões reais, contexto vivo de projetos, preferências confirmadas e aprendizados observados.
- Não copie segredos, logs, outputs de build ou transcrições para este repositório.
- Antes de alterar arquivos existentes, preserve conteúdo e compatibilidade; mudanças destrutivas exigem confirmação explícita.

## Validação

Depois de mudar o contexto compartilhado, execute
`ruby scripts/sync-platforms.rb --apply`, `./scripts/validate-structure.sh` e
`ruby scripts/test-integration.rb`. Depois de mudar skills, execute também
`./scripts/package-skills.sh`.
