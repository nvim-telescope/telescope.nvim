test:
	nvim --headless -c 'PlenaryBustedDirectory lua/tests/automated/'

lint:
	luacheck lua/telescope
