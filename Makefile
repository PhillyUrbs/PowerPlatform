# Convenience developer targets
# Use with: make <target>
# Requires: bash, git (and optional: jq, ctags)

.PHONY: help manifest reindex clean-index

help:
	@echo "Available targets:" \
	 && echo "  manifest    - Rebuild repo-manifest.json" \
	 && echo "  reindex     - Rebuild file index, tags, and manifest" \
	 && echo "  clean-index - Remove generated index artifacts" \
	 && echo "  help        - Show this help"

manifest:
	bash scripts/build-manifest.sh

reindex:
	bash scripts/reindex.sh

clean-index:
	rm -f .file-index .tags repo-manifest.json
	@echo "Removed generated index artifacts."
