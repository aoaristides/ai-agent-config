# Padrões de cloud

- Managed service reduz operação, mas aumenta dependência do fornecedor.
- Multi-AZ melhora disponibilidade regional, não substitui backup.
- Multi-region só se justifica por RTO/RPO e impacto comprovados.
- Queue-based load leveling suaviza picos, introduz atraso e consistência eventual.
- Bulkhead reduz blast radius, aumenta capacidade reservada.

Toda recomendação deve incluir custo recorrente, skill operacional e estratégia de saída proporcional ao risco.
