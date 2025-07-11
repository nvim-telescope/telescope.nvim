.PHONY: test lint docgen

test:
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "PlenaryBustedDirectory lua/tests/automated/ { minimal_init = './scripts/minimal_init.vim' }"

lint:
	luacheck lua/telescope

docgen:
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "luafile ./scripts/gendocs.lua" -c 'qa'

test-utils:
	nvim --headless --noplugin -u scripts/minimal_init.vim -c "lua require('plenary.busted').run('lua/tests/automated/actions/utils_spec.lua', { minimal_init = './scripts/minimal_init.vim' })" -c "qa"
