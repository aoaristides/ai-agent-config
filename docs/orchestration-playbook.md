# Coordenação prática: Codex, Claude Code e Antigravity

Este roteiro descreve a configuração atual da biblioteca e um fluxo manual de
trabalho entre hosts. Os três hosts compartilham contratos, regras e skills
instalados por `scripts/install-agents.rb`; eles não compartilham uma fila de
tarefas nem transferem sessões automaticamente. A passagem entre hosts usa um
handoff explícito, salvo no projeto consumidor.

## Preparar e conferir

Na raiz de `ai-agent-config`, confira o plano e o estado da fonte:

```bash
ruby scripts/install-agents.rb --user --agents codex,claude,antigravity
ruby scripts/check-context-drift.rb
./scripts/validate-structure.sh
ruby scripts/test-integration.rb
```

O primeiro comando é dry-run. `--apply` instala ou atualiza regras e links de
skills; faça isso somente depois de revisar os destinos. Para um projeto
consumidor, use `ruby scripts/install-agents.rb --project /caminho/absoluto/do/projeto`
e acrescente `--apply` depois de revisar o plano. Abra sessões novas e confira
se cada host leu as regras. No Antigravity, confirme a regra no painel Rules.

Execute o resolver de memória a partir do projeto atendido, pelo caminho
absoluto do script. Na instalação desta máquina:

```bash
ruby /Users/andersonorione/ai-agent-config/scripts/resolve-memory.rb --format json
```

O backend padrão versionado é `ai-memory`; o cofre local só fica efetivo após a
troca descrita em [seleção de memória](persistent-memory.md). O resolver não
concede acesso ao MCP nem ao filesystem. Confira a conexão no host utilizado.

## Escolher o owner da etapa

O [roteamento padrão](../core/agent-platform.md#roteamento-padrão) chega aos
três hosts pelas regras geradas. Em uma sessão com as regras atualizadas,
descreva a tarefa normalmente, com escopo, restrições e autorização. O host
seleciona o responsável e aplica o `orchestrator` quando houver etapas ou
responsabilidades para coordenar. Por exemplo: “Planeje, implemente localmente
e rode os testes de aceite da alteração descrita no ticket.”

| Etapa | Owner do catálogo | Entrega esperada |
| --- | --- | --- |
| Escopo e aceite ambíguos | `product-manager` | Problema, limites e critérios observáveis |
| Decisão estrutural | `architect` | Opções, trade-offs e ADR proposto quando necessário |
| Implementação ou diagnóstico | `software-engineer` | Mudança ou causa sustentada por evidências |
| Validação independente | `tester` | Resultado de testes e lacunas de aceite |
| Revisão independente | `code-reviewer` | Achados por risco, ligados ao diff e contrato |
| Risco específico | `security-engineer` ou `performance-engineer` | Avaliação focada, com evidências |
| Dependências entre owners | `orchestrator` | Sequência, handoffs e reconciliação |

Use um owner só quando ele puder concluir o trabalho. `orchestrator` coordena
uma entrega que cruza responsabilidades; ele não é um scheduler. O catálogo está
em [`agents/catalog.yml`](../agents/catalog.yml), e a regra de seleção em
[`routing-context-policy.md`](../agents/_shared/routing-context-policy.md).

Para inspecionar o perfil de modelo antes de materializar um especialista:

```bash
ruby scripts/resolve-model.rb --runtime codex --agent software-engineer --format json
ruby scripts/resolve-model.rb --runtime claude --agent code-reviewer --format json
ruby scripts/resolve-model.rb --runtime antigravity --agent tester --format json
```

Use o `host_selector` retornado quando `materializable` for `true` e o host
aceitar a seleção. No Antigravity, `selection_mode: advisory` e
`materializable: false` expressam preferência, sem provar que o modelo foi
aplicado a um subagente. O resultado do resolver não demonstra que a sessão
real carregou o modelo nem que o provedor está disponível.

## Escolher modelos por etapa

| Host | `--phase plan` | `--phase execute` | Alternativa de execução |
| --- | --- | --- | --- |
| Codex | GPT-6.2 Sol | GPT-6 Luna | GPT-6.2 Sol para uma implementação que exija mais raciocínio |
| Claude Code | Opus 5.5 | Sonnet 5.5 | Haiku 5.5 para tarefas bem delimitadas |
| Antigravity CLI | Gemini 4 Carbon (High) | Gemini 4 Hydrogen (Medium) | Gemini 3.8 Flash (Medium) |

Entre no diretório do projeto consumidor para que o cliente carregue seu
contexto. `--format command` mostra como a sessão será aberta. Substitua por
`--launch` para abri-la. O parâmetro `--model` permite escolher outro modelo
declarado para a etapa, só para aquela chamada.

```bash
ruby ~/ai-agent-config/scripts/resolve-model.rb --runtime codex --phase plan --format command
ruby ~/ai-agent-config/scripts/resolve-model.rb --runtime claude --phase execute --model claude-haiku-5-5 --launch
ruby ~/ai-agent-config/scripts/resolve-model.rb --runtime antigravity --phase execute --model gemini-3.8-flash-medium --launch
```

Para mudar o padrão das próximas chamadas, altere `primary` e `fallbacks`
de `planning` ou `execution` no `models.yaml` do host em `adapters/`. No Claude,
um modelo novo também precisa de uma entrada em `selectors` para o perfil de
subagente. Confira o ID no host antes de mudar o arquivo. `agy models` lista
os IDs acessíveis no Antigravity. O launcher passa o ID concreto para a sessão
principal. Exiba o comando ou consulte `--format json` para auditar a resolução.
Somente informe `--unavailable` quando o host confirmar a indisponibilidade
do modelo. Uma falha da sessão é devolvida ao operador.

Em `plan`, o launcher pede sandbox `read-only` ao Codex e o modo `plan` a
Claude Code e Antigravity. Preserve o plano aprovado em um artefato do projeto
por um caminho com permissão de escrita. Passe o link ou caminho à sessão de
`execute`, junto com escopo, critérios de aceite e autoridade. Se a execução
encontrar uma decisão em aberto que afete o contrato, retorne ao planejamento.
Para uma revisão crítica, abra outra sessão com `plan` e entregue o diff e os
critérios. A passagem entre sessões é feita pelo operador.

`--agent` com `--phase` usa a mesma escolha para orientar o modelo do agente.
O campo `host_selector` mantém a semântica do adapter para subagentes. `--launch`
abre uma sessão principal da CLI e o operador fornece o contrato ou handoff.
No Antigravity, a CLI aceita o modelo da sessão, enquanto o resolver segue
reportando `advisory` para materialização de subagentes. O Antigravity também
oferece seu [Orchestrator nativo](https://antigravity.google/docs/models),
que pode combinar Carbon e Hydrogen dentro do mesmo host conforme a conta.

## Exemplo de ponta a ponta

**Cenário ilustrativo:** um projeto precisa alterar uma operação de checkout.
Os textos abaixo são prompts para os hosts, não comandos de shell. Escopo,
contratos e critérios reais devem vir do projeto; não os invente para completar
um handoff.

1. **Codex, coordenação.** Peça: “Use `orchestrator` para identificar os owners
   necessários para esta alteração. Leia `agents/catalog.yml`, a policy de
   routing e os contratos selecionados. Preserve as restrições deste pedido.
   Produza a sequência de trabalho e handoffs; não altere arquivos nesta etapa.”
2. **Codex, descoberta e decisão.** Se escopo ou aceite estiverem indefinidos,
   passe a `product-manager`. Se houver decisão estrutural, passe a `architect`.
   Cada etapa entrega critérios, decisão e fonte verificável antes da próxima.
3. **Claude Code, implementação.** Leve o handoff `ready` para uma sessão nova e
   peça: “Atue como `software-engineer` segundo o contrato da biblioteca. Use
   apenas o escopo e a autoridade deste handoff. Implemente e valide os critérios
   informados; devolva arquivos alterados, testes e riscos restantes.”
4. **Antigravity, validação.** Leve o diff, critérios e um novo handoff para
   `tester`. Peça validação independente somente se houver sessão ou agente
   independente; trocar de papel na mesma conversa é autorrevisão. Se não houver
   despacho nativo, execute os contratos em sequência e registre cada handoff.
5. **Codex ou Claude Code, revisão e fechamento.** Entregue diff e contrato a
   `code-reviewer` em sessão independente, sem antecipar a conclusão desejada.
   O `orchestrator` reconcilia implementação, teste e review e devolve ao usuário
   pendências, evidências e decisão que dependa dele.

Um handoff deve usar [`templates/agent-handoff.md`](../templates/agent-handoff.md)
e cumprir o [protocolo](../agents/_shared/handoff-protocol.md): `task_id`, origem,
destino, status, objetivo, escopo, fora de escopo, autoridade e fonte, localização
do artefato, fatos, decisões, premissas, critérios, artefatos, questões abertas e
ação pedida. Se qualquer conteúdo necessário faltar, marque `blocked`; a mera
frase “escopo aprovado” não substitui o escopo. Um handoff nunca cria permissão
para produção, deploy ou mudança destrutiva.

## Existente e proposta

**Existente:** catálogo de oito agentes, contratos, routing, skills, workflows,
model resolver, adapters dos três hosts, instalação por links/blocos gerenciados,
protocolo de handoff e testes estruturais. Há [evidência histórica de sessões](../tests/session-results.md)
com subagentes em Codex e Claude Code e execução sequencial no Antigravity.

**Proposta de uso:** a sequência Codex → Claude Code → Antigravity → revisão
acima é um exemplo de divisão de trabalho, não uma automação já instalada nem
uma obrigação de usar os três hosts. O projeto consumidor escolhe onde salvar
os handoffs entre sessões. O backend persistente guarda apenas fatos duráveis
solicitados explicitamente, não transcrições ou estado operacional efêmero.
