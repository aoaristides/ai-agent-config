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

assert_safe_path() {
  local path="$1"
  local label="$2"

  ruby - "${ROOT_DIR}" "${path}" "${label}" <<'RUBY'
# encoding: UTF-8
root = File.realpath(ARGV.fetch(0))
path = File.expand_path(ARGV.fetch(1))
label = ARGV.fetch(2)

resolved_path = if File.exist?(path) || File.symlink?(path)
                  File.realpath(path)
                else
                  File.join(File.realpath(File.dirname(path)), File.basename(path))
                end

unless resolved_path == root || resolved_path.start_with?(root + File::SEPARATOR)
  warn "#{label} fora da raiz do repositório: #{path}"
  exit 1
end

current = path
loop do
  if File.symlink?(current)
    warn "#{label} contém symlink não permitido: #{current}"
    exit 1
  end
  begin
    break if File.realpath(current) == root
  rescue Errno::ENOENT
    # O caminho pode ainda não existir; continue até um ancestral existente.
  end

  parent = File.dirname(current)
  if parent == current
    warn "#{label} possui ancestral inválido: #{current}"
    exit 1
  end
  current = parent
end
RUBY
}

assert_safe_path "${SKILLS_DIR}" "fonte de skills" \
  || fail "Fonte de skills não confinada ao repositório."
assert_safe_path "${DIST_DIR}" "destino de pacotes" \
  || fail "Destino de pacotes não confinado ao repositório."
mkdir -p "${DIST_DIR}"
assert_safe_path "${DIST_DIR}" "destino de pacotes" \
  || fail "Destino de pacotes não confinado após criação."

validate_skill() {
  local skill_file="$1"

  ruby - "${skill_file}" <<'RUBY'
# encoding: UTF-8
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

reject_symlinks() {
  local skill_dir="$1"
  local symlink_path

  symlink_path="$(find "${skill_dir}" -type l -print -quit)"
  [[ -z "${symlink_path}" ]] \
    || fail "Skill '$(basename "${skill_dir}")' contém symlink não permitido: ${symlink_path}"
}

reject_sensitive_files() {
  local skill_dir="$1"
  local sensitive_path

  sensitive_path="$(find "${skill_dir}" -type f \
    \( -name '.env' -o -name '.env.*' -o -name '.npmrc' -o -name '.pypirc' \
       -o -name '*.pem' -o -name '*.key' -o -name '*.p12' -o -name '*.pfx' \) \
    -print -quit)"
  [[ -z "${sensitive_path}" ]] \
    || fail "Skill '$(basename "${skill_dir}")' contém arquivo potencialmente sensível: ${sensitive_path}"
}

package_skill() {
  local skill_dir="$1"
  local skill_name
  local skill_file
  local output_file

  skill_name="$(basename "${skill_dir}")"
  skill_file="${skill_dir}/SKILL.md"
  output_file="${DIST_DIR}/${skill_name}.zip"

  assert_safe_path "${skill_dir}" "diretório da skill ${skill_name}" \
    || fail "Diretório da skill '${skill_name}' não confinado."
  [[ ! -L "${skill_dir}" ]] \
    || fail "Diretório da skill '${skill_name}' é symlink."
  [[ ! -L "${skill_file}" ]] \
    || fail "Skill '${skill_name}' possui SKILL.md como symlink."
  [[ -f "${skill_file}" ]] \
    || fail "Skill '${skill_name}' não contém SKILL.md"

  reject_symlinks "${skill_dir}"
  reject_sensitive_files "${skill_dir}"
  assert_safe_path "${output_file}" "ZIP da skill ${skill_name}" \
    || fail "Saída da skill '${skill_name}' não confinada."
  [[ ! -L "${output_file}" && ! -d "${output_file}" ]] \
    || fail "Saída da skill '${skill_name}' é symlink ou diretório: ${output_file}"

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

quarantine_orphan_zips() {
  local current_names=("$@")
  local zip_path
  local zip_name
  local current_name
  local is_current
  local quarantine_dir=""
  local archives=()

  shopt -s nullglob
  archives=("${DIST_DIR}"/*.zip)
  shopt -u nullglob

  for zip_path in "${archives[@]}"; do
    [[ ! -L "${zip_path}" && -f "${zip_path}" ]] \
      || fail "ZIP órfão é symlink ou não é arquivo regular: ${zip_path}"
    zip_name="$(basename "${zip_path}" .zip)"
    is_current=false
    for current_name in "${current_names[@]}"; do
      if [[ "${zip_name}" == "${current_name}" ]]; then
        is_current=true
        break
      fi
    done
    [[ "${is_current}" == true ]] && continue

    if [[ -z "${quarantine_dir}" ]]; then
      assert_safe_path "${DIST_DIR}/.stale" "quarentena de pacotes" \
        || fail "Quarentena de pacotes não confinada."
      mkdir -p "${DIST_DIR}/.stale"
      assert_safe_path "${DIST_DIR}/.stale" "quarentena de pacotes" \
        || fail "Quarentena de pacotes não confinada após criação."
      quarantine_dir="$(mktemp -d "${DIST_DIR}/.stale/run.XXXXXX")"
      assert_safe_path "${quarantine_dir}" "execução da quarentena" \
        || fail "Execução da quarentena não confinada."
    fi
    mv "${zip_path}" "${quarantine_dir}/"
    log "ZIP órfão movido para quarentena: ${quarantine_dir}/$(basename "${zip_path}")"
  done
}

main() {
  local count=0
  local skill_names=()

  log "Fonte: ${SKILLS_DIR}"
  log "Destino: ${DIST_DIR}"

  while IFS= read -r -d '' skill_entry; do
    [[ ! -L "${skill_entry}" ]] \
      || fail "Entrada em skills é symlink não permitido: ${skill_entry}"
    [[ -d "${skill_entry}" ]] || continue

    package_skill "${skill_entry}"
    skill_names+=("$(basename "${skill_entry}")")
    count=$((count + 1))
  done < <(
    find "${SKILLS_DIR}" \
      -mindepth 1 \
      -maxdepth 1 \
      -print0 |
      sort -z
  )

  if [[ "${count}" -eq 0 ]]; then
    fail "Nenhuma skill contendo SKILL.md foi encontrada em ${SKILLS_DIR}"
  fi

  quarantine_orphan_zips "${skill_names[@]}"

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
