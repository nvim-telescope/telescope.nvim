local helper = require "telescope.testharness.helpers"
local runner = require "telescope.testharness.runner"

-- Change the working directory to the path with tilde in it
vim.api.nvim_set_current_dir("lua/tests/fixtures/oldfiles~escape~tilde")

-- Open oldfiles-escape-tile.md to that is gets saved in history
vim.api.nvim_command(":e oldfiles-escape-tilde.md")

-- Create and naviagete to a temp buffer so that the previously opened oldfiles-escape-tile.md is
-- visible in the picker
vim.api.nvim_command(":enew")

-- Attempt to find the file in the
runner.picker("oldfiles", "oldfiles-escape-tilde.md", {
  post_typed = {
    { '>  oldfiles-escape-tilde.md', helper.get_best_result },
  },
}, {
	only_cwd=true
})
