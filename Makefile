test:
	nvim --headless -c 'lua require("plenary.test_harness"):test_directory("busted", "./lua/tests/automated/")'
