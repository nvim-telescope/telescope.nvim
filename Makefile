.PHONY: test lint docgen clean

DEPS_DIR := deps
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

test-deps: plenary | $(DEPS_DIR)
	$(call git_clone_or_pull,$(DEVICONS_DIR),https://github.com/nvim-tree/nvim-web-devicons)

test: plenary
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "PlenaryBustedDirectory lua/tests/automated/ { minimal_init = './scripts/minimal_init.vim' }"

lint:
	luacheck lua/telescope

# pinned tree-sitter-lua commit no longer works on nightly (0.10)
docgen:
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "luafile ./scripts/gendocs.lua" -c 'qa'

clean:
	@rm -rf $(DEPS_DIR)

