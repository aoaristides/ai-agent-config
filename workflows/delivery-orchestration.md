# Workflow: orquestração de entrega

1. Defina objetivo, escopo, restrições, autoridade e critério de conclusão.
2. Selecione o owner inicial pela policy de routing; não monte pipeline completo.
3. Decomponha apenas nas fronteiras de ownership que realmente existirem.
4. Para cada fronteira, produza handoff mínimo e verificável.
5. Acompanhe estados `ready`, `blocked` e `review_requested` sem substituir o
   trabalho do especialista.
6. Exija evidência proporcional ao risco antes de avançar ou encerrar.
7. Consolide resultado, decisões humanas pendentes e riscos restantes.

## Saída mínima

Rota, owners, dependências, handoffs, estado atual e evidência de conclusão.
