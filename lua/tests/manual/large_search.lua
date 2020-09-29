RELOAD('plenary')
RELOAD('telescope')

local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local previewers = require('telescope.previewers')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')

local cwd = vim.fn.expand("~/build/neovim")

pickers.new {
  prompt = 'Large search',
  finder = finders.new_oneshot_job(
    {"fdfind"},
    {
      cwd = cwd,
      entry_maker = make_entry.gen_from_file {cwd = cwd},
      -- disable_devicons = true,
      -- maximum_results = 1000,
    }
  ),
  sorter = sorters.get_fuzzy_file(),
  previewer = previewers.cat.new{cwd = cwd},
}:find()


-- vim.wait(3000, function()
--   vim.cmd [[redraw!]]
--   return COMPLETED
-- end, 100)
-- vim.cmd [[bd!]]
-- vim.cmd [[stopinsert]]
