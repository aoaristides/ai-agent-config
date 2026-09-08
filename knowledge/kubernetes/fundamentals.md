# Kubernetes — fundamentos

Kubernetes reconcilia estado desejado; não corrige uma aplicação que desconhece shutdown, limites ou falhas.

## Base

- requests orientam scheduling; limits impõem teto;
- readiness controla tráfego; liveness detecta processo travado;
- configuração não sensível e segredos têm ciclos distintos;
- labels consistentes sustentam seleção, métricas e operação.

Comece com poucos objetos e ownership claro.
