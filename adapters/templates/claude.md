<!-- generated-by: ai-agent-config/context-compiler -->
# Contexto compartilhado — Claude Code

Raiz da biblioteca: `{{AI_AGENT_CONFIG_ROOT}}`.

Use o índice para selecionar somente o contexto necessário. Não use imports para
carregar a biblioteca inteira. Regras do projeto e o pedido atual prevalecem.

Ao materializar um agente, resolva seu `model_profile` com
`adapters/claude/models.yaml`, `models/selection-policy.md` e
`models/fallback-policy.md`. Use `scripts/resolve-model.rb` quando houver shell.
Ao criar o subagente, use `host_selector`; se `materializable` for `false`, não
afirme que o modelo resolvido foi aplicado pelo host.

{{MANAGED_CONTEXT}}
