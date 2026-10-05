# Adaptadores de host

Os arquivos Markdown em `codex/`, `claude/` e `antigravity/` são artefatos
gerados a partir de `config/context-manifest.yml` e de `templates/`. Não os edite
manualmente: altere a fonte e sincronize novamente.

Cada diretório também contém um `models.yaml` versionado manualmente. Ele é o
mapping do runtime entre os perfis canônicos de `models/profiles.yaml` e nomes
concretos de modelos; não é saída do compilador de contexto.

Cada mapping declara ainda as capabilities observadas do host. `exact` aceita o
ID concreto, `alias` exige tradução por `selectors` e `advisory` resolve somente
a intenção, sem comprovar materialização. O resolver expõe essa distinção por
`host_selector`, `selection_mode` e `materializable`.

## Uso

1. Confira o plano com `ruby scripts/sync-platforms.rb`.
2. Aplique com `ruby scripts/sync-platforms.rb --apply`.
3. Valide com `ruby scripts/check-context-drift.rb`.
4. Use `scripts/install-agents.rb` para preservar regras existentes no destino.
5. Valide numa sessão nova quais arquivos foram realmente lidos.

Para inspecionar uma resolução sem iniciar o host:

```bash
ruby scripts/resolve-model.rb --runtime codex --agent software-engineer --format yaml
```

`<AI_AGENT_CONFIG_ROOT>` é deliberadamente portátil nos artefatos versionados.
O instalador renderiza o caminho local real dentro do bloco gerenciado.
