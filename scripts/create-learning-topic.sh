#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LEARNING_DIR="${ROOT_DIR}/learning"

fail() {
  printf '[create-learning-topic] ERRO: %s\n' "$*" >&2
  exit 1
}

[[ "$#" -eq 1 ]] || fail "Uso: $0 <tema-em-kebab-case>"

topic="$1"
[[ "${topic}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] \
  || fail "Tema inválido. Use kebab-case com letras minúsculas, números e hífens."

topic_dir="${LEARNING_DIR}/${topic}"
[[ ! -e "${topic_dir}" && ! -L "${topic_dir}" ]] \
  || fail "O tópico já existe e não será sobrescrito: ${topic_dir}"

mkdir -p "${LEARNING_DIR}"
mkdir "${topic_dir}" || fail "Não foi possível reservar o tópico; ele pode ter sido criado por outra sessão."
# Uma falha preserva os arquivos parciais para recuperação manual.
trap 'printf "[create-learning-topic] Escrita interrompida; revise o tópico parcial: %s\n" "${topic_dir}" >&2' ERR

printf '# Contexto de aprendizado — %s\n\n## Objetivo\n\n## Contexto de aplicação\n\n## Nível atual\n\n## Tempo disponível\n\n## Critério de sucesso\n' "${topic}" > "${topic_dir}/context.md"
printf '# Roadmap — %s\n\n1. Fundamentos.\n2. Aplicação prática.\n3. Produção e falhas.\n4. Tópicos avançados.\n5. Projeto final.\n' "${topic}" > "${topic_dir}/roadmap.md"
printf '# Progresso — %s\n\n## Estado atual\n\n- Etapa: diagnóstico.\n- Última sessão: ainda não registrada.\n\n## Evidências de domínio\n\n## Lacunas\n\n## Próximo passo\n' "${topic}" > "${topic_dir}/progress.md"
printf '# Notas — %s\n\n## AAAA-MM-DD — Tema\n\n- Modelo mental:\n- Evidência/exemplo:\n- Dúvida aberta:\n- Aplicação em produção:\n' "${topic}" > "${topic_dir}/notes.md"
printf '# Exercícios — %s\n\n## Exercício 1\n\n### Cenário\n\n### Resposta\n\n### Feedback\n\n### Nova tentativa\n' "${topic}" > "${topic_dir}/exercises.md"

printf '[create-learning-topic] Criado: %s\n' "${topic_dir}"
