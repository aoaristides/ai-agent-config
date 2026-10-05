# Política de fallback de modelos

## Gatilhos permitidos

Use fallback somente quando o runtime informar indisponibilidade concreta, como
modelo não reconhecido, falta de acesso, retirada, quota específica esgotada ou
falha equivalente de seleção. Erro de prompt, ferramenta, permissão ou qualidade
da resposta não autoriza trocar de modelo silenciosamente.

## Ordem

1. Tente `primary` do perfil no mapping do runtime.
2. Percorra `fallbacks` na ordem declarada.
3. Pare no primeiro modelo que o runtime considere disponível.
4. Se nenhum candidato restar, falhe de forma explícita e preserve o erro.

## Invariantes

- Não atravesse para outro runtime ou fornecedor implicitamente.
- Não altere o `model_profile` do agente durante o fallback.
- Não repita um modelo entre `primary` e `fallbacks`.
- Não substitua falha de autenticação, permissão ou configuração por downgrade.
- Registre o modelo resolvido e se houve fallback quando o host oferecer
  observabilidade para isso.
- Em runtime `advisory`, fallback significa somente nova resolução; não comprova
  que o host executou o modelo retornado.
- Em runtime `alias`, envie o `host_selector` e confirme o modelo efetivo quando
  o host fornecer transcript ou metadata confiável.

## Manutenção

Revise mappings quando um runtime adicionar, renomear, depreciar ou retirar um
modelo. Faça a troca concreta no adapter e preserve o perfil abstrato, salvo se a
intenção da função também tiver mudado.
