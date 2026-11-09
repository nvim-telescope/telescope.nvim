DEPDIR ?= .deps
DOCGEN := $(DEPDIR)/docgen.nvim
DOCGEN_TAG := v1.1.0

NVIM ?= nvim
TEST_FILE ?= tests/automated
NVIM_TEST_VERSION := v0.12.6
TEST_DEPS := $(DEPDIR)/neovim/$(NVIM_TEST_VERSION)
TEST_MODULES := $(addprefix $(TEST_DEPS)/test/,harness.lua assert.lua reporter.lua)

$(TEST_MODULES):
	mkdir -p "$(@D)"
	curl --fail --location --silent --show-error --output "$@.tmp" \
		https://raw.githubusercontent.com/neovim/neovim/$(NVIM_TEST_VERSION)/test/$(notdir $@)
	mv "$@.tmp" "$@"

.PHONY: test lint docgen
test: $(TEST_MODULES)
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
