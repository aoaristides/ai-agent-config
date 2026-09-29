# Kernel de composição de contexto

Carregue este arquivo como entrada mínima. Ele não substitui as regras do host
nem duplica o núcleo compartilhado.

## Ordem de precedência

1. pedido atual do usuário e políticas do host;
2. regras do projeto consumidor;
3. `context/agent-core.md`, na raiz local indicada pelo adaptador;
4. módulos selecionados por `context-index.md` nessa mesma raiz.

## Protocolo mínimo

- Leia `context/agent-core.md` uma vez por sessão relevante.
- Classifique a tarefa pelo índice antes de carregar contexto adicional.
- Carregue uma role, um workflow e somente os packs/projetos necessários.
- Não carregue `knowledge/`, `projects/` ou o cofre inteiro por padrão.
- Prefira links e resumos; a fonte detalhada continua no arquivo de origem.
- Se dois módulos divergirem, exponha a divergência e use a fonte canônica.
- Ao terminar, registre somente conhecimento durável no destino autorizado.

## Modos de contexto

`economical` é o padrão: use kernel, índice, uma role, um workflow e inicialmente
um único módulo adicional de projeto ou context pack. Expanda somente quando uma
lacuna concreta impedir a tarefa.

`deep` só é ativado por pedido explícito de análise ampla, modo profundo ou por
risco que exija investigação adicional. Mesmo nesse modo, carregue referências
por tema; nunca a biblioteca inteira.

## Limite sugerido

[suposição] Comece com kernel + índice + até três módulos: role, workflow e um
módulo adicional. Expanda apenas quando
uma lacuna concreta impedir a tarefa; quantidade de arquivos não mede qualidade.
