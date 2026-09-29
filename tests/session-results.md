# Matriz de validação

Atualização: 2026-09-28. Escopo: configuração local, sete skills e fundação da
plataforma de agentes.
Este arquivo é um registro de aceite técnico; decisões e contexto vivo continuam
no cofre. Não incluir transcrições, credenciais ou outputs brutos de ferramentas.

## Fundação multiagente — validação comportamental

[fato] Em 2026-09-28, a fonte passou a incluir catálogo e contratos para oito
agentes, routing/context policy, protocolo de handoff e novos workflows. Foram
executados `git diff --check`, sincronização dos três adapters, validação
estrutural e 30 testes de integração com 96 assertions, sem falhas, erros ou
skips.

[fato] Em sessões reais registradas pelo usuário, Codex, Claude Code e
Antigravity descobriram os oito agentes e aprovaram o caso 13, roteando a
descoberta ambígua de checkout para `product-manager` sem escolher tecnologia ou
alterar arquivos.

[fato] Em um teste adicional de orquestração somente leitura, Codex e Claude Code
despacharam três subagentes distintos (`security-engineer`,
`performance-engineer` e `tester`), aguardaram os três resultados e reconciliaram
os handoffs em uma conclusão consolidada. O Antigravity informou que a sessão não
expunha despacho nativo de subagentes e executou os mesmos contratos
sequencialmente, com handoffs explícitos, conforme o fallback da plataforma.

| Host | Descoberta | Routing — caso 13 | Orquestração observada | Limite da evidência |
| --- | --- | --- | --- | --- |
| Codex | Aprovado | Aprovado | Paralela, com três subagentes nativos | Achados dos especialistas não foram verificados de forma independente |
| Claude Code | Aprovado | Aprovado | Paralela, com três subagentes nativos | Achados dos especialistas não foram verificados de forma independente |
| Antigravity | Aprovado | Aprovado | Sequencial, com troca de contrato e handoffs | Paralelismo nativo não estava disponível nessa sessão |

[fato] Em sessões novas de Codex e Claude Code, os prompts exatos dos casos 12,
14 e 15 foram executados. O caso 12 selecionou somente `software-engineer`; o
caso 14 devolveu o handoff como `blocked` porque o pedido declarava escopo e
aceite fechados sem fornecer seu conteúdo; e o caso 15 preservou os contratos em
execução sequencial, distinguindo autorrevisão de review independente. O routing
de incidente sem causa e sem baseline também permaneceu com
`software-engineer`, usando `workflows/incident-debug.md`, e condicionou o
acionamento de performance a evidência e baseline comparável.

[inferência] A evidência aprova a portabilidade dos contratos de orquestração:
quando o host oferece subagentes, há execução paralela; quando não oferece, o
fallback sequencial preserva ownership e handoffs. Ela não demonstra paralelismo
nativo no Antigravity. Independência de review continua exigindo outra sessão,
outro agente ou uma pessoa; trocar persona na mesma sessão não a produz.

[fato] As revisões dos subagentes levantaram possíveis inconsistências e lacunas
de segurança, validação e coerência entre índice, catálogo e policy. Cada achado
foi reproduzido contra a fonte antes de qualquer correção; a afirmação isolada de
um agente não foi tratada como confirmação nem como autorização para alterar.

## Hardening posterior aos testes de orquestração

[fato] Os achados candidatos foram verificados contra a fonte. Foram corrigidos:
confinamento contra symlinks no empacotador e no sincronizador, quarentena
recuperável de ZIPs órfãos, coerência entre rotas e catálogo, detecção de chaves
YAML duplicadas, rejeição de seções obrigatórias vazias, preservação de authority
nos handoffs, semântica de destino humano, herança explícita do contexto global e
handoffs condicionais de engenharia. A role `tech-lead` passou a ser usada pelo
`orchestrator`.

[fato] O instalador também passou a atualizar blocos já gerenciados sem tentar
substituir o backup original. Os adapters pessoais de Codex, Claude Code e
Antigravity foram atualizados e um segundo plano reportou zero alterações.

[fato] Após o hardening, a validação estrutural passou, os adapters ficaram sem
drift, 38 testes de integração executaram 117 assertions sem falhas, erros ou
skips, os sete ZIPs foram regenerados e passaram no teste de integridade, e
`git diff --check` não encontrou erro.

[fato] Os prompts exatos dos casos 12 e 14 foram aprovados em sessões novas de
Codex e Claude Code. O caso 15 também foi aprovado nesses dois hosts. A correção
e os testes automatizados continuam sem substituir validação comportamental.

## Fechamento após os retestes de Codex e Claude Code

[fato] Os retestes revelaram defeitos adicionais reproduzíveis: validação
dependente do locale do processo; saída `dist/` e quarentena `.stale` sem
confinamento suficiente; `SKILL.md` ou diretório de skill como symlink podendo
ser omitido silenciosamente; arquivo `.env` incluído no ZIP; escape no instalador
com `HOME` terminado por separador e ancestral symlink; `role` opcional no
catálogo; e campos de autoridade e persistência ausentes no handoff.

[fato] A fonte foi corrigida para operar em UTF-8 independentemente do locale,
falhar fechada em symlinks e destinos fora da raiz, rejeitar arquivos
potencialmente sensíveis, exigir `role`, `authority_source` e
`handoff_artifact`, revalidar ancestrais após criação de diretórios e explicitar
que review na mesma sessão é autorrevisão. O workflow de performance agora
mantém o incidente com seu owner até existir sintoma, métrica e baseline
comparável.

[fato] Após essas correções, a validação estrutural passou tanto com locale `C`
quanto com UTF-8; 53 testes de integração executaram 172 assertions, sem falhas,
erros ou skips, também sob locale `C`; os sete ZIPs foram regenerados e passaram
na verificação de integridade; os adapters ficaram sem drift; e
`git diff --check` passou.

## Reteste do Antigravity e regra de completude do handoff

[fato] Em evidências sanitizadas de 2026-09-28, o Antigravity aprovou o routing
mínimo do caso 12, manteve incidentes sem baseline com `software-engineer`,
aprovou o fallback sequencial do caso 15 e repetiu a orquestração somente leitura
com contratos, contexto global de segurança e envelopes contendo
`authority_source` e `handoff_artifact`.

[fato] O caso 14 foi reprovado: embora o pedido apenas declarasse que escopo e
critérios estavam fechados, sem fornecer seu conteúdo, a resposta marcou o
handoff como `ready` e sintetizou `task_id`, escopo, critérios e artefatos. A
fonte já descrevia o aceite do caso, mas o protocolo e o template não tornavam
essa condição de completude igualmente explícita.

[fato] O protocolo e o template foram reforçados para exigir conteúdo explícito,
verificável e com fonte antes de `ready`; declarações abstratas de que algo está
fechado, definido ou aprovado não suprem o conteúdo. Campos ausentes não podem
ser inventados: o envelope deve permanecer `blocked`, registrar cada lacuna e
solicitar os dados faltantes.

[fato] Após o reforço, a validação estrutural passou com locale `C` e UTF-8; 54
testes de integração executaram 188 assertions sem falhas, erros ou skips; os
adapters permaneceram sem drift; e `git diff --check` passou.

[fato] Nesse ponto, o único reteste comportamental pendente era o caso 14. Como
a regra alterada é compartilhada, a regressão foi repetida em sessões novas de
Codex, Claude Code e Antigravity; os demais casos não foram repetidos porque não
eram afetados por essa mudança.

[fato] Nos três hosts, o handoff permaneceu `blocked`, preservou a autoridade de
somente leitura e sua origem, marcou `task_id`, objetivo, escopo, fora de escopo,
critérios e artefatos ausentes como não fornecidos, listou as lacunas e solicitou
os dados faltantes. Nenhuma resposta sintetizou conteúdo ausente nem autorizou
implementação, produção ou deploy.

[inferência] O caso 14 está encerrado nos três hosts e não há reteste
comportamental pendente causado por esse reforço do protocolo.

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

Com isso, não havia reteste pendente para Codex ou Claude Code no escopo dos
casos 1 a 11 daquela revisão. Os casos 12 a 15 foram adicionados depois.

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
- E3: evidências sanitizadas fornecidas pelo usuário em 2026-09-28 para
  descoberta, routing do caso 13 e orquestração com três especialistas no Codex,
  Claude Code e Antigravity. Modelos visíveis: GPT-5.6 Sol em esforço Alto,
  Opus 5.5 em esforço Alto e Gemini 3.8 Flash High, respectivamente. As versões
  exatas dos aplicativos não estavam visíveis e não foram inferidas.
- E4: evidências sanitizadas fornecidas pelo usuário em 2026-09-28 para os
  prompts dos casos 12, 14 e 15, routing de incidente e nova orquestração no
  Codex e Claude Code. Modelos visíveis: GPT-5.6 Sol em esforço Alto e Opus 5.5
  em esforço Alto. As versões exatas dos aplicativos não estavam visíveis e não
  foram inferidas.
- E5: evidências sanitizadas fornecidas pelo usuário em 2026-09-28 para os
  prompts dos casos 12, 14 e 15, routing de incidente e nova orquestração no
  Antigravity. Modelo visível: Gemini 3.8 Flash High. A versão exata do aplicativo
  não estava visível e não foi inferida.
- E6: evidências sanitizadas fornecidas pelo usuário em 2026-09-28 para o reteste
  final do caso 14 em Codex, Claude Code e Antigravity. Os três mantiveram o
  handoff incompleto como `blocked` e não inventaram os campos ausentes. Modelos
  visíveis: GPT-5.6 Sol em esforço Alto, Opus 5.5 em esforço Alto e Gemini 3.8
  Flash High, respectivamente. As versões exatas dos aplicativos não estavam
  visíveis e não foram inferidas.
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

[fato] Na atualização histórica E2, nenhuma sessão comportamental nova foi
executada e os casos afetados permaneceram pendentes naquele momento. Os
fechamentos posteriores desta matriz substituem esse estado, mas não reescrevem
a evidência histórica. Os arquivos permanecem como alterações locais, sem commit
ou push desta tarefa.

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
