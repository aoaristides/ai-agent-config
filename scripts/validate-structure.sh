#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
command -v ruby >/dev/null 2>&1 || { printf 'Ruby é necessário.\n' >&2; exit 1; }
exec ruby "${ROOT_DIR}/scripts/validate_structure.rb" "${ROOT_DIR}"
