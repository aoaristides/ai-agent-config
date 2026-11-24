# Seleção da memória persistente

`config/persistent-memory.yml` seleciona o backend de memória dos agents:

```yaml
version: 1
mode: ai-memory
local_vault: ~/obsidian/claude-second-brain
```

`mode` aceita `ai-memory` ou `local`. O padrão versionado é `ai-memory`; esta
configuração não altera sozinha MCPs, hooks ou o servidor. Execute o verificador
a partir do projeto em que o agente vai atuar, usando o caminho absoluto do
script na biblioteca. Na própria raiz de `ai-agent-config`, confira a seleção
efetiva antes de consultar ou gravar:

```bash
ruby scripts/resolve-memory.rb --format json
```

O resolver verifica os registros de MCP e hooks `ai-memory` em Codex, Claude
Code e Antigravity no diretório pessoal e no projeto corrente. Se `mode: local`
coexistir com qualquer
um deles, o resultado efetivo continua `ai-memory` e `local_enabled` é `false`.
Essa precedência é conservadora: um registro ainda presente bloqueia o modo
local mesmo se a conexão estiver temporariamente indisponível. Erro ao ler uma
configuração também impede a resolução; não use o cofre local nesse caso.
O verificador cobre os arquivos conhecidos desses três hosts. Integrações de
outros hosts ou em outros projetos precisam ser desativadas e conferidas
separadamente.

`.ai-memory.toml` define o escopo do MCP, não escolhe o backend. Não apague esse
marcador para trocar de modo. O `ai-memory` permanece a fonte principal sempre
que estiver configurado ou registrado; não há escrita simultânea nos dois
backends pelo fluxo deste repositório.

## Usar ai-memory

Mantenha `mode: ai-memory`. Consulte `memory_query` e `memory_read_page` pelo MCP;
grave fatos duráveis somente a pedido explícito do usuário, com
`memory_write_page` e controle de versão. O cofre local fica apenas como cópia
histórica. Depois de reativar uma instalação, confira `codex mcp list`,
`claude mcp list`, `agy mcp list` e o painel Manage MCPs do Antigravity; `enabled`
na CLI não comprova que a conexão do IDE está funcionando.

Se estiver voltando do modo local, altere primeiro `mode` para `ai-memory` e
confirme que o resolver retorna `efetivo: ai-memory`.
Depois registre o MCP nos hosts desejados. Confira o plano dos comandos sem
`--apply` e a saída de `--help` da versão instalada antes de aplicar:

```bash
ai-memory install-mcp --client codex --apply
ai-memory install-mcp --client claude-code --apply
ai-memory install-mcp --client antigravity-cli --apply
```

Os hooks de ciclo de vida não são necessários para consultas e notas explícitas;
não os reinstale por rotina. O Antigravity IDE desta máquina usa
`scripts/antigravity-mcp-compat.js`; confirme a entrada no painel e restaure
esse adapter se o instalador da CLI não cobrir o IDE. Abra sessões novas depois
da troca. A volta ao `ai-memory` não sincroniza automaticamente notas criadas
no cofre local; reconcilie-as antes de gravar o mesmo fato no wiki.

## Usar o cofre local

O modo local usa o cofre Obsidian existente para **notas duráveis explícitas**.
Não reativa `scripts/capture-knowledge.rb` nem `scripts/process-knowledge.rb`:
eles recebem ou arquivam capturas de conversas, que a política atual proíbe
persistir. Não copie prompts, transcrições, segredos, dados pessoais, logs brutos,
outputs de build ou código-fonte para o cofre.

Antes de selecionar `mode: local`, retire a integração `ai-memory` dos três
hosts. Os comandos abaixo têm efeitos sobre a configuração pessoal, inclusive
fora deste repositório; revise os planos e backups. **Não use `--purge-data`**:

```bash
ai-memory uninstall --only hooks
ai-memory uninstall --only mcp
```

Quando decidir efetivar a troca, remova os hooks e as entradas MCP. Na instalação
auditada, o desinstalador cobre os hooks dos três hosts e o MCP do Claude Code;
as entradas Codex e Antigravity exigem seus próprios comandos:

```bash
ai-memory uninstall --only hooks --apply
ai-memory uninstall --only mcp --apply
codex mcp remove ai-memory
agy mcp remove ai-memory
```

Confira também instalações por projeto e outros hosts; `ai-memory run` e `setup`
podem reinstalar integrações. Não há necessidade de apagar o wiki do ai-memory.
Altere `mode` para `local` em `config/persistent-memory.yml`. A partir do
projeto em que o agente vai atuar, execute o script pelo caminho absoluto da
biblioteca:

```bash
ruby /Users/andersonorione/ai-agent-config/scripts/resolve-memory.rb --require-local
```

O comando só retorna sucesso se o modo local for efetivo no diretório corrente.
Em cada consulta, leia
`00-indice-mestre.md`, `_protocolo.md`, o índice do projeto e as notas pertinentes
no caminho `cofre local` retornado pelo resolver. Antes de qualquer escrita,
execute `--require-local` novamente, busque nota equivalente, siga o protocolo
e atualize seus índices. A permissão do host para acessar o cofre fora do
workspace continua necessária. Sem acesso ou sem pedido explícito para gravar,
entregue o resultado no chat.

O cofre preservado é um snapshot histórico. Antes de usá-lo como fonte viva,
compare as notas necessárias com o wiki do `ai-memory` e trate divergências;
trocar o modo não migra dados automaticamente.

## Verificação da troca

- `ruby scripts/resolve-memory.rb --format json` deve mostrar exatamente o
  backend pretendido em `effective_mode`; `local_enabled` só pode ser `true`
  quando nenhuma integração `ai-memory` foi detectada.
- Confira `codex mcp list`, `claude mcp list`, `agy mcp list` e o painel do IDE.
  Um registro não detectado pelo resolver ainda pode manter a captura ativa.
- Execute `./scripts/validate-structure.sh` e `ruby scripts/test-integration.rb`
  após editar a configuração compartilhada.
