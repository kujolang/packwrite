# PackWrite developer tasks.
#
# Point KUJO at your Kujo interpreter (or have `kujo` on PATH):
#   make test KUJO=/path/to/kujo/target/release/kujo

KUJO ?= kujo
KUJO_FILES := packwrite.kujo $(wildcard src/*.kujo) $(wildcard tests/*.kujo)

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: check
check: ## Run `kujo check` on every .kujo file
	@for f in $(KUJO_FILES); do \
		$(KUJO) check $$f || exit 1; \
	done
	@echo "kujo check: all files passed"

.PHONY: test
test: check ## Lint, then run the full test suite (unit + CLI integration, offline)
	@KUJO="$(KUJO)" ./tests/run.sh

.PHONY: unit
unit: ## Run only the offline unit assertions
	@$(KUJO) run tests/packwrite_test.kujo

.PHONY: integration
integration: ## Run only the CLI integration tests
	@KUJO="$(KUJO)" ./tests/cli_integration.sh

.PHONY: smoke
smoke: ## Quick sanity check: print help and version
	@KUJO="$(KUJO)" ./bin/packwrite version
	@KUJO="$(KUJO)" ./bin/packwrite help >/dev/null && echo "help: ok"

.PHONY: install
install: ## Symlink bin/packwrite into PREFIX/bin (default /usr/local/bin)
	@PREFIX=$${PREFIX:-/usr/local}; \
	ln -sf "$(CURDIR)/bin/packwrite" "$$PREFIX/bin/packwrite"; \
	echo "linked $$PREFIX/bin/packwrite -> $(CURDIR)/bin/packwrite"; \
	echo "remember to export KUJO=/path/to/kujo in your shell profile"
