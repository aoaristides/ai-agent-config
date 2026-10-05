# Política de seleção de modelos

## Contrato

O agente declara somente `model_profile` em `agents/catalog.yml`. Nomes concretos
de modelos pertencem exclusivamente a `adapters/<runtime>/models.yaml`.

O resolver recebe um agente ou perfil e o runtime atual:

```text
agent
  -> model_profile
  -> adapters/<runtime>/models.yaml
  -> modelo concreto
```

## Regras

1. Use o perfil declarado no catálogo; o agente não escolhe fornecedor ou modelo.
2. Resolva o perfil somente no adapter do runtime em execução.
3. Se o modelo primário estiver disponível, use-o.
4. Se estiver indisponível, aplique `models/fallback-policy.md`.
5. Perfil ausente, runtime desconhecido ou lista esgotada são erro explícito.
6. Não use o default silencioso do host para encobrir configuração inválida.
7. Mudanças de nomes concretos ficam nos mappings; mudanças de intenção ficam nos
   perfis. Não replique nenhuma das duas nos contratos `AGENT.md`.
8. Respeite `capabilities.model_selection`: `exact` envia o ID concreto,
   `alias` envia o `host_selector` declarado e `advisory` não autoriza afirmar
   que o modelo foi aplicado pelo host.
9. Não materialize subagente quando `materializable` for `false`; preserve a
   resolução como intenção e declare a limitação do runtime.

## Operação

O comando abaixo resolve o modelo primário de um agente:

```bash
ruby scripts/resolve-model.rb --runtime codex --agent software-engineer
```

Quando o adapter já souber que um modelo não está disponível para a conta ou
execução atual, informe-o ao resolver:

```bash
ruby scripts/resolve-model.rb --runtime codex --agent software-engineer \
  --unavailable gpt-6.1-sol
```

A disponibilidade real continua sendo responsabilidade do runtime. Os mappings
versionados expressam preferência e ordem de fallback, não garantem entitlement,
quota ou presença do modelo numa conta específica.

Em JSON ou YAML, o resolver também retorna:

- `host_selector`: valor que deve ser enviado ao host, quando aplicável;
- `selection_mode`: `exact`, `alias` ou `advisory`;
- `materializable`: se o runtime testado oferece materialização de subagente com
  seleção de modelo.

Em seleção por alias, `model` representa o candidato concreto preferido e
`host_selector` representa o controle realmente aceito pelo host. O alias pode
ser móvel; quando o host expuser o modelo efetivamente executado, registre e
compare esse valor em vez de presumir equivalência permanente.
