DEPDIR ?= .deps
DOCGEN := $(DEPDIR)/docgen.nvim
DOCGEN_TAG := v1.1.0

# Nvim under test ("test"), set by the CI matrix
NVIM_VERSION ?= nightly
# Nvim running the test harness ("host")
# TODO: stable once Nvim 0.13 is released
NVIM_HOST_VERSION := nightly
TEST_FILE ?= tests/automated

EMMYLUA_VERSION ?= 0.25.1
CURL ?= curl -sL --create-dirs

ifeq ($(OS),Windows_NT)
    NVIM_ARCH ?= win64
    EXE := .exe
else ifeq ($(shell uname -s),Darwin)
    NVIM_ARCH ?= macos-arm64
    LUALS_ARCH ?= darwin-arm64
else
    NVIM_ARCH ?= linux-x86_64
    LUALS_ARCH ?= linux-x64
endif

# Each version is downloaded once to $(DEPDIR)/nvim-<version>: the release build and the test
# harness modules from the same git ref (cached, "make clean" to update).
NVIM_TEST_FILES := assert.lua harness.lua reporter.lua runner.lua testutil.lua \
	client/rpc_stream.lua client/session.lua client/uv_stream.lua \
	functional/testnvim.lua functional/testnvim/exec_lua.lua
comma := ,
space := $(subst ,, )

NVIM := $(DEPDIR)/nvim-$(NVIM_VERSION)
NVIM_BIN := $(NVIM)/bin/nvim$(EXE)
NVIM_HOST := $(DEPDIR)/nvim-$(NVIM_HOST_VERSION)
NVIM_HOST_BIN := $(NVIM_HOST)/bin/nvim$(EXE)

.PHONY: nvim
nvim: $(NVIM_BIN) $(NVIM_HOST_BIN)

# Downloads to a temp dir, renamed after all downloads succeed.
$(DEPDIR)/nvim-%/bin/nvim$(EXE):
	rm -rf $(DEPDIR)/nvim-$* $(DEPDIR)/nvim-$*.tmp
	mkdir -p $(DEPDIR)/nvim-$*.tmp
ifeq ($(OS),Windows_NT)
	$(CURL) --fail https://github.com/neovim/neovim/releases/download/$*/nvim-$(NVIM_ARCH).zip \
		-o $(DEPDIR)/nvim-$*.zip
	unzip -q $(DEPDIR)/nvim-$*.zip -d $(DEPDIR)/nvim-$*.tmp
	mv $(DEPDIR)/nvim-$*.tmp/nvim-$(NVIM_ARCH)/* $(DEPDIR)/nvim-$*.tmp
	rmdir $(DEPDIR)/nvim-$*.tmp/nvim-$(NVIM_ARCH)
	rm $(DEPDIR)/nvim-$*.zip
else
	$(CURL) --fail https://github.com/neovim/neovim/releases/download/$*/nvim-$(NVIM_ARCH).tar.gz \
		| tar -xz --strip-components=1 -C $(DEPDIR)/nvim-$*.tmp
endif
	$(CURL) --fail --parallel --output "$(DEPDIR)/nvim-$*.tmp/test/#1" \
		"https://raw.githubusercontent.com/neovim/neovim/$*/test/{$(subst $(space),$(comma),$(strip $(NVIM_TEST_FILES)))}"
	mv $(DEPDIR)/nvim-$*.tmp $(DEPDIR)/nvim-$*

.PHONY: test
# The specs run their code in $(NVIM_BIN) (see tests/sut.lua, tests/helper.lua).
test: $(NVIM_BIN) $(NVIM_HOST_BIN)
	NVIM_LOG_FILE="$(DEPDIR)/nvim.log" NVIM_PRG="$(NVIM_BIN)" \
		"$(NVIM_HOST_BIN)" --clean -l "$(NVIM_HOST)/test/runner.lua" --helper=tests/helper.lua $(TEST_FILE)

EMMYLUALS := $(DEPDIR)/emmylua_check-$(LUALS_ARCH)
EMMYLUALS_TARBALL := $(EMMYLUALS).tar.gz
EMMYLUALS_URL := https://github.com/emmyluals/emmylua-analyzer-rust/releases/download/$(EMMYLUA_VERSION)/$(notdir $(EMMYLUALS_TARBALL))

.PHONY: emmyluals
emmyluals: $(EMMYLUALS)

$(EMMYLUALS):
	$(CURL) $(EMMYLUALS_URL) -o $(EMMYLUALS_TARBALL)
	mkdir $@
	tar -xf $(EMMYLUALS_TARBALL) -C $@
	rm -rf $(EMMYLUALS_TARBALL)

.PHONY: lint
lint: $(EMMYLUALS) $(NVIM_BIN)
	VIMRUNTIME="$(NVIM)/share/nvim/runtime" $(EMMYLUALS)/emmylua_check --warnings-as-errors .

.PHONY: docgen
docgen: $(DOCGEN)

$(DOCGEN):
	git clone --filter=blob:none --branch $(DOCGEN_TAG) https://github.com/jamestrew/docgen.nvim $(DOCGEN)

.PHONY: docs
# Generated with the host Nvim (fixed version, so the output doesn't depend on the matrix).
docs: $(DOCGEN) $(NVIM_HOST_BIN)
	VIMRUNTIME="$(NVIM_HOST)/share/nvim/runtime" "$(NVIM_HOST_BIN)" --clean -l scripts/gendocs.lua
	VIMRUNTIME="$(NVIM_HOST)/share/nvim/runtime" "$(NVIM_HOST_BIN)" --clean -l scripts/check_doc_tags.lua

.PHONY: clean
clean:
	rm -rf $(DEPDIR)
