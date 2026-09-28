# mentor-aprendizado

Skill agnóstica para estruturar e acompanhar aprendizado sobre qualquer assunto.
Ela transforma um objetivo amplo em uma sequência adaptativa de diagnóstico,
ensino incremental, prática, feedback, revisão e demonstração de domínio.

## Quando usar

Use quando a pessoa quiser aprender, aprofundar ou retomar um tema ao longo de
uma ou mais sessões. Para uma explicação ou dúvida pontual, responda diretamente
sem iniciar uma trilha persistente.

A skill não pressupõe Codex, Claude Code, Antigravity, API, comando ou diretório
global. O `SKILL.md`, a referência metodológica e os templates formam um pacote
portátil que qualquer agente capaz de ler Markdown pode aplicar.

## Composição com `mentor-tecnico`

`mentor-aprendizado` define o ciclo universal: diagnosticar, planejar, praticar,
avaliar, adaptar e continuar. `mentor-tecnico` acrescenta critérios e exemplos
do domínio técnico, como aplicação em produção, troubleshooting e trade-offs de
engenharia.

Quando ambas estiverem disponíveis, use-as em conjunto sem depender de herança
do runtime:

- `mentor-aprendizado` governa a metodologia e o estado da aprendizagem;
- `mentor-tecnico` governa a profundidade e os critérios técnicos;
- instruções do usuário e do ambiente continuam prevalecendo.

Essa composição é semântica e documental. Não há campo `extends`, import
obrigatório ou acoplamento entre pacotes.

## Persistência

Uma trilha persistida usa a estrutura relativa `learning/<topic>/`, no destino
acordado com o usuário:

```text
learning/<topic>/
├── context.md
├── roadmap.md
├── progress.md
├── notes.md
└── exercises.md
```

Os modelos em `templates/` definem o conteúdo inicial de cada arquivo. O agente
deve ler os cinco arquivos antes de continuar uma sessão, preservar o histórico
e registrar apenas progresso observado. Sem destino autorizado, a mentoria pode
continuar no chat e terminar com um resumo portátil para persistência posterior.

## Conteúdo do pacote

- `SKILL.md`: contrato e fluxo essencial carregado pelo agente;
- `references/learning-methodology.md`: critérios pedagógicos aprofundados;
- `templates/`: estruturas de contexto, roadmap, progresso, notas e exercícios.
