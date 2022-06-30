local tester = require "telescope.testharness"
local runner = require "telescope.testharness.runner"
local helper = require "telescope.testharness.helpers"

runner.picker("find_files", "plugin<c-n>", {
  post_close = {
    tester.not_ { "telescope.vim", helper.get_file },
    { "TelescopePrompt.lua", helper.get_file },
  },
}, {
  sorting_strategy = "descending",
  scroll_strategy = "cycle",
})
