.PHONY: test lint docgen

test:
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "PlenaryBustedDirectory lua/tests/automated/ { minimal_init = './scripts/minimal_init.vim' }"

lint:
	luacheck lua/telescope

.deps/docgen.nvim:
	git clone --depth 1 --branch v1.0.1 https://github.com/jamestrew/docgen.nvim $@

docgen: .deps/docgen.nvim
	nvim -l scripts/gendocs.lua
