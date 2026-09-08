# Kubernetes — práticas de produção

- imagens imutáveis e execução sem privilégio;
- requests calibrados e limits conscientes;
- probes baratas e semanticamente corretas;
- rollout gradual com rollback testado;
- autoscaling baseado no gargalo real;
- disruption budget compatível com manutenção;
- secrets fora de manifests versionados;
- políticas de rede e acesso mínimo.

Valide sob falha de node, drain e indisponibilidade de dependência.
