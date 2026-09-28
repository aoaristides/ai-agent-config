# Context packs

Packs agrupam contexto reutilizável que atravessa tarefas ou projetos. Não são
um depósito geral e não substituem as fontes vivas do cofre.

## Critério de criação

Crie um pack somente quando o mesmo contexto for necessário em mais de um fluxo
ou projeto. Um pack deve responder:

- quando carregar e quando não carregar;
- qual problema e vocabulário cobre;
- quais fatos são estáveis e qual fonte os sustenta;
- quais arquivos detalhados devem ser lidos sob demanda.

## Template mínimo

```markdown
# Pack: <nome>
## Carregar quando
## Não carregar quando
## Vocabulário mínimo
## Invariantes e restrições
## Fontes e módulos relacionados
```

Mantenha o pack curto. Extraia detalhes para arquivos temáticos apenas quando o
índice deixar de ser suficiente.
