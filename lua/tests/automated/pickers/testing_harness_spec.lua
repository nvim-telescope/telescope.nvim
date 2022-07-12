local testharness = require "telescope.testharness"

describe("testing harness", function()
  it("should find the readme, using lowercase", function()
    testharness.run_string [[
      runner.picker('find_files', 'readme.md', {
        post_typed = {
          { "> readme.md", GetPrompt },
          { "> README.md", GetBestResult },
        },
        post_close = {
          { 'README.md', GetFile },
        }
      }, {
        disable_devicons = true,
      })
    ]]
  end)

  it("should find the readme, using uppercase", function()
    testharness.run_string [[
      runner.picker('find_files', 'RE', {
        post_close = {
          { 'README.md', GetFile },
        }
      })
    ]]
  end)

  it("Should find telescope prompt file", function()
    testharness.run_string [[
      runner.picker('find_files', 'TelescopePrompt', {
        post_close = {
          { 'TelescopePrompt.lua', GetFile },
        }
      })
    ]]
  end)
end)
