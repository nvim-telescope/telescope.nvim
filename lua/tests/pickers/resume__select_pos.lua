local helper = require "telescope.testharness.helpers"
local runner = require "telescope.testharness.runner"

runner.picker("find_files", ".md", {
  post_close = {
    { "README.md", helper.get_file },
  },
})

runner.picker("resume", "", {
  post_close = {
    { "developers.md", helper.get_file },
  },
}, { select_pos = 1 })

runner.picker("resume", "", {
  post_close = {
    { "CONTRIBUTING.md", helper.get_file },
  },
}, { select_pos = 1 })

runner.picker("resume", "", {
  post_close = {
    { "developers.md", helper.get_file },
  },
}, { select_pos = -1 })

runner.picker("resume", "", {
  post_close = {
    { "README.md", helper.get_file },
  },
}, { select_pos = -1 })

runner.picker("resume", "", {
  post_close = {
    { "CONTRIBUTING.md", helper.get_file },
  },
}, { select_pos = 2 })
