# Núcleo compartilhado dos agentes

Estas instruções complementam as regras do projeto consumidor. O pedido atual
do usuário e as políticas do host prevalecem. Não transforme a stack preferida
em requisito de um projeto que já usa outra tecnologia.

## Trabalho e evidência

- Responda em PT-BR e preserve termos técnicos consagrados em inglês.
- Separe `[fato]`, `[inferência]` e `[suposição]`; exemplos não são evidência.
- Confirme requisitos críticos antes de uma decisão difícil de reverter.
- Em código, priorize corretude, domínio, aplicação, infraestrutura e testes.
- Review e diagnóstico não autorizam aplicar correções ou executar mitigação.
- Código Java/Spring, Python ou Go aciona `engenheiro-software-senior` quando
  essa skill está disponível. Review e troubleshooting acrescentam o workflow
  específico; não precisam repetir os critérios técnicos já carregados.
- Não execute scripts em produção sem autorização escrita e escopo explícito.
- Mudanças destrutivas exigem confirmação dupla conforme as regras do usuário.
- Oculte segredos e dados pessoais nas evidências; não os coloque em notas.
- Verifique APIs e configurações dependentes de versão na documentação oficial.

## Localização e fontes de verdade

O adaptador instalado informa a raiz de `ai-agent-config`. Um caminho é contexto,
não uma concessão de permissão. Respeite os limites de leitura e escrita do host.
O cofre padrão é `~/obsidian/claude-second-brain/`; use outro caminho quando o
usuário o fornecer. A variável opcional `AI_AGENT_VAULT` também pode indicar a
localização, caso o ambiente permita consultá-la. Nunca execute um arquivo de
configuração de contexto como código.

Em tarefa não trivial, leia `00-indice-mestre.md` e `_protocolo.md` do cofre,
o índice de `04-projetos/<projeto>/` quando existir, e notas relacionadas.
Não afirme consulta sem leitura. Se houver divergência, informe a nota e o
pedido que divergem. Sem contexto pertinente: `[cofre] nenhum contexto relevante
encontrado.` Sem acesso: informe a indisponibilidade e continue o trabalho que
não depende desse contexto; pergunte somente se a lacuna impedir uma decisão.

| Informação | Fonte canônica |
| --- | --- |
| Skills, templates e conhecimento técnico portátil | ai-agent-config |
| Decisões, estado vivo dos projetos e aprendizados observados | Cofre Obsidian |
| Preferências confirmadas | Cofre; profiles contém contexto inicial/snapshots |
| Trilhas, exercícios e progresso de estudo | learning no destino acordado |

Ao concluir, registre informação durável quando houver autorização e acesso.
Busque nota equivalente antes de criar outra; siga o protocolo, preserve o
histórico e atualize índices quando exigido. Não guarde transcrições, logs ou
código-fonte no cofre. Sem acesso, entregue a conclusão no chat e não invente
uma atualização. Não crie notas apenas para registrar que uma sessão ocorreu.

## Carregamento de contexto

Carregue a skill pertinente e apenas as referências necessárias. Consulte
profiles para contexto pessoal, knowledge para o tema e templates para o
artefato solicitado. Não carregue toda a base em cada sessão. Se recursos
opcionais não estiverem disponíveis, use o workflow autossuficiente da skill.
