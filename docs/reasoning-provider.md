# ReasoningProvider

## Fronteira

`SecondBrain::ReasoningProvider`, definido em
[`processors/reasoning_provider.rb`](../processors/reasoning_provider.rb), é o
único contrato de raciocínio que o core deve conhecer. O core recebe uma
implementação desse módulo por injeção de dependência. Seleção de modelo,
autenticação, SDK, payloads, retries e conversão de respostas pertencem aos
adapters externos que implementarem o contrato.

O contrato não importa fornecedores no core. Os adapters de comando atuais são
Codex CLI e Claude Code CLI; outros providers podem implementar a mesma porta
sem alterar o `KnowledgeProcessor`.

## Operações

| Método | Entrada neutra | Saída neutra |
| --- | --- | --- |
| `summarize(capture:, context:)` | `CanonicalCapture` e contexto opcional | `String` |
| `classify(capture:, taxonomy:, context:)` | capture, categorias aceitas e contexto opcional | `Hash` estruturado conforme o contrato do core |
| `extract_knowledge(capture:, context:)` | capture e contexto opcional | `Array<Hash>` de candidatos |
| `find_relationships(knowledge:, existing_knowledge:, context:)` | candidato, notas existentes e contexto opcional | `Array<Hash>` de relacionamentos sugeridos |
| `review_semantics(candidate:, related_notes:)` | candidato e somente notas pré-selecionadas pelo resolver | decisão estruturada ou `nil` se não suportada |

Os hashes e arrays usam somente tipos de dados Ruby comuns. Formatos internos de
SDK ou respostas proprietárias não atravessam essa fronteira. O formato detalhado
dos candidatos e relacionamentos é validado pelo provider e pelo
KnowledgeProcessor antes da persistência.

## Regra para o core

`KnowledgeProcessor` depende somente de `SecondBrain::ReasoningProvider` e
recebe a implementação por injeção. A composição e a seleção ficam em
`ReasoningProviderFactory`, fora do processor. A configuração em
[`config/reasoning.yml`](../config/reasoning.yml) mantém `rule-based` como
default; Codex e Claude são opt-in. A CLI recebe `--provider`,
`--fallback-provider` e `--timeout-seconds`. Providers externos exigem timeout
positivo declarado na configuração ou na CLI. A configuração recomenda 120
segundos para desenvolvimento; ajuste `timeout_seconds` no YAML ou sobrescreva
com `--timeout-seconds` conforme o ambiente.

`CommandReasoningProvider` executa argv diretamente, sem interpolação de shell,
envia o prompt por stdin, limita duração, coleta stdout/stderr e valida o
contrato estruturado antes de expor a resposta ao core. Falhas preservam
provider, executable, argv, cwd, exit status, signal, timeout, stdout/stderr e
classe da exceção original. A saída padrão continua resumida; `--provider-debug`
ativa detalhes com redaction de argumentos e conteúdo reconhecido como segredo.
O arquivo [`schemas/knowledge-reasoning-result.schema.json`](../schemas/knowledge-reasoning-result.schema.json)
é o contrato canônico. Na fronteira do Codex, `CodexOutputSchema` copia esse
contrato e adapta `classification.primary_type` de `oneOf` para `anyOf`, forma
aceita pelo Structured Outputs strict. `ClaudeSchemaAdapter` também deriva uma
cópia e remove somente `$schema`, pois a CLI Claude reporta que não consegue
resolver o meta-schema Draft 2020-12. As demais constraints permanecem. A saída
parseada de ambos continua passando pela validação do contrato canônico em
`CommandReasoningProvider`; schemas de provider não substituem a validação de
domínio.
`review_semantics` é uma operação opcional do mesmo contrato. Codex e Claude
usam schema e prompt próprios na borda do adapter; o core valida novamente
`action`, `confidence`, `target`, `reason` e `novel_information`. O prompt
versionado está em
[`semantic-dedup-review-v1.md`](../prompts/semantic-dedup-review-v1.md). O
processor só a chama após `capture_id`, conflito de destino e relationship
resolution, com limite configurável de notas por candidato. `UPDATE` e `MERGE`
são somente propostas: processamento real bloqueia escrita e conserva a captura
na inbox. Providers sem suporte retornam `nil`, levando a `LINK` conservador;
falha técnica não usa fallback determinístico para decidir duplicidade.
`CodexReasoningProvider`
usa `codex exec` em sandbox read-only e efêmero, com config pessoal desativada.
O help da versão instalada não expõe uma opção para desativar tools nem para
fixar a política de aprovação nessa chamada; o prompt proíbe seu uso, mas esse
limite não equivale a uma barreira de segurança. `ClaudeReasoningProvider` usa
`claude --print`, saída estruturada, sem tools e sem persistência de sessão.
O fallback opcional cobre somente falha técnica (indisponibilidade, timeout,
exit code não zero ou resposta inválida). Uma resposta válida sem candidatos é
resultado de negócio e não aciona fallback.

O processor persiste apenas candidatos que excedam `confidence_threshold`, até
`max_candidates`; ambos são configuráveis. A captura canônica original continua
na inbox até notas e índice serem gravados, e então vai para `99-inbox/processed/`.
`--dry-run` não grava nota, índice ou archive. O runner inicia cada processo em
um diretório temporário privado (modo `0700`), passa a captura somente por
stdin/prompt e remove o diretório ao sair, inclusive após exit code não zero.
Nenhum arquivo do vault é copiado. Para satisfazer `codex exec --output-schema`,
o contrato JSON de saída é materializado como arquivo temporário `0600`; nenhum
caminho do repositório é passado ao processo. O ambiente é herdado para preservar
autenticação já configurada; `HOME`/`CODEX_HOME` e arquivos de credenciais ficam
acessíveis à própria CLI quando necessários.

O self-test manual executa primeiro a CLI diretamente e depois pelo
`CommandReasoningProvider`, sem fallback nem acesso à inbox/vault:

```bash
ruby scripts/test-reasoning-provider.rb --provider codex --debug
ruby scripts/test-reasoning-provider.rb --provider claude --debug
```

Cada camada recebe somente uma captura sintética e exige JSON estruturado sem
candidates. Os testes automatizados verificam `cwd`, remoção, metadados de erro
e redaction usando subprocessos Ruby e mocks; não invocam Codex nem Claude.
