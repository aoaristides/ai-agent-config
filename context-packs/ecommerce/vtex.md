# Context Pack: VTEX

## Carregar quando

A tarefa envolver catálogo, produto/SKU, preço, estoque, checkout, orderForm,
Master Data ou integração de um BFF com VTEX.

## Perguntas obrigatórias

- Qual produto/API VTEX está no fluxo e qual é o contrato observado?
- Site e app acessam VTEX diretamente ou por BFF?
- Qual identificador é canônico: produto, SKU, refId ou id de origem?
- Há cache, rate limit, sessão, coexistência ou migração com legado?
- Qual comportamento foi verificado no ambiente e em qual data?

## Riscos recorrentes

Identidade divergente, cache escondendo read-after-write, cota compartilhada,
credencial ou cookie atravessando fronteira errada e contrato inferido de exemplo.

## Fontes sob demanda

Consulte o projeto identificável e as notas VTEX do cofre. Fatos vivos não devem
ser copiados automaticamente para este pack.
