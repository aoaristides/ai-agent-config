# Logging

Logs explicam eventos discretos; não substituem métricas nem traces.

## Práticas

- estrutura consistente e campos pesquisáveis;
- timestamp, nível, serviço, ambiente e correlation/trace ID;
- contexto de negócio sem PII ou segredo;
- erro com causa e ação, sem duplicação em cada camada;
- amostragem e retenção proporcionais ao valor.

Teste consultas de diagnóstico antes de precisar delas em incidente.
