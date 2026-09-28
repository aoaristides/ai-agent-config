# Context Pack: SAP Commerce / Hybris

## Carregar quando

A tarefa envolver SAP Commerce, Hybris, coexistência, migração ou anti-corruption
layer entre o legado e uma plataforma nova.

## Perguntas obrigatórias

- Qual versão, extensão e modelo de dados estão realmente em uso?
- Qual sistema é fonte de verdade durante a transição?
- Quais contratos e identificadores precisam de tradução?
- Há escrita dupla, reconciliação e rollback definidos?
- O problema exige extração ou pode ser resolvido por modularização?

## Guardrail

Não deixe o modelo legado ditar automaticamente o domínio novo. Não proponha
big-bang rewrite nem dual-write sem reconciliação observável.
