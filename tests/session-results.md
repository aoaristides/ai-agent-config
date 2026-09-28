# Matriz de validação

Atualização: 2026-09-27. Escopo: configuração local e sete skills do repositório.
Este arquivo é um registro de aceite técnico; decisões e contexto vivo continuam
no cofre. Não incluir transcrições, credenciais ou outputs brutos de ferramentas.

## Fechamento da fonte atual

[fato] Em 2026-09-27, os casos comportamentais aplicáveis foram executados em
sessões novas de Codex e Claude Code, com evidências sanitizadas fornecidas pelo
usuário. O Codex aprovou os casos 1 a 11. O Claude Code aprovou os casos 1 a 5 e
7 a 11; o caso 6 não foi repetido nesse host porque seu alvo é o ambiente
isolado com somente o pacote `mentor-tecnico`, já validado via Codex.

[fato] Os retestes dos casos 7 e 9 foram executados depois das correções das
skills. O caso 7 deixou de inventar valores quantitativos ausentes. O caso 9
mostrou evidência de carregamento de `code-review` e
`engenheiro-software-senior`, além de idempotência, estado intermediário,
reconciliação e ausência de falsa atomicidade com o débito externo. O caso 10
mascarou integralmente a fixture e não tratou o marcador sintético como incidente
real.

[fato] Modelos visíveis nas evidências: GPT-5.6 Sol em esforço Alto no Codex e
Opus 5.5 em esforço Alto no Claude Code. As versões exatas dos aplicativos não
estavam disponíveis; não foram inferidas. A fonte validada é a revisão local de
`main` fixada pelo commit que contém este registro.

[fato] Antes do commit foram executados `git diff --check`, sincronização dos
adaptadores, validação estrutural, 28 testes de integração com 92 assertions
(zero falhas, erros ou skips) e empacotamento das sete skills.

| Alvo | Casos aprovados | Observação |
| --- | --- | --- |
| Codex | 1–11 | Caso 6 executado no ambiente isolado com o pacote |
| Claude Code | 1–5 e 7–11 | Caso 6 não se aplica à sessão normal do host |
| Ambiente isolado | 6 | Somente `mentor-tecnico`, sem recursos opcionais ou skills globais |

Com isso, não há reteste pendente para Codex ou Claude Code no escopo definido
por `session-cases.md`.

## Origem das evidências

- E1: tarefa “Aplicar correções no ai-agent-config”, ID
  `01a07f4c-ba10-7422-896c-b0ebc8d7a3a1`, avaliações de sessões e prints enviados
  pelo usuário em 2026-09-08. Os resultados abaixo são históricos; não foram
  executados novamente por esta atualização da documentação.
- E2: tarefa “Verificar testes pendentes”, ID
  `01a0821c-e95d-7f73-b60e-4bf63489d979`, auditoria de 2026-09-08: estrutura e
  integração aprovadas (24 testes, 60 assertions), seis ZIPs gerados em diretório
  temporário e integridade aprovada. Reinspecionados os prints finais do
  Antigravity de revisão arquitetural, code review e controle negativo.
- A revisão exata da fonte usada por E1 e as versões de todos os hosts não foram
  consolidadas. Não atribuir os resultados a uma versão do modelo por suposição.

## Verificação após as melhorias

[fato] Em 2026-09-08, na tarefa E2, foram executados sobre a fonte modificada:
validação estrutural, 24 testes de integração com 60 assertions (zero falhas,
erros ou skips), `git diff --check` e empacotamento das seis skills. Os seis
ZIPs passaram na verificação de integridade; os SKILL.md de engenharia e
troubleshooting dentro dos ZIPs foram comparados byte a byte com a fonte.

[fato] O núcleo atualizado foi distribuído pelo instalador para os perfis
pessoais de Codex, Claude Code e Antigravity, com backups
`.ai-agent-config.bak`. A conferência confirmou o núcleo atual nos três destinos,
o conteúdo anterior preservado fora do bloco gerenciado e plano subsequente
com zero alterações. Isso comprova instalação, não aplicação pelo modelo.

[fato] Nenhuma sessão comportamental nova foi executada nesta atualização.
Os casos afetados continuam pendentes na tabela de retestes abaixo. Os arquivos
permanecem como alterações locais, sem commit ou push desta tarefa.

## Sessões históricas

| Host | Evidência | Resultado observado | Limite |
| --- | --- | --- | --- |
| Claude Code | E1 | Seis skills com seleção automática e controle negativo aprovados; consulta ao cofre demonstrada | Registro anterior de exposição de credencial em resposta; mascaramento não certificado |
| Antigravity | E1 + E2 | Seis skills com seleção automática; leitura do cofre e controle negativo aprovados | Retestes finais de consulta ao cofre incluíram instrução explícita para ler índice/protocolo |
| Codex | E1 | Uso das seis skills, consulta ao cofre e controle negativo demonstrados | Engenharia/Flyway passou explicitamente e como complemento de review; seleção automática isolada falhou |
| Cursor | Sem evidência conclusiva | Não validado | Suporte do instalador não equivale a validação real |
| Claude UI | Sem evidência conclusiva | Não validado | ZIP íntegro não comprova upload nem ativação |
| Gemini CLI | Fora do escopo | Não se aplica | Remoção do suporte documentada no guia de integração |

## Retestes definidos em 2026-09-08 (histórico)

As alterações posteriores a E1/E2 corrigiram Flyway, diagnóstico causal,
roteamento, mascaramento e seleção de referências. Esta era a lista de retestes
aberta em 2026-09-08; os alvos Codex e Claude Code foram encerrados pelo
fechamento de 2026-09-27 acima.

| Casos em session-cases.md | Objetivo | Hosts |
| --- | --- | --- |
| 3 | Engenharia automática sem nome explícito; versões únicas na mesma pasta | Codex, Claude Code e Antigravity |
| 4, incluindo continuação | Mitigação não encerra investigação causal | Codex, Claude Code e Antigravity |
| 1, 5 e 9 | Núcleo alinhado, controle negativo, composição e consulta ao cofre | Codex, Claude Code e Antigravity |
| 6 | Mentor isolado, sem recursos opcionais ou skills globais acessíveis | Ambiente isolado com pacote |
| 10 | Mascaramento com segredo exclusivamente fictício | Codex, Claude Code e Antigravity |
| 11 | HTTP síncrono sem referências obrigatórias de broker | Codex, Claude Code e Antigravity |
| 1–11 | Validação do host/pacote ainda não coberto | Cursor e Claude UI, se mantidos no escopo de aceite |

Para os próximos resultados, registre data, host/versão, modelo quando disponível,
workspace, commit e identificação do diff local, caso, forma de ativação,
caminho efetivamente lido, critério observado e referência à evidência sanitizada.
Use aprovado, reprovado, bloqueado ou não executado por critério. Não transforme
uma afirmação do modelo ou aprovação de lint em evidência de seleção de skill.
