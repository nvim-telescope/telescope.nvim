local helper = require "telescope.testharness.helpers"
local runner = require "telescope.testharness.runner"

-- Save the current directory to restore it, otherwise `telescope.builtin.__internal` wont be found
local previous_cwd = vim.loop.cwd()

-- Change the working directory to the path with tilde in it
vim.api.nvim_set_current_dir "lua/tests/fixtures/oldfiles~escape~tilde"

-- Open oldfiles-escape-tile.md to that is gets saved in history
vim.api.nvim_command ":e oldfiles-escape-tilde.md"

-- Create and naviagete to a temp buffer so that the previously opened oldfiles-escape-tile.md is
-- visible in the picker
vim.api.nvim_command ":enew"

-- Change the working directory back to what it was at the start of the test
vim.api.nvim_set_current_dir(previous_cwd)

-- Attempt to find the file in the
runner.picker("oldfiles", "oldfiles-escape-tilde.md", {
  post_typed = {
    { ">  lua/tests/fixtures/oldfiles~escape~tilde/oldfiles-escape-tilde.md", helper.get_best_result },
  },
}, {
  only_cwd = true,
})
