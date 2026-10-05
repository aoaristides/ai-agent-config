<!-- generated-by: ai-agent-config/context-compiler -->
# Contexto compartilhado — Antigravity

Raiz da biblioteca: `{{AI_AGENT_CONFIG_ROOT}}`.

Use o índice para selecionar somente o contexto necessário. Confirme na UI que
a regra foi reconhecida; o arquivo não concede acesso fora do workspace.

Ao materializar um agente, resolva seu `model_profile` com
`adapters/antigravity/models.yaml`, `models/selection-policy.md` e
`models/fallback-policy.md`. Use `scripts/resolve-model.rb` quando houver shell.
Ao criar o subagente, use `host_selector`; se `materializable` for `false`, não
afirme que o modelo resolvido foi aplicado pelo host.

{{MANAGED_CONTEXT}}
