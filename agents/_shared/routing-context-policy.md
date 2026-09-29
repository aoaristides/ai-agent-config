# Policy de routing e contexto

## Routing

1. Classifique o objetivo principal e selecione o agente com ownership direto no
   `agents/catalog.yml`.
2. Prefira execução por um agente. Adicione outro apenas por mudança de ownership,
   necessidade de especialidade ou revisão independente.
3. Não execute o pipeline completo por padrão. Produto, arquitetura, segurança e
   performance entram quando seus gatilhos estiverem presentes.
4. O `orchestrator` coordena; ele não substitui decisão de produto, arquitetura,
   implementação ou aprovação humana.
5. Se dois agentes puderem atender, escolha o dono do resultado pedido. O outro
   vira consultado ou destinatário de handoff, não coautor implícito.

## Composição de contexto

Carregue, nesta ordem:

1. kernel e núcleo compartilhado;
2. definição do agente selecionado;
3. no máximo a role e o workflow necessários para a etapa atual;
4. skills exigidas pelo tipo de trabalho;
5. projeto, context pack e evidências diretamente relacionados.

Não carregue todo o catálogo, todas as skills ou todos os projetos. Ao trocar de
agente, transfira o handoff e carregue o contexto do destinatário; não replique
o histórico inteiro. As listas de workflows e skills do catálogo são candidatas;
use somente as que tiverem gatilho na etapa atual. Parâmetros quantitativos
ausentes continuam desconhecidos.

## Compatibilidade entre hosts

- Com delegação nativa: cada agente precisa ter efetivamente o kernel, o núcleo
  compartilhado e as regras de segurança, além de seu contrato e do handoff. Só
  trate esse contexto como herdado quando o mecanismo do host tiver sido
  verificado na sessão atual. Sem essa evidência, o `orchestrator` deve incluí-lo
  explicitamente; nunca presuma herança e continue sem os guardrails.
- Sem delegação nativa: o host alterna explicitamente o contrato ativo e mantém o
  mesmo envelope de handoff.
- O adapter traduz somente descoberta e carregamento. Regras técnicas e de
  negócio permanecem nas fontes canônicas compartilhadas.
