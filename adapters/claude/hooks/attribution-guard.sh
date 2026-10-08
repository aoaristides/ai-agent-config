#!/usr/bin/env bash
# Bloqueia atribuição ao Claude em commits e PRs (Co-Authored-By, "Generated with Claude Code").
# PreToolUse hook para a tool Bash. Recebe JSON no stdin com o comando proposto.
# Exit 2 = bloqueia a execução e devolve a mensagem (stderr) ao Claude.
# Complementa "attribution" do settings.json: aquela chave só impede o harness de pedir o
# trailer; não impede o modelo de copiá-lo do histórico do repositório (git log).
set -euo pipefail

input="$(cat)"
# Extrai o comando do payload JSON sem depender de jq (fallback com grep/sed).
if command -v jq >/dev/null 2>&1; then
  cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
else
  cmd="$(printf '%s' "$input" | grep -o '"command"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*:[[:space:]]*"//;s/"$//')"
fi

[ -z "${cmd:-}" ] && exit 0

block() {
  echo "🚫 BLOQUEADO pelo hook (attribution-guard): $1" >&2
  echo "Regra do núcleo compartilhado (context/agent-core.md): nenhum commit ou PR leva atribuição ao agente de IA, mesmo que o histórico do repositório tenha." >&2
  echo "Refaça o comando sem o trailer Co-Authored-By do Claude e sem a linha 'Generated with Claude Code'." >&2
  exit 2
}

# Só interessa comando que escreve mensagem de commit ou texto de PR; leitura (git log --grep) passa.
writes='\bgit\b.*\b(commit|merge|tag|notes|revert|cherry-pick)\b|\b(gh|glab)\b.*\b(pr|mr|issue|release)\b.*\b(create|edit|comment|merge|review|update)\b|\bcurl\b.*pull-?requests'
echo "$cmd" | grep -Eiq "$writes" || exit 0

echo "$cmd" | grep -Eiq 'co-authored-by:.*(claude|anthropic)' && block "trailer Co-Authored-By do Claude"
echo "$cmd" | grep -Eiq 'noreply@anthropic\.com' && block "e-mail de atribuição da Anthropic"
echo "$cmd" | grep -Eiq 'generated with[[:space:]]*\[?claude code' && block "linha 'Generated with Claude Code'"

exit 0
