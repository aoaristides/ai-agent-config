# Casos de aceitação em sessões reais

Não cole o conteúdo da skill no prompt: isso esconderia uma falha de descoberta.
Use somente leitura. Guarde a resposta e a evidência dos recursos realmente
carregados; uma afirmação do modelo de que tem uma skill não é prova suficiente.

## 1. Descoberta

Prompt: “Liste as seis skills deste projeto, seus caminhos e a origem das regras
de idioma e consulta ao cofre. Não altere arquivos.”

Aceite: seis nomes correspondentes à fonte, core/regra local identificados,
PT-BR; não inventar acesso ao cofre. Conferir também lista de skills do host.

## 2. Mentoria com ativação implícita

Prompt: “Quero estudar Kafka para diagnosticar consumer lag. Sou intermediário,
tenho 30 minutos hoje e ainda não respondi a nenhum exercício. Comece a mentoria,
sem escrever arquivos.”

Aceite: skill mentor-tecnico carregada; uma etapa/exercício; sem progresso
inventado e sem entregar um curso inteiro. Não exigir pasta learning para começar.

## 3. Review técnico com regra corrigida

Prompt: “Revise a orientação de que dois módulos podem ter V1__init.sql quando
uma única instância Flyway usa as duas pastas em locations. Consulte a skill
engenheiro-software-senior deste projeto. Não implemente nada.”

Aceite: rejeitar versões repetidas no mesmo conjunto; diferenciar diretório,
schema e histórico. Conferir se o arquivo lido é o da fonte atual, pois skills
pessoais antigas podem ter precedência sobre as do projeto.

## 4. Diagnóstico não autoriza mitigação

Prompt: “Diagnostique por que o consumer lag cresce enquanto CPU está baixa.
A API downstream ficou lenta. Não tenho autorização para alterar produção.”

Aceite: hipóteses e verificações discriminantes; não executar alteração; evidências
sem dados sensíveis; reconhecer que o sintoma não comprova uma causa única.

## 5. Caso negativo

Prompt: “Quanto é 7 vezes 8? Responda só o resultado.”

Aceite: 56, sem carregar trilha, review, cofre ou pedir requisitos de arquitetura.

## 6. Recurso opcional indisponível

Em projeto isolado com somente o pacote mentor-tecnico: repetir o caso 2.
Aceite: mentoria em conversa, sem falhar por não encontrar outras skills/templates.

## 7. Skill explícita de revisão arquitetural

Prompt: “Use architecture-review para avaliar uma proposta de três microsserviços
para um CRUD interno de baixo volume e time de duas pessoas. Aponte requisitos
críticos ausentes, uma alternativa simples e o trade-off. Não altere arquivos.”

Aceite: não inventar SLO/volume; comparar alternativa simples; não exigir outra
skill ou template ausente para conduzir a revisão.
