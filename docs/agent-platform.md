# Fundação da plataforma local de agentes

## Inventário de partida

[fato] Antes desta fundação, o repositório já possuía kernel compartilhado,
compiler de contexto, adapters para Codex, Claude Code e Antigravity, roles,
workflows, context packs, projetos, skills, validação estrutural e testes de
integração. Não existiam catálogo operacional de agentes, contrato comum,
routing entre agentes ou protocolo de handoff.

## Decisão incremental

A plataforma adiciona uma camada `agents/` sobre as fontes atuais:

```text
pedido
  -> routing/context policy
  -> agent contract
  -> model_profile
  -> runtime model mapping
  -> role + workflow
  -> skills/packs/project sob demanda
  -> handoff verificável, se necessário
```

Os oito agentes iniciais são `orchestrator`, `product-manager`, `architect`,
`software-engineer`, `tester`, `code-reviewer`, `security-engineer` e
`performance-engineer`.

## O que foi reaproveitado

- `skills/` continua fonte canônica de conhecimento técnico.
- `roles/` continua definindo comportamento especializado.
- `workflows/` continua definindo processo executável.
- `context-index.md` continua como router humano e seletivo.
- `config/context-manifest.yml` e o compiler continuam gerando os três adapters.
- `models/profiles.yaml` define intenções de capacidade sem nomes de fornecedor;
  `adapters/<runtime>/models.yaml` concentra os nomes concretos.
- O instalador e os symlinks de skills continuam como mecanismo de distribuição;
  o instalador preserva o backup original ao atualizar blocos já gerenciados.

## Alternativas consideradas

1. **Prompts completos por agente.** Facilita copiar para um host, mas duplica
   guardrails e conhecimento; o drift cresce a cada atualização.
2. **Runtime de orquestração agora.** Automatiza execução, mas fixa cedo um SDK,
   modelo de estado e semântica de concorrência ainda não requeridos.
3. **Contratos portáteis sobre a base atual.** Mantém os hosts finos, valida a
   estrutura e permite materialização nativa ou sequencial. Esta foi a opção
   adotada.

## Trade-offs

- Positivo: evolução reversível, baixo acoplamento ao host e ausência de cópia de
  conhecimento técnico.
- Negativo: a primeira versão define contratos e validação, não um scheduler nem
  uma UI de execução.
- Neutro: cada host mantém suas próprias capacidades de paralelismo e permissão;
  o protocolo comum preserva a semântica quando não houver subagentes nativos.

## Evolução — seleção agnóstica de modelos

Os contratos `AGENT.md` permanecem inalterados. Cada entrada de
`agents/catalog.yml` declara apenas um `model_profile`. O resolver lê o mapping
do runtime atual e retorna o primeiro candidato disponível na ordem
`primary -> fallbacks`.

```text
software-engineer
  -> coding-high
  -> adapters/<runtime>/models.yaml
  -> modelo concreto
```

Mappings ausentes e listas esgotadas falham explicitamente. O runtime precisa
informar indisponibilidade concreta; a camada não troca modelo para esconder erro
de autenticação, permissão, ferramenta, prompt ou qualidade.

Cada adapter declara suas capabilities de execução. Codex usa seleção `exact`;
Claude Code usa seleção `alias` e traduz o ID preferido para `host_selector`;
Antigravity usa seleção `advisory`, pois a sessão validada não expôs
materialização nativa de subagente com parâmetro de modelo. O resolver preserva
os campos anteriores e acrescenta `host_selector`, `selection_mode` e
`materializable` para impedir que resolução seja confundida com execução.

## Próximas etapas condicionais

Descoberta, routing de produto e orquestração foram exercitados em sessões reais
nos três hosts. Os casos 12, 14 e 15 também foram exercitados no Codex e no
Claude Code. A escolha de um runtime local, persistência de tarefas ou observabilidade
de orquestração continua condicionada a dor concreta e a requisitos de
concorrência, isolamento, latência, custo e recuperação ainda não fornecidos.
