DEPDIR ?= .deps
DOCGEN := $(DEPDIR)/docgen.nvim
DOCGEN_TAG := v1.1.0

NVIM ?= nvim
TEST_FILE ?= tests/automated
# TODO: v0.13.0 once released
NVIM_TEST_VERSION := nightly
TEST_DEPS := $(DEPDIR)/neovim/$(NVIM_TEST_VERSION)
TEST_URL := https://raw.githubusercontent.com/neovim/neovim/$(NVIM_TEST_VERSION)/test

$(TEST_DEPS):
	rm -rf "$@.tmp"
	mkdir -p "$@.tmp/test"
	curl --fail --location --silent --show-error --parallel --remote-name-all --output-dir "$@.tmp/test" \
		$(addprefix $(TEST_URL)/,harness.lua assert.lua reporter.lua)
	mv "$@.tmp" "$@"

.PHONY: test lint docgen
test: $(TEST_DEPS)
	NVIM_LOG_FILE="$(abspath $(DEPDIR)/nvim.log)" "$(NVIM)" --clean \
		-l tests/runner.lua "$(TEST_DEPS)" "$(TEST_FILE)"

lint:
	luacheck lua/telescope

.PHONY: docgen
docgen: $(DOCGEN)

$(DOCGEN):
	git clone --filter=blob:none --branch $(DOCGEN_TAG) https://github.com/jamestrew/docgen.nvim $(DOCGEN)

.PHONY: docs
docs: $(DOCGEN)
	nvim -l scripts/gendocs.lua

.PHONY: clean
clean:
	rm -rf $(DEPDIR)
