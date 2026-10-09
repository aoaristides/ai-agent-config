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

## Hooks do Claude Code

`claude/hooks/` guarda guards versionados manualmente; como o `models.yaml`,
não são saída do compilador de contexto. São o reforço determinístico de uma
regra do núcleo: a regra orienta o modelo, o hook barra o comando.

| Hook | Evento | Regra que reforça |
| --- | --- | --- |
| `attribution-guard.sh` | `PreToolUse` em `Bash` | Commits e PRs sem atribuição ao agente de IA |

`attribution-guard.sh` bloqueia (exit 2) o comando que escreve commit ou PR com
trailer `Co-Authored-By` do Claude, o e-mail `noreply` da Anthropic ou a linha
"Generated with Claude Code". Coautor humano e leitura (`git log --grep`) passam.
Ele existe porque `attribution` vazia no `settings.json` só retira o pedido do
harness: o modelo ainda copia o trailer quando o `git log` do repositório o tem.

`adapters/claude/hooks.yaml` declara evento e matcher de cada script; a
validação recusa script sem entrada, entrada sem script e hook não executável.

`scripts/install-agents.rb --user --agents claude` liga os hooks declarados:
cria o symlink em `~/.claude/hooks/` e acrescenta o comando ao grupo do matcher
em `hooks.<evento>` do `~/.claude/settings.json`. Nos hooks ele só acrescenta:
os demais ficam como estão, e um hook já registrado não é duplicado. Antes
da primeira alteração grava `settings.json.ai-agent-config.bak`, que nunca é
substituído. Recusa, sem escrever nada, `settings.json` que não seja JSON válido
e arquivo comum já existente no lugar do symlink. O arquivo é regravado com
indentação de dois espaços; comentários não são suportados.

A instalação por `--project` não liga hooks: o symlink seria um caminho absoluto
desta máquina dentro de um `settings.json` versionado. Sessões em nuvem não leem
`~/.claude`; lá o registro precisa estar no `.claude/settings.json` do projeto,
com o script versionado junto.

No mesmo comando, o instalador garante no `~/.claude/settings.json` as chaves
declaradas em `adapters/claude/settings.yaml`. Hoje é só `attribution`, com
`commit` e `pr` vazios e `sessionUrl: false`, para o harness também deixar de
pedir a atribuição. Ao contrário dos hooks, essas chaves são impostas: valor
diferente no destino é sobrescrito, e o plano avisa qual chave antes de aplicar
(`settings: attribution.commit tem outro valor e será sobrescrito`). Subchaves
não declaradas ficam como estão. O manifesto aceita apenas mappings e escalares;
listas e a chave `hooks` são recusadas pela validação.

O hook só enxerga a tool `Bash`: mensagem lida de arquivo (`git commit -F`) e PR
criado por tool MCP dependem apenas da regra do núcleo.

`<AI_AGENT_CONFIG_ROOT>` é deliberadamente portátil nos artefatos versionados.
O instalador renderiza o caminho local real dentro do bloco gerenciado.
