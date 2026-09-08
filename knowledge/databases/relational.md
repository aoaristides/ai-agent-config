# Bancos relacionais

Use o modelo relacional quando integridade, joins e transações forem centrais.

## Checklist

- constraints protegem invariantes persistentes;
- índices seguem queries e cardinalidade medidas;
- transações são curtas e sem I/O externo;
- migrations são versionadas e compatíveis com rollout;
- paginação evita offsets caros em grandes volumes;
- backup só conta quando restore foi testado.

Observe locks, conexões, queries lentas e crescimento.
