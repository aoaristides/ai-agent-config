# AI Agent Config

Configuração compartilhada de skills usadas por diferentes agentes de IA.

## Estrutura e fonte canônica

- `skills/arquiteto-solucoes/`
- `skills/engenheiro-software-senior/`
- `scripts/package-skills.sh` — valida e empacota as skills para upload.
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

Com as duas skills atuais, os arquivos gerados são:

```text
~/ai-agent-config/dist/arquiteto-solucoes.zip
~/ai-agent-config/dist/engenheiro-software-senior.zip
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

O conhecimento persistente fica separado no Obsidian.

Vault:

`~/obsidian/claude-second-brain/`

O repositório `ai-agent-config` contém comportamento/configuração dos agentes,
não o conteúdo do segundo cérebro.

## Regra

Não editar cópias específicas em `.claude` ou `.codex`.

Editar sempre a fonte canônica em:

`~/ai-agent-config/skills/`
