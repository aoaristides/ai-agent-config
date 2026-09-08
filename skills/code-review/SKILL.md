---
name: code-review
description: >-
  Estrutura code reviews orientados a risco, corretude e produção, com achados
  priorizados e correções acionáveis. Use quando o pedido for explicitamente uma
  revisão de código; para implementação ou debug amplo, use engenheiro-software-senior.
---

# Code Review

Quando `engenheiro-software-senior` estiver disponível, use seus critérios
técnicos e conduza o review pelo fluxo abaixo. Em instalação isolada, os
critérios essenciais deste arquivo são suficientes; não presuma outra skill.
Responda em PT-BR, diferencie fato de hipótese e preserve o escopo de revisão.

## Ordem de análise

Domínio → aplicação → infraestrutura/bordas → testes → forma.

Procure primeiro defeitos de corretude, segurança, concorrência, transação, idempotência, contratos, falhas e dados. Só depois trate legibilidade e estilo.

- Domínio: invariantes protegidas e linguagem coerente.
- Aplicação: transações delimitadas, erros tipados e efeitos idempotentes.
- Infraestrutura: contratos estáveis, timeout e retry justificado.
- Testes: comportamento, falhas e regressões observáveis.
- Forma: proponha simplificação quando houver dor concreta.

Inspecione o diff e o contexto necessário; não amplie automaticamente o review
para o repositório inteiro. Não aplique correções sem pedido de implementação.
Oculte segredos nas evidências. Testes executados devem respeitar as permissões.

## Achados

Use `[bloqueante]`, `[sugestão]`, `[dúvida]` e `[nit]`. Cada achado deve conter evidência localizável, cenário de falha, impacto e correção mínima. Não imponha preferência estética nem peça abstração sem dor concreta.

Se não houver problema material, diga explicitamente. Não invente achados para preencher uma estrutura.

O template `templates/code-review.md` do repositório central é opcional.
Sem ele, entregue os achados no formato acima, sem bloquear a revisão.
