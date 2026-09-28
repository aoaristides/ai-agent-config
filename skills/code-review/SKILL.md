---
name: code-review
description: >-
  Estrutura code reviews orientados a risco, corretude e produção, com achados
  priorizados e correções acionáveis. Use quando o pedido for explicitamente uma
  revisão de código; quando engenheiro-software-senior estiver disponível,
  componha as duas skills. Para implementação ou debug amplo, a engenharia conduz.
---

# Code Review

Antes de iniciar a análise, quando `engenheiro-software-senior` estiver
disponível, carregue e leia seu `SKILL.md`. Essa composição é obrigatória:
`code-review` conduz o workflow e a taxonomia; `engenheiro-software-senior`
fornece os critérios técnicos. Consultar o cofre ou conhecer critérios
equivalentes não substitui o carregamento da skill. Em instalação isolada, os
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

## Fixtures e valores sensíveis

- Quando o pedido ou a evidência identificar explicitamente um literal como
  fixture, exemplo ou valor falso, não o apresente como credencial real ou
  comprometida sem evidência contrária.
- Separe o dado observado do risco condicional: o valor fictício não exige
  rotação, mas o mesmo padrão com um segredo real pode expô-lo no repositório ou
  no artefato. Continue mascarando o literal ao citá-lo.
- Não classifique como `[bloqueante]`, incidente ou vulnerabilidade crítica apenas
  pela presença da fixture. Baseie a severidade no escopo real do arquivo, no uso
  do valor e em evidência de que produção aceita ou distribui uma credencial.
- Na dúvida sobre a natureza do valor, use `[dúvida]` e peça confirmação; não
  converta incerteza em afirmação de vazamento ou recomendação de rotação.

## Achados

Use `[bloqueante]`, `[sugestão]`, `[dúvida]` e `[nit]`. Cada achado deve conter evidência localizável, cenário de falha, impacto e correção mínima. Não imponha preferência estética nem peça abstração sem dor concreta.

Se não houver problema material, diga explicitamente. Não invente achados para preencher uma estrutura.

O template `templates/code-review.md` do repositório central é opcional.
Sem ele, entregue os achados no formato acima, sem bloquear a revisão.
