if vim.fn.has "mac" == 1 or require("telescope.utils").iswin then
  return
end

local tester = require "telescope.testharness"

local disp = function(val)
  return vim.inspect(val, { newline = " ", indent = "" })
end

describe("builtin.live_grep", function()
  for _, configuration in ipairs {
    { sorting_strategy = "descending" },
    { sorting_strategy = "ascending" },
  } do
    it("clears results correctly when " .. disp(configuration), function()
      tester.run_string(string.format(
        [[
        runner.picker(
          "live_grep",
          "abcd<esc>G",
          {
            post_typed = {
              {
                5,
                function()
                  return #vim.tbl_filter(function(line)
                    return line ~= ""
                  end, GetResults())
                end,
              },
            },
          },
          vim.tbl_extend("force", {
            sorter = require("telescope.sorters").get_fzy_sorter(),
            layout_strategy = "center",
            cwd = "./lua/tests/fixtures/live_grep",
            temp__scrolling_limit = 5,
          }, vim.json.decode [==[%s]==])
        )
        ]],
        vim.json.encode(configuration)
      ))
    end)
  end
end)
