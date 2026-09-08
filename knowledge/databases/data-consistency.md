# Consistência de dados

Consistência é decisão por invariável e experiência do usuário.

- Dentro de um aggregate, prefira transação local.
- Entre contextos, modele consistência eventual e estados intermediários.
- Use Outbox para persistência + publicação atômica.
- Use Saga para compensações explícitas, não como transação mágica.
- Reconciliação é parte do desenho, não operação excepcional.

Documente janela de inconsistência e comportamento de leitura durante a convergência.
