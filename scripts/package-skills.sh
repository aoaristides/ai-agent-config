#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="${ROOT_DIR}/skills"
DIST_DIR="${ROOT_DIR}/dist"

log() {
  printf '[package-skills] %s\n' "$*"
}

fail() {
  printf '[package-skills] ERRO: %s\n' "$*" >&2
  exit 1
}

command -v ruby >/dev/null 2>&1 \
  || fail "Ruby não encontrado. Ele é necessário para validar o frontmatter YAML."

command -v zip >/dev/null 2>&1 \
  || fail "Comando 'zip' não encontrado."

[[ -d "${SKILLS_DIR}" ]] \
  || fail "Diretório de skills não encontrado: ${SKILLS_DIR}"

mkdir -p "${DIST_DIR}"

validate_skill() {
  local skill_file="$1"

  ruby - "${skill_file}" <<'RUBY'
require "yaml"

file = ARGV.fetch(0)
content = File.read(file, encoding: "UTF-8")

match = content.match(/\A---[ \t]*\r?\n(.*?)\r?\n---[ \t]*\r?\n/m)

unless match
  warn "#{file}: frontmatter YAML não encontrado ou inválido"
  exit 1
end

begin
  metadata = YAML.safe_load(
    match[1],
    permitted_classes: [],
    permitted_symbols: [],
    aliases: false
  )
rescue Psych::SyntaxError => e
  warn "#{file}: YAML inválido: #{e.message}"
  exit 1
end

unless metadata.is_a?(Hash)
  warn "#{file}: frontmatter precisa ser um mapping YAML"
  exit 1
end

name = metadata["name"]
description = metadata["description"]

if name.nil? || name.to_s.strip.empty?
  warn "#{file}: campo obrigatório 'name' ausente"
  exit 1
end

if description.nil? || description.to_s.strip.empty?
  warn "#{file}: campo obrigatório 'description' ausente"
  exit 1
end

puts "OK: #{file} (#{name})"
RUBY
}

package_skill() {
  local skill_dir="$1"
  local skill_name
  local skill_file
  local output_file

  skill_name="$(basename "${skill_dir}")"
  skill_file="${skill_dir}/SKILL.md"
  output_file="${DIST_DIR}/${skill_name}.zip"

  [[ -f "${skill_file}" ]] \
    || fail "Skill '${skill_name}' não contém SKILL.md"

  log "Validando ${skill_name}..."
  validate_skill "${skill_file}"

  log "Empacotando ${skill_name}..."

  rm -f "${output_file}"

  (
    cd "${SKILLS_DIR}"

    zip -q -r "${output_file}" "${skill_name}" \
      -x "*/.DS_Store" \
      -x "*/__MACOSX/*" \
      -x "*/.git/*" \
      -x "*/.idea/*" \
      -x "*/.vscode/*" \
      -x "*/node_modules/*" \
      -x "*.tmp" \
      -x "*.bak" \
      -x "*.swp"
  )

  log "Gerado: ${output_file}"
}

main() {
  local count=0

  log "Fonte: ${SKILLS_DIR}"
  log "Destino: ${DIST_DIR}"

  while IFS= read -r -d '' skill_file; do
    package_skill "$(dirname "${skill_file}")"
    count=$((count + 1))
  done < <(
    find "${SKILLS_DIR}" \
      -mindepth 2 \
      -maxdepth 2 \
      -type f \
      -name "SKILL.md" \
      -print0 |
      sort -z
  )

  if [[ "${count}" -eq 0 ]]; then
    fail "Nenhuma skill contendo SKILL.md foi encontrada em ${SKILLS_DIR}"
  fi

  printf '\n'
  log "${count} skill(s) empacotada(s) com sucesso."

  printf '\nArtefatos:\n'
  find "${DIST_DIR}" \
    -maxdepth 1 \
    -type f \
    -name "*.zip" \
    -print |
    sort |
    sed 's/^/  - /'
}

main "$@"