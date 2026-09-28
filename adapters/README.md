# Adaptadores de host

Os arquivos em `codex/`, `claude/` e `antigravity/` são artefatos gerados a
partir de `config/context-manifest.yml` e de `templates/`. Não os edite
manualmente: altere a fonte e sincronize novamente.

## Uso

1. Confira o plano com `ruby scripts/sync-platforms.rb`.
2. Aplique com `ruby scripts/sync-platforms.rb --apply`.
3. Valide com `ruby scripts/check-context-drift.rb`.
4. Use `scripts/install-agents.rb` para preservar regras existentes no destino.
5. Valide numa sessão nova quais arquivos foram realmente lidos.

`<AI_AGENT_CONFIG_ROOT>` é deliberadamente portátil nos artefatos versionados.
O instalador renderiza o caminho local real dentro do bloco gerenciado.
