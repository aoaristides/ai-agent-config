# Captura canônica de conhecimento

## Escopo

O comando `scripts/capture-knowledge.rb` recebe texto ou Markdown fornecido pelo
usuário, associa metadados de proveniência e grava um `CanonicalCapture` JSON na
inbox existente do vault. A entrada é encaminhada pelo adapter indicado em
`--source`; o core apenas cria o envelope canônico e grava o arquivo. O adapter
dedicado do ChatGPT mantém seus defaults e leitura de arquivo isolados. Fontes
sem adapter dedicado continuam aceitas pelo adapter genérico de texto, preservando
o uso provider-agnostic da captura anterior.

O adapter ChatGPT aceita conteúdo copiado ou exportado pelo usuário em texto ou
Markdown. Não acessa o histórico interno, não chama APIs e não executa
processamento com LLM. A captura preserva o conteúdo fornecido como JSON na
inbox. O processor determinístico promove somente conteúdo selecionado pelo
adapter de raciocínio; o Markdown final não inclui a conversa completa. Após
persistir a nota e seu link no índice mestre, o JSON original é movido para
`99-inbox/processed/` como proveniência. Essa área só é criada na execução real.

## Uso

Leia uma conversa exportada de arquivo:

```bash
ruby scripts/capture-knowledge.rb --source chatgpt --file conversation.md
```

Ou envie conteúdo por stdin:

```bash
cat conversation.md | ruby scripts/capture-knowledge.rb --source chatgpt
```

Com metadados de triagem:

```bash
ruby scripts/capture-knowledge.rb \
  --source chatgpt \
  --project agent-runtime \
  --type architecture \
  --title "Second Brain Chat Ingestion" \
  --tags "second-brain,chat-ingestion" \
  --file conversation.md
```

`--file -` também lê stdin. Metadados opcionais: `--project`, `--title`,
`--type`, `--tags`, `--conversation-id`, `--source-url` e `--vault`. Tags são
separadas por vírgula. Sem `--title`, o adapter usa o nome do arquivo ou um
título genérico para stdin. O caminho do vault é escolhido nesta ordem:
`--vault`, `AI_AGENT_VAULT` e `~/obsidian/claude-second-brain/`. O comando grava
em `99-inbox/` e recusa sobrescrever arquivos existentes.

## Contrato

O schema versionado está em
[`schemas/canonical-capture.schema.json`](../schemas/canonical-capture.schema.json).
Cada captura inclui `schema_version`, UUID `capture_id`, `captured_at`,
`source.provider`, `source.title` e `content`. `project`, `type` e `tags` são
opcionais. `type` é uma pista de triagem e não substitui `tipo` do protocolo de
notas do vault. O conteúdo original é armazenado como texto no JSON; não há
normalização específica por fornecedor.

Campos livres adicionais são rejeitados pelo schema. Uma evolução incompatível
do contrato deve incrementar sua versão.

## Processor determinístico (Fase 1)

Inspecione uma captura sem alterar vault ou inbox:

```bash
ruby scripts/process-knowledge.rb \
  --file "$HOME/obsidian/claude-second-brain/99-inbox/capture-UUID.json" \
  --dry-run
```

O provider `rule-based` segue como padrão. LLM é opt-in. A configuração recomenda
120 segundos para desenvolvimento; o valor pode ser ajustado em
`config/reasoning.yml` ou sobrescrito na CLI:

```bash
ruby scripts/process-knowledge.rb --file /caminho/para/capture-UUID.json \
  --provider codex --dry-run
```

Use `--provider claude` para Claude Code CLI; a mesma configuração e override
de timeout se aplicam.
Em falha de execução, acrescente `--provider-debug` para exibir metadados do
processo e stderr com redaction de secrets.
`--fallback-provider rule-based` é o fallback padrão para falhas técnicas;
`--fallback-provider none` desativa esse fallback. “Nenhum conhecimento
durável” é um resultado válido: a captura fica na inbox, sem archive, para
triagem posterior. O limite de confiança e o máximo de candidatos ficam em
`config/reasoning.yml`.

Processe uma captura explicitamente após revisar o dry-run:

```bash
ruby scripts/process-knowledge.rb \
  --file "$HOME/obsidian/claude-second-brain/99-inbox/capture-UUID.json"
```

`--all` processa os arquivos `capture-*.json` diretamente na inbox e nunca é
implícito. O processor valida o contrato, normaliza texto e tags,
classifica/extrai via `SecondBrain::ReasoningProvider`, bloqueia colisões de
destino, só sugere relações com notas existentes, gera Markdown no protocolo do
vault, adiciona o link ao índice mestre e arquiva a origem após sucesso. Captura
inválida, não classificada ou conflitante fica na inbox. A deduplicação automática
usa primeiro o `capture_id` persistido no frontmatter; esse caminho retorna
`duplicate/skip` sem criar outra nota. Depois verifica o destino derivado do
título. Colisão sem o mesmo id é conflito explícito e exige revisão manual; não
gera nomes alternativos nem sobrescreve a nota existente.

Quando o resolver encontra notas relacionadas plausíveis, o provider pode fazer
uma revisão semântica única por candidato, limitada por
`max_semantic_candidates` (padrão configurado: 5). A chamada recebe somente o
candidato e o título/conteúdo dessas notas relacionadas. Sem relações, não há
chamada semântica. `CREATE` e `LINK` podem seguir para persistência; `SKIP`
mantém a captura na inbox quando é a única decisão; `UPDATE` e `MERGE` aparecem
como `*_REVIEW_REQUIRED` no dry-run e bloqueiam qualquer escrita/arquivo na
execução real até revisão manual. Confiança abaixo do `confidence_threshold`
existente rebaixa a decisão a `LINK`. Falha técnica interrompe o processamento e
mantém a captura na inbox. `RuleBasedReasoningProvider` não faz inferência
semântica; nesse caso, relações plausíveis viram `LINK` conservador.

`captured_at` permanece exatamente como veio no CanonicalCapture, em UTC. Os
campos `criado` e `atualizado` usam a data local do processo, respeitando `TZ` ou
o timezone configurado no sistema: `criado` converte `captured_at` para esse fuso
e `atualizado` usa a data local no momento do processamento.

O archive ocorre somente depois da persistência da nota e do índice. Se ocorrer
erro, o capture permanece na inbox; um arquivo de archive conflitante nunca é
sobrescrito. O `--dry-run` apenas lê e exibe cada candidato com confidence,
evidence, relacionamentos, destino, decisão semântica e ação final prevista
(`CREATE`, `LINK`, `SKIP`, `UPDATE_REVIEW_REQUIRED`, `MERGE_REVIEW_REQUIRED` ou
`CONFLICT`), sem criar diretórios, escrever arquivos ou mover captures. Valores
com padrões reconhecidos de token ou credencial são redigidos no preview.
`--provider-debug` continua separado e não é incluído na saída do dry-run.

O provider local usa `type` e seções explícitas `Decisão`, `Arquitetura`,
`Aprendizado`, `Problema` e `Solução`, promovendo somente a primeira afirmação da
seção selecionada. Texto sem seção reconhecida fica na inbox. Não chama modelo
nem serviço externo. No
vocabulário atual do vault, arquitetura é tratada como decisão; uma captura que
não sustente uma categoria existente é recusada para revisão. A Fase 2 poderá
adicionar providers de LLM sem alterar a orquestração.

O destino de archive proposto é `99-inbox/processed/`, pois o protocolo atual não
define outra área. O processamento real pode criar essa pasta somente após a
nota e o índice terem sido persistidos.

A interface de raciocínio está em [`reasoning-provider.md`](reasoning-provider.md).
O processor depende somente dessa interface; `RuleBasedReasoningProvider` é o
default determinístico, e os adapters Codex/Claude são opt-in. O conteúdo da
captura é tratado como dado não confiável pelo prompt versionado em
`prompts/knowledge-extraction-v1.md`. A execução de reasoning não concede ao
modelo escrita no vault: somente a aplicação valida candidatos, renderiza notas
e persiste Markdown.

## Exemplo de item

```json
{
  "schema_version": "1.0",
  "capture_id": "a1a171a9-c32d-4fd4-8cd4-61f4e1e76978",
  "captured_at": "2026-10-06T12:00:00Z",
  "source": {
    "provider": "claude-chat",
    "title": "Exemplo de título"
  },
  "content": "[fato] Candidato curto a conhecimento, sem transcrição da conversa."
}
```
