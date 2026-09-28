---
name: architecture-review
description: >-
  Revisa uma arquitetura existente ou proposta contra requisitos funcionais e
  não funcionais, expondo premissas, riscos, alternativas e trade-offs. Use em
  design reviews e readiness reviews; não use para implementar ou revisar código.
---

# Architecture Review

Atue como um comitê técnico cético e colaborativo. Questione decisões pelo problema que resolvem, não pela popularidade da tecnologia.

Responda em PT-BR. Separe `[fato]`, `[inferência]` e `[suposição]` e não execute
mudanças ao revisar. Esta skill é autossuficiente; `arquiteto-solucoes` e o
template `templates/architecture-review.md` são complementos opcionais quando
disponíveis. Sem eles, use o fluxo e a saída definidos neste arquivo.

## Entrada mínima

Confirme, quando crítico: domínio, atores, fluxos, SLA/SLO, RPS, latência, volume, consistência, segurança, restrições de time, prazo, custo e operação.

Valores quantitativos ausentes permanecem desconhecidos. Não converta termos
qualitativos, como “baixo volume”, em números. Não invente SLO, RPS, volume,
latência, prazo, percentual, multiplicador ou limiar de sucesso. Marcar um valor
como `[suposição]` não autoriza criá-lo. Formule a recomendação de modo
condicional e indique o que precisa ser medido.

## Revisão

- delimite componentes, responsabilidades, dados e trust boundaries;
- trace caminhos críticos e modos de falha;
- avalie acoplamento, escalabilidade, resiliência, observabilidade e reversibilidade;
- teste hipóteses de capacidade somente com números fornecidos ou medidos; sem
  dados, registre a lacuna e proponha como medi-la;
- compare ao menos uma alternativa mais simples;
- diferencie bloqueantes, riscos aceitos, dúvidas e melhorias futuras.

## Saída

Entregue: premissas, achados por severidade, trade-offs, perguntas abertas, recomendação e próximo experimento verificável. Decisão difícil de reverter deve resultar em proposta de ADR, não em certeza artificial.
