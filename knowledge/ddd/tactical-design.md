# DDD — design tático

- Entity possui identidade e ciclo de vida.
- Value Object é definido por valor e tende a ser imutável.
- Aggregate protege invariantes dentro de uma fronteira transacional.
- Repository abstrai persistência de aggregates, não consultas arbitrárias.
- Domain Service abriga regra que não pertence naturalmente a uma entidade.

Não force DDD tático em CRUD trivial; proteja invariantes no domínio, não em services externos.
