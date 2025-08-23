#!/usr/bin/env bash
set -euo pipefail
shopt -s extglob || true  # needed for pattern trimming with *( )

# build-manifest.sh
# ------------------
# Generate a lightweight machine-readable manifest summarising the repository *without*
# enumerating the heavy contents of the unpacked Power Platform solutions.
#
# Output file: repo-manifest.json with fields:
#   generated  (UTC timestamp)
#   solutions  (array of names from solutions.json, or empty if invalid)
#   workflows  (list of workflow file paths)
#   notes      (flags)
#
# Behaviour notes:
# - Prefers jq for robust parsing. If jq is missing we fall back to a *simple* extraction of
#   quoted strings inside solutions.json; if that basic shape check fails we mark the list empty.
# - Designed to be fast and safe in pre-commit hooks; any failure should surface clearly.

root_dir="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"
cd "$root_dir"

if [[ ! -f solutions.json ]]; then
  echo "solutions.json not found" >&2
  exit 1
fi

timestamp=$(date -u +%FT%TZ)

solutions=()
solutions_json_valid=true

if command -v jq >/dev/null 2>&1; then
  if jq -e 'type == "array" and (all(.[]; type == "string"))' solutions.json >/dev/null 2>&1; then
    # shellcheck disable=SC2207
    solutions=($(jq -r '.[]' solutions.json))
  else
    echo "solutions.json must be a JSON array of strings" >&2
    solutions_json_valid=false
  fi
else
  # Fallback: extract naive quoted strings, then perform a *very* light validation that the
  # file looks like an array (starts with '[' and ends with ']'). This intentionally ignores
  # escape sequences and will treat any quoted token as a candidate solution name.
  if grep -q '^\s*\[' solutions.json && grep -q '\]\s*$' solutions.json; then
    # shellcheck disable=SC2016
    mapfile -t solutions < <(grep -oE '"([^"\\]|\\.)*"' solutions.json | sed -e 's/^"//' -e 's/"$//' ) || true
  else
    solutions_json_valid=false
  fi
  echo "(INFO) jq not found – fallback parser used (entries: ${#solutions[@]})." >&2
fi

# Normalise: trim whitespace, drop empties, dedupe & sort.
cleaned=()
declare -A seen
for s in "${solutions[@]}"; do
  trimmed="${s##*( )}"; trimmed="${trimmed%%*( )}"  # needs extglob; enable if not default
  [[ -z ${trimmed} ]] && continue
  if [[ -z ${seen[$trimmed]+x} ]]; then
    cleaned+=("$trimmed")
    seen[$trimmed]=1
  fi
done
IFS=$'\n' cleaned=($(sort <<<"${cleaned[*]-}" )) || true
unset IFS
solutions=(${cleaned[@]-})

# Gather workflows.
mapfile -t workflows < <(git ls-files '.github/workflows/*.yml' '.github/workflows/*.yaml' 2>/dev/null | sort)

json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//"/\\"}
  printf '%s' "$s"
}

{
  echo '{'
  printf '  "generated": "%s",\n' "${timestamp}"
  if $solutions_json_valid; then
    echo '  "solutions": ['
    if ((${#solutions[@]})); then
      for s in "${solutions[@]}"; do
        printf '    "%s",\n' "$(json_escape "$s")"
      done | sed '$ s/,$//'
    fi
    echo '  ],'
  else
    echo '  "solutions": [],'
  fi
  echo '  "workflows": ['
  if ((${#workflows[@]})); then
    for wf in "${workflows[@]}"; do
      printf '    "%s",\n' "$(json_escape "$wf")"
    done | sed '$ s/,$//'
  fi
  echo '  ],'
  echo '  "notes": {'
  echo '    "solutionsContentExcluded": true'
  echo '  }'
  echo '}'
} > repo-manifest.json

echo "Generated repo-manifest.json (excluded solutions/ contents)."
