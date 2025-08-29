#!/usr/bin/env bash
set -euo pipefail
#
# Usage: scripts/reindex.sh
# Purpose: Regenerate lightweight developer indexes excluding heavy solution payloads.
# Outputs (overwrites):
#   .file-index         — tracked file list minus solutions/
#   .tags               — ctags symbols (if ctags installed)
#   repo-manifest.json  — via build-manifest.sh
# Safe to run locally; may stage repo-manifest.json if changed.
# Exit codes: 0 success; non-fatal steps (ctags or manifest errors) are downgraded with warnings.
shopt -s extglob || true  # for pattern-based trimming used by build-manifest fallback

# Regenerate lightweight indexes excluding the large/unnecessary solution file contents.
# Outputs:
#  - .file-index (tracked file list excluding solutions/)
#  - .tags (ctags symbol index excluding solutions/)
#  - repo-manifest.json (summary metadata)

root_dir="$(cd "${BASH_SOURCE[0]%/*}/.." && pwd)"
cd "$root_dir"

echo "Creating .file-index (excluding solutions/)..." >&2
git ls-files | grep -v '^solutions/' > .file-index

echo "Building ctags index (excluding solutions/)..." >&2
if command -v ctags >/dev/null 2>&1; then
  ctags -R -f .tags \
    --exclude=solutions \
    --exclude=.git \
    --languages=YAML,XML \
    --options=.ctags.d/xml.cnf \
    . || true
else
  echo "ctags not installed; skipping .tags generation" >&2
fi

echo "Building manifest..." >&2
"$root_dir/scripts/build-manifest.sh" || echo "(WARNING) build-manifest encountered an error but continuing." >&2
if ! git diff --quiet -- repo-manifest.json 2>/dev/null; then
  echo "Staging updated repo-manifest.json" >&2
  git add repo-manifest.json || true
fi

echo "Reindex complete." >&2
