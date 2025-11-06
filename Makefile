NVIM_VERSION ?= nightly

DEPDIR ?= .test-deps
CURL ?= curl -sL --create-dirs

ifeq ($(shell uname -s),Darwin)
    NVIM_ARCH ?= macos-arm64
    LUALS_ARCH ?= darwin-arm64
    STYLUA_ARCH ?= macos-aarch64
else
    NVIM_ARCH ?= linux-x86_64
    LUALS_ARCH ?= linux-x64
    STYLUA_ARCH ?= linux-x86_64
endif

# download test dependencies

NVIM := $(DEPDIR)/nvim-$(NVIM_ARCH)
NVIM_TARBALL := $(NVIM).tar.gz
NVIM_URL := https://github.com/neovim/neovim/releases/download/$(NVIM_VERSION)/$(notdir $(NVIM_TARBALL))
NVIM_BIN := $(NVIM)/nvim-$(NVIM_ARCH)/bin/nvim
NVIM_RUNTIME=$(NVIM)/nvim-$(NVIM_ARCH)/share/nvim/runtime

.PHONY: nvim
nvim: $(NVIM)

$(NVIM):
	$(CURL) $(NVIM_URL) -o $(NVIM_TARBALL)
	mkdir $@
	tar -xf $(NVIM_TARBALL) -C $@
	rm -rf $(NVIM_TARBALL)

EMMYLUALS := $(DEPDIR)/emmylua_check-$(LUALS_ARCH)
EMMYLUALS_TARBALL := $(EMMYLUALS).tar.gz
EMMYLUALS_URL := https://github.com/emmyluals/emmylua-analyzer-rust/releases/latest/download/$(notdir $(EMMYLUALS_TARBALL))

.PHONY: emmyluals
luals: $(EMMYLUALS)

$(EMMYLUALS):
	$(CURL) $(EMMYLUALS_URL) -o $(EMMYLUALS_TARBALL)
	mkdir $@
	tar -xf $(EMMYLUALS_TARBALL) -C $@
	rm -rf $(EMMYLUALS_TARBALL)


STYLUA := $(DEPDIR)/stylua-$(STYLUA_ARCH)
STYLUA_TARBALL := $(STYLUA).zip
STYLUA_URL := https://github.com/JohnnyMorganz/StyLua/releases/latest/download/$(notdir $(STYLUA_TARBALL))

.PHONY: stylua
stylua: $(STYLUA)

$(STYLUA):
	$(CURL) $(STYLUA_URL) -o $(STYLUA_TARBALL)
	unzip $(STYLUA_TARBALL) -d $(STYLUA)
	rm -rf $(STYLUA_TARBALL)

.PHONY: formatlua
formatlua: $(STYLUA)
	$(STYLUA)/stylua .

.PHONY: checklua
checklua: $(EMMYLUALS) $(NVIM)
	VIMRUNTIME=$(NVIM_RUNTIME) $(EMMYLUALS)/emmylua_check --warnings-as-errors .

.PHONY: test
test:
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "PlenaryBustedDirectory lua/tests/automated/ { minimal_init = './scripts/minimal_init.vim' }"

.PHONY: lint
luacheck:
	luacheck lua/telescope

.PHONY: docgen
docgen:
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "luafile ./scripts/gendocs.lua" -c 'qa'

.PHONY: clean
clean:
	rm -rf $(DEPDIR)
