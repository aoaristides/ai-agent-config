# Integração local e validação

Fonte canônica: este repositório. As skills são autossuficientes; recursos do
repositório central e outras skills são opcionais. O pacote da engenharia inclui
suas referências locais. Os ZIPs não transportam o cofre nem as trilhas pessoais.

O contexto compartilhado dos hosts é compilado por
`config/context-manifest.yml`. `scripts/install-agents.rb` usa o mesmo renderer
dos artefatos em `adapters/`; não mantenha cópias independentes por host.

A plataforma multiagente é definida em `agents/catalog.yml`. Os adapters carregam
somente `core/agent-platform.md`, que aponta para contratos sob demanda. Não há
cópias específicas dos oito agentes por host. Quando o host não suportar
delegação nativa, execute os contratos sequencialmente e preserve o mesmo
protocolo de handoff.

## Instalar sem sobrescrever configuração existente

Pré-requisitos: Ruby com YAML (o mesmo usado pelo empacotador), Bash e permissões
de escrita nos destinos escolhidos. O script usa symlinks locais; para outra
máquina, clone a fonte e execute ali. Não leve links absolutos para ambientes cloud.

Na raiz da fonte, visualize o plano de instalação pessoal:

```bash
ruby scripts/install-agents.rb --user --agents codex,claude,antigravity
```

Para aplicá-lo, acrescente `--apply`. Em um projeto consumidor existente:

```bash
ruby scripts/install-agents.rb --project /caminho/absoluto/do/projeto
```

O plano não escreve. A aplicação valida primeiro os conflitos, mantém links
corretos, recusa arquivos/diretórios que ocupariam o lugar de uma skill, e
acrescenta um bloco identificado às regras. Instruções anteriores são preservadas.
Na primeira alteração de um arquivo sem bloco gerenciado, cria um backup
`.ai-agent-config.bak`. Um backup prévio nunca é sobrescrito: revise e guarde-o
antes de atualizar novamente. Depois que o bloco existe, atualizações regeneram
somente esse bloco e preservam o backup original; editar manualmente dentro do
bloco não cria outro backup e será substituído na próxima aplicação.
Uma falha durante a aplicação pode deixar parte da instalação pronta; repita o
plano após resolver a causa. Não há promessa de transação entre vários arquivos.

No escopo pessoal do Claude Code, o mesmo comando liga os hooks declarados em
`adapters/claude/hooks.yaml`: symlink em `~/.claude/hooks/` e registro em
`~/.claude/settings.json`, só acrescentando entradas. Antes da primeira
alteração grava `settings.json.ai-agent-config.bak`, preservado nas seguintes.
A instalação por projeto não liga hooks. Detalhes em
[adapters/README.md](../adapters/README.md#hooks-do-claude-code).

Os blocos gerados registram o caminho absoluto da fonte local. Não versione uma
regra pessoal ou de projeto gerada e espere que funcione em outra máquina: clone
a fonte no destino e execute o instalador novamente. Essa informação também pode
revelar o nome do usuário ou a organização do filesystem; revise o diff antes de
publicar arquivos de configuração gerados.

| Host | Skills de projeto | Regras |
| --- | --- | --- |
| Codex | .agents/skills | AGENTS.md com núcleo expandido |
| Claude Code | .claude/skills | CLAUDE.md importa AGENTS.md |
| Cursor | .agents/skills | AGENTS.md com núcleo expandido |
| Antigravity | .agents/skills | .agents/rules/ai-agent-config.md |

No Antigravity, verifique no painel Rules se a regra foi reconhecida e marque
Always On. O instalador não afirma que escrever Markdown configurou a ativação
na versão instalada. Versões antigas podem usar .agent/rules e .agent/skills;
confira os caminhos na UI antes de optar por um adaptador legado.

No escopo pessoal, Codex/Cursor usam .agents/skills, Claude usa
.claude/skills e Antigravity usa .gemini/config/skills segundo a documentação
consultada. O Codex reutiliza .codex/skills quando encontra ali links desta fonte.
Cursor pessoal instala skills; regras são integradas por projeto. Hosts podem
exibir aliases duplicados ao descobrir vários diretórios; confirme o alvo real.

## Antigravity e retirada do Gemini CLI

Gemini CLI foi retirado do escopo por decisão do usuário em 2026-09-08, após
o serviço recusar o cliente no login individual apesar do sucesso no navegador.
O instalador rejeita `--agents gemini`. Isso não desinstala o executável nem
remove credenciais ou arquivos existentes de outros projetos.

Antigravity permanece suportado: regras pessoais em `~/.gemini/GEMINI.md`
e sete symlinks em `~/.gemini/config/skills/`. Esses caminhos devem ser
preservados; o nome `.gemini` não significa uso exclusivo pelo Gemini CLI.
O `GEMINI.md` da raiz é orientação local para Antigravity, não uma cópia da
configuração pessoal.

Nas sessões verificadas, o acesso fora do workspace foi liberado em Settings
→ General → File Access → Agent Non-Workspace File Access. Essa opção amplia
o acesso a arquivos externos, não apenas ao cofre, nem apenas para leitura.
Como alternativa de menor escopo, inclua o repositório e o cofre nas pastas
do workspace e mantenha a opção desativada. Confirme sempre a leitura efetiva
da skill, do índice e do protocolo em uma nova sessão.

## Contexto e autoridade

O núcleo está em [agent-core.md](../context/agent-core.md). As regras geradas
contêm sua versão atual e a raiz local da fonte; reaplique o instalador quando
atualizar o núcleo. O cofre padrão pode ser substituído por um caminho informado
pelo usuário ou por AI_AGENT_VAULT (convenção deste repositório, não opção nativa
dos agentes). Nenhum caminho concede acesso fora do sandbox.

Nos perfis pessoais, o bloco gerenciado é a fonte canônica de roteamento,
consulta ao cofre e tratamento de evidências. O instalador preserva preferências
fora desse bloco; não edite cópias do núcleo individualmente por host. Depois
de atualizar a fonte, revise o plano `--user --agents codex,claude,antigravity`
e aplique-o com `--apply`. Regras de projetos consumidores também precisam ser
atualizadas nos respectivos destinos. Backups anteriores exigem revisão antes
de outra aplicação; nunca os apague automaticamente para desbloquear o comando.

O README/AGENTS deste repositório orientam sua manutenção. Os adaptadores dos
projetos consumidores levam somente o núcleo compartilhado. Eles não mandam
executar scripts de manutenção do ai-agent-config em outros projetos.

## Verificações reproduzíveis

```bash
ruby scripts/sync-platforms.rb
ruby scripts/check-context-drift.rb
./scripts/validate-structure.sh
ruby scripts/test-integration.rb
```

O primeiro comando é somente plano. Use `--apply` para sincronizar e repita o
check de drift. O renderer também pode ser inspecionado sem escrita:

```bash
ruby scripts/render-agent-context.rb --adapter codex
```

Os testes cobrem YAML inválido, campos/tipos/nomes inválidos, recursos ausentes,
skills/tópicos incompletos, imports e instalação não destrutiva. São checks
estruturais; não comprovam o comportamento de um modelo.

Para sessões reais, use um projeto de teste com os adaptadores instalados e
execute os casos de [session-cases.md](../tests/session-cases.md). Registre host,
versão, prompt, skill selecionada, arquivos lidos, resposta e critério de aceite.
Não registre credenciais nem invente sucesso quando rede, autenticação ou trust
impedirem o teste. Sessões devem ser somente leitura; nenhum caso exige produção.

Consulte a [matriz de validação](../tests/session-results.md) antes de afirmar
conclusão. Distinga resultados históricos da fonte atual: após mudar instruções,
repita os casos afetados em novas conversas. Aprovação por chamada explícita não
resolve falha anterior de seleção automática; pacotes válidos não comprovam
upload nem funcionamento isolado.

Fontes verificadas em 2026-09-08: [Codex](https://learn.chatgpt.com/docs/build-skills),
[Claude](https://code.claude.com/docs/en/memory),
[Cursor](https://cursor.com/help/customization/skills),
[Antigravity](https://antigravity.google/docs/skills).
