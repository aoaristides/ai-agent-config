# AI Agent Config

Configuração compartilhada e portátil para agentes de IA: perfis, skills,
conhecimento técnico curado, trilhas de aprendizado, templates e contexto de
projetos.

## Integração com os agentes

Consulte [o guia de integração](docs/agent-integration.md). Criar uma pasta em
`skills/` não instala a skill nos agentes. O instalador oferece um plano sem
escrita e aplicação explícita, preservando instruções e links existentes:

```bash
ruby scripts/install-agents.rb --user --agents codex,claude,gemini,antigravity
```

Acrescente `--apply` para aplicar. Para um projeto consumidor, use `--project`
com o caminho absoluto do projeto. O núcleo está em
[context/agent-core.md](context/agent-core.md); Claude/Gemini usam importações
nativas, e os demais adaptadores recebem instruções no formato do host.

Validação completa da fonte: `./scripts/validate-structure.sh`.
Regressões e instalação isolada: `ruby scripts/test-integration.rb`.
Sessões reais: [casos e critérios de aceite](tests/session-cases.md).
O sucesso desses testes estruturais não certifica uma sessão real de modelo.

## Estrutura e fonte canônica

- `AGENTS.md` e `CLAUDE.md` — pontos de entrada compatíveis para agentes.
- `profiles/` — contexto técnico e preferências relativamente estáveis.
- `skills/` — comportamento especializado; cada skill tem um `SKILL.md`.
- `knowledge/` — modelos mentais e checklists técnicos reutilizáveis.
- `learning/` — contexto, roadmap, progresso, notas e exercícios por tema.
- `templates/` — modelos de ADR, reviews, incidentes, projetos e estudo.
- `projects/` — contexto portátil de projetos, com exemplo inicial.
- `prompts/` — entradas curtas que encaminham para as skills apropriadas.
- `scripts/package-skills.sh` — valida e empacota as skills para upload.
- `scripts/create-learning-topic.sh` — cria uma trilha sem sobrescrever tópicos.
- `scripts/validate-structure.sh` — valida arquivos obrigatórios e skills.
- `dist/` — ZIPs gerados localmente, fora do versionamento.

As skills são agnósticas ao agente. A fonte canônica é:

`~/ai-agent-config/skills/`

Edite o `SKILL.md` e seus recursos sempre nessa pasta. Os symlinks locais e os
ZIPs para upload derivam dessa mesma fonte.

## Claude Code e Codex: symlinks locais

[fato] Nesta instalação, Claude Code e Codex acessam as duas skills por symlinks:

| Agente | Symlink local | Destino canônico |
| --- | --- | --- |
| Claude Code | `~/.claude/skills/arquiteto-solucoes` | `~/ai-agent-config/skills/arquiteto-solucoes` |
| Claude Code | `~/.claude/skills/engenheiro-software-senior` | `~/ai-agent-config/skills/engenheiro-software-senior` |
| Codex | `~/.codex/skills/arquiteto-solucoes` | `~/ai-agent-config/skills/arquiteto-solucoes` |
| Codex | `~/.codex/skills/engenheiro-software-senior` | `~/ai-agent-config/skills/engenheiro-software-senior` |

Os links apontam para os mesmos arquivos; não é necessário copiar as alterações
nem gerar ZIPs para esses consumidores locais. Isso não garante que uma sessão
já aberta recarregue instruções que leu anteriormente: após editar, valide em
uma nova sessão e reinicie o agente caso a alteração não apareça.

Para conferir os links existentes:

```bash
ls -l ~/.claude/skills/ ~/.codex/skills/
```

[fato] A documentação atual do Codex confirma o suporte a pastas de skills via
symlink e lista `~/.agents/skills/` como diretório de usuário. Os caminhos
`~/.codex/skills/` acima descrevem a configuração local deste repositório;
ao configurar outra instalação, confira os locais de descoberta da versão usada.
Veja a [documentação oficial de skills do Codex](https://learn.chatgpt.com/docs/build-skills).

## Claude UI: distribuição por upload

A UI do Claude (web ou aplicativo, no fluxo de skills pessoais) não lê os
symlinks locais de `~/.claude/skills/` ou `~/.codex/skills/`. Ela usa a skill
enviada por upload. Alterar a fonte no Mac não atualiza automaticamente a
versão enviada: é necessário gerar um novo ZIP e atualizar a skill na UI.

### Gerar os ZIPs

Pré-requisitos: Bash, Ruby com a biblioteca YAML, `zip` e as ferramentas usadas
pelo script (`find`, `sort` com suporte a `-z` e `sed`) disponíveis no terminal.
O script precisa ter permissão de execução.

Na raiz do repositório, execute:

```bash
cd ~/ai-agent-config
./scripts/package-skills.sh
```

Se houver erro de permissão de execução, ajuste uma vez e repita:

```bash
chmod +x ./scripts/package-skills.sh
./scripts/package-skills.sh
```

[fato] O script encontra as subpastas diretamente em `skills/` que contêm
`SKILL.md`, valida o frontmatter YAML e a presença de `name` e `description`,
e recria o ZIP correspondente em `dist/`. Ele exclui arquivos como `.DS_Store`,
metadados de Git/IDE e temporários. Essa validação não substitui a validação de
upload do Claude.

Com as skills atuais, é gerado um ZIP por subpasta válida de `skills/`, por
exemplo:

```text
~/ai-agent-config/dist/arquiteto-solucoes.zip
~/ai-agent-config/dist/engenheiro-software-senior.zip
~/ai-agent-config/dist/mentor-tecnico.zip
```

Cada ZIP contém a pasta da própria skill na raiz, com `SKILL.md` e seus recursos
internos. Envie cada ZIP individualmente, sem compactar `dist/` inteira. Essa é a
[estrutura de pacote documentada pelo Claude](https://support.claude.com/en/articles/12512198-how-to-create-custom-skills).

### Fazer upload e atualizar na UI

[fato] O fluxo documentado para adicionar uma skill é:

1. Abra **Personalizar → Skills** (**Customize → Skills**).
2. Clique em **+ → Criar skill** (**Create skill**).
3. Selecione **Fazer upload de uma skill** (**Upload a skill**).
4. Escolha o ZIP correspondente em `~/ai-agent-config/dist/`.
5. Confira se a skill aparece na lista e habilite-a.

Se a seção não estiver disponível, confira se a execução de código e criação de
arquivos está habilitada; em contas organizacionais, confira também a permissão
para criar skills. Consulte o [guia oficial de uso de skills no Claude](https://support.claude.com/en/articles/12512180-use-skills-in-claude).

Para atualizar uma skill já instalada, gere novamente os ZIPs e abra a skill
existente na UI. Se a interface oferecer substituição do pacote, envie o novo
ZIP por essa opção. Caso não ofereça, desative a versão antiga e faça um novo
upload pelo fluxo acima; habilite e teste a nova versão antes de remover a antiga.
Evite manter duas versões da mesma skill ativas. Não presuma que um upload com
o mesmo nome substitui automaticamente a versão anterior.

Os rótulos e as opções de atualização podem variar na interface. O script apenas
gera os pacotes locais; ele não faz upload nem sincroniza a conta do Claude.

### Gitignore

[fato] O `.gitignore` já contém estas regras, que devem ser mantidas:

```gitignore
dist/
*.zip
```

Versione a fonte em `skills/`, o script e a documentação. Os ZIPs são artefatos
regeneráveis para distribuição. As regras de ignore não deixam de rastrear um
arquivo que já tenha sido versionado anteriormente.

## Workflow após editar uma skill

1. Edite `~/ai-agent-config/skills/<nome-da-skill>/SKILL.md` e os recursos necessários.
2. Valide a alteração em uma nova sessão do Claude Code e/ou Codex; os symlinks
   continuam apontando para a fonte atualizada.
3. Na raiz de `~/ai-agent-config`, execute `./scripts/package-skills.sh` e confira
   a conclusão sem erros e os arquivos gerados em `dist/`.
4. Atualize na UI do Claude cada skill alterada usando seu novo ZIP.
5. Habilite a versão atual e teste uma solicitação compatível com a skill em uma
   nova conversa para conferir o comportamento.
6. Revise o diff da fonte e da documentação. Mantenha `dist/` e `*.zip` fora do Git;
   faça commit e push somente quando decidir explicitamente versionar/publicar.

## Segundo cérebro

Este repositório guarda a parte **portátil e versionada** do segundo cérebro:
comportamento dos agentes, perfil técnico, conhecimento curado, templates e
trilhas de aprendizado.

O conhecimento **vivo e factual** continua separado no Obsidian:

Vault:

`~/obsidian/claude-second-brain/`

O cofre continua sendo a fonte de verdade para decisões reais, estado de
projetos, preferências confirmadas, gotchas e aprendizados observados. Não copie
automaticamente notas entre os dois locais: defina a autoridade antes de
registrar para evitar divergência.

## Árvore do segundo cérebro

```text
ai-agent-config/
├── AGENTS.md
├── CLAUDE.md
├── profiles/
├── skills/
│   ├── arquiteto-solucoes/
│   ├── engenheiro-software-senior/
│   ├── mentor-tecnico/
│   ├── architecture-review/
│   ├── code-review/
│   └── troubleshooting/
├── knowledge/
│   ├── architecture/  java/  spring/  kafka/
│   ├── kubernetes/    cloud/ ddd/     databases/
│   └── observability/ performance/ ai-engineering/
├── learning/
│   ├── kafka/
│   └── ddd/
├── templates/
├── projects/
├── prompts/
└── scripts/
```

## Criar uma nova trilha

```bash
./scripts/create-learning-topic.sh spring-security
```

O comando aceita nomes em kebab-case e recusa sobrescrever uma pasta existente.
Ele cria `context.md`, `roadmap.md`, `progress.md`, `notes.md` e `exercises.md`.

## Validar a estrutura

```bash
./scripts/validate-structure.sh
```

Execute a validação antes de empacotar skills. Ela interpreta YAML, valida
nome/pasta, campos, limites, corpo, referências obrigatórias do pacote, todos
os tópicos de aprendizado, arquivos do manifesto e imports de contexto.
O package-skills.sh existente permanece preservado; execute a validação primeiro.

## Regra

Não editar cópias específicas em `.claude` ou `.codex`.

Editar sempre a fonte canônica em:

`~/ai-agent-config/skills/`
