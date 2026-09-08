# Integração local e validação

Fonte canônica: este repositório. As skills são autossuficientes; recursos do
repositório central e outras skills são opcionais. O pacote da engenharia inclui
suas referências locais. Os ZIPs não transportam o cofre nem as trilhas pessoais.

## Instalar sem sobrescrever configuração existente

Pré-requisitos: Ruby com YAML (o mesmo usado pelo empacotador), Bash e permissões
de escrita nos destinos escolhidos. O script usa symlinks locais; para outra
máquina, clone a fonte e execute ali. Não leve links absolutos para ambientes cloud.

Na raiz da fonte, visualize o plano de instalação pessoal:

```bash
ruby scripts/install-agents.rb --user --agents codex,claude,gemini,antigravity
```

Para aplicá-lo, acrescente `--apply`. Em um projeto consumidor existente:

```bash
ruby scripts/install-agents.rb --project /caminho/absoluto/do/projeto
```

O plano não escreve. A aplicação valida primeiro os conflitos, mantém links
corretos, recusa arquivos/diretórios que ocupariam o lugar de uma skill, e
acrescenta um bloco identificado às regras. Instruções anteriores são preservadas.
Se alterar uma regra existente, cria um backup `.ai-agent-config.bak`. Um backup
prévio nunca é sobrescrito: revise e guarde-o antes de atualizar novamente.
Uma falha durante a aplicação pode deixar parte da instalação pronta; repita o
plano após resolver a causa. Não há promessa de transação entre vários arquivos.

| Host | Skills de projeto | Regras |
| --- | --- | --- |
| Codex | .agents/skills | AGENTS.md com núcleo expandido |
| Claude Code | .claude/skills | CLAUDE.md importa AGENTS.md |
| Cursor | .agents/skills | AGENTS.md com núcleo expandido |
| Gemini CLI | .agents/skills | GEMINI.md importa AGENTS.md |
| Antigravity | .agents/skills | .agents/rules/ai-agent-config.md |

No Antigravity, verifique no painel Rules se a regra foi reconhecida e marque
Always On. O instalador não afirma que escrever Markdown configurou a ativação
na versão instalada. Versões antigas podem usar .agent/rules e .agent/skills;
confira os caminhos na UI antes de optar por um adaptador legado.

No escopo pessoal, Codex/Gemini/Cursor usam .agents/skills, Claude usa
.claude/skills e Antigravity usa .gemini/config/skills segundo a documentação
consultada. O Codex reutiliza .codex/skills quando encontra ali links desta fonte.
Cursor pessoal instala skills; regras são integradas por projeto. Hosts podem
exibir aliases duplicados ao descobrir vários diretórios; confirme o alvo real.

## Contexto e autoridade

O núcleo está em [agent-core.md](../context/agent-core.md). As regras geradas
contêm sua versão atual e a raiz local da fonte; reaplique o instalador quando
atualizar o núcleo. O cofre padrão pode ser substituído por um caminho informado
pelo usuário ou por AI_AGENT_VAULT (convenção deste repositório, não opção nativa
dos agentes). Nenhum caminho concede acesso fora do sandbox.

O README/AGENTS deste repositório orientam sua manutenção. Os adaptadores dos
projetos consumidores levam somente o núcleo compartilhado. Eles não mandam
executar scripts de manutenção do ai-agent-config em outros projetos.

## Verificações reproduzíveis

```bash
./scripts/validate-structure.sh
ruby scripts/test-integration.rb
```

Os testes cobrem YAML inválido, campos/tipos/nomes inválidos, recursos ausentes,
skills/tópicos incompletos, imports e instalação não destrutiva. São checks
estruturais; não comprovam o comportamento de um modelo.

Para sessões reais, use um projeto de teste com os adaptadores instalados e
execute os casos de [session-cases.md](../tests/session-cases.md). Registre host,
versão, prompt, skill selecionada, arquivos lidos, resposta e critério de aceite.
Não registre credenciais nem invente sucesso quando rede, autenticação ou trust
impedirem o teste. Sessões devem ser somente leitura; nenhum caso exige produção.

Fontes verificadas em 2026-09-08: [Codex](https://learn.chatgpt.com/docs/build-skills),
[Claude](https://code.claude.com/docs/en/memory),
[Cursor](https://cursor.com/help/customization/skills),
[Gemini](https://geminicli.com/docs/cli/using-agent-skills/),
[Antigravity](https://antigravity.google/docs/skills).
