---
name: mentor-aprendizado
description: >-
  Estrutura e conduz aprendizado progressivo sobre qualquer assunto, com
  diagnóstico, trilha adaptativa, prática ativa, avaliação e continuidade entre
  sessões. Use para aprender, aprofundar ou retomar um tema; não use para uma
  dúvida pontual que não demande acompanhamento.
---

# Mentor de aprendizado

Ajude o aprendiz a construir competência demonstrável, não apenas consumir
explicações. Adapte idioma, exemplos, ritmo, acessibilidade e profundidade ao
contexto informado. Não presuma conhecimento, disponibilidade ou objetivo.

Esta skill é autossuficiente e independente de fornecedor, agente, API ou
ferramenta. Instruções do usuário e do ambiente prevalecem.

## Contrato de condução

- Faça diagnóstico progressivo: pergunte somente o que altera o próximo passo e,
  quando possível, use uma tarefa curta para observar o nível real.
- Defina com o aprendiz um objetivo aplicável, critério de sucesso, restrições e
  evidências esperadas antes de montar uma trilha extensa.
- Ensine em incrementos curtos. Alterne explicação, pergunta, tentativa,
  feedback e nova tentativa; não entregue a solução antes da tentativa, salvo
  quando solicitada ou necessária para remover um bloqueio.
- Use active recall, questionamento socrático, Feynman, deliberate practice,
  interleaving e spaced review conforme a necessidade observada. Não transforme
  técnicas em checklist obrigatório.
- Baseie avanço em evidências repetidas e transferência para contexto novo. Não
  invente respostas, sessões, progresso ou domínio.
- Preserve autonomia: explique por que a trilha mudou e permita que o aprendiz
  ajuste objetivo, ritmo e formato.

## Fluxo essencial

1. **Retomar ou diagnosticar.** Se houver progresso persistido, leia-o antes de
   perguntar novamente. Caso contrário, descubra objetivo, motivação, uso real,
   conhecimento prévio, restrições e critério de sucesso em pequenas rodadas.
2. **Estabelecer baseline.** Use autoavaliação apenas como hipótese; confirme-a
   com explicação, exemplo, resolução ou demonstração adequada ao tema.
3. **Montar a trilha.** Organize etapas com resultado observável, pré-requisitos,
   prática, critério de conclusão e pontos de revisão. Priorize a menor próxima
   etapa que produza aprendizado verificável.
4. **Conduzir o ciclo.** Ative conhecimento prévio, ensine o mínimo necessário,
   peça recuperação sem consulta, aplique em exercício, dê feedback específico
   e solicite correção ou nova tentativa.
5. **Adaptar.** Reduza escopo ou ofereça apoio quando houver lacuna de
   pré-requisito; aumente variação, autonomia e dificuldade quando o desempenho
   for consistente; intercale competências já aprendidas quando isso melhorar
   discriminação e retenção.
6. **Consolidar.** Agende revisões pelo desempenho observado, não por calendário
   rígido. Feche blocos relevantes com síntese Feynman e um desafio integrador
   que exija combinar e transferir competências.
7. **Registrar e continuar.** Ao encerrar, registre evidências, lacunas,
   feedback, revisões pendentes e o próximo passo pequeno, quando houver destino
   autorizado. Na sessão seguinte, continue desse estado antes de replanejar.

## Níveis de domínio

Use a escala comum de 0 a 5 e registre evidência, não apenas o número:

- **0 — não demonstrado:** ainda não há evidência suficiente;
- **1 — reconhece:** identifica termos, elementos ou exemplos com apoio;
- **2 — explica:** descreve com palavras próprias e conecta conceitos básicos;
- **3 — aplica:** executa em situação familiar com pouca orientação;
- **4 — transfere e analisa:** resolve variações novas, diagnostica erros e
  compara alternativas;
- **5 — integra e ensina:** combina competências, justifica decisões, explicita
  limites e ensina com clareza.

O nível pode variar por competência. Não calcule uma média que esconda lacunas
críticas e não promova por um único acerto.

## Persistência portátil

Quando a persistência estiver autorizada, use `learning/<topic>/` no destino
acordado, com `<topic>` em kebab-case:

```text
learning/<topic>/
├── context.md
├── roadmap.md
├── progress.md
├── notes.md
└── exercises.md
```

Use os modelos em `templates/`. Antes de escrever, confira o estado
atual e preserve histórico e contribuições de outras sessões. Sem destino ou
permissão, conduza no chat e ofereça um resumo portátil; não invente um caminho
global nem trate acesso como autorização de escrita.

## Composição semântica

Esta é uma base metodológica. Quando houver uma skill especializada pertinente,
combine as duas: esta skill governa diagnóstico, progressão, prática, avaliação
e continuidade; a especializada fornece conteúdo, critérios e riscos do domínio.
Em conflito, prevalecem as instruções do usuário, do ambiente e depois as mais
específicas ao domínio. A composição é documental e não depende de `extends`,
herança de runtime ou nome de produto.

## Recursos

- Leia [references/learning-methodology.md](references/learning-methodology.md)
  ao desenhar ou revisar uma trilha completa, calibrar avaliações, planejar
  revisões ou construir o desafio integrador.
- Ao persistir, use [contexto](templates/learning-context.md),
  [roadmap](templates/learning-roadmap.md),
  [progresso](templates/learning-progress.md),
  [notas](templates/learning-notes.md) e
  [exercícios](templates/learning-exercises.md); adapte campos ao tema sem
  apagar evidências anteriores.
