.PHONY: test lint docgen clean

DEPS_DIR := deps
TS_DIR := $(DEPS_DIR)/tree-sitter-lua
PLENARY_DIR := $(DEPS_DIR)/plenary.nvim
DEVICONS_DIR := $(DEPS_DIR)/nvim-web-devicions

define git_clone_or_pull
@mkdir -p $(dir $1)
@if [ ! -d "$1" ]; then \
	git clone --depth 1 $2 $1; \
else \
	git -C "$1" pull; \
fi
endef

$(DEPS_DIR):
	@mkdir -p $@

plenary: | $(DEPS_DIR)
	$(call git_clone_or_pull,$(PLENARY_DIR),https://github.com/nvim-lua/plenary.nvim)

docgen-deps: plenary | $(DEPS_DIR)
	@mkdir -p deps
	@if [ ! -d "$(TS_DIR)" ]; then \
		git clone https://github.com/tjdevries/tree-sitter-lua $(TS_DIR); \
	else \
		git -C "$(TS_DIR)" pull; \
	fi
	cd "$(TS_DIR)" && git checkout 86f74dfb69c570f0749b241f8f5489f8f50adbea && make dist

test-deps: plenary | $(DEPS_DIR)
	$(call git_clone_or_pull,$(DEVICONS_DIR),https://github.com/nvim-tree/nvim-web-devicons)

test: plenary
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "PlenaryBustedDirectory lua/tests/automated/ { minimal_init = './scripts/minimal_init.vim' }"

lint:
	luacheck lua/telescope

# pinned tree-sitter-lua commit no longer works on nightly (0.10)
docgen: docgen-deps
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "luafile ./scripts/gendocs.lua" -c 'qa'

clean:
	@rm -rf $(DEPS_DIR)

