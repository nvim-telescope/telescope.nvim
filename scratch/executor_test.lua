RELOAD("telescope")

local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')
local conf = require('telescope.config').values
local themes = require('telescope.themes')


local find_files = function(opts)
  opts = themes.get_dropdown {
    winblend = 10,
    border = true,
    previewer = false,
    shorten_path = false,
  }

  local files = vim.fn.systemlist('rg --files')
  opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)


  pickers.new(opts, {
    prompt_title = 'Find Files',
    finder = require('telescope.finders.static'):new {
      operations = 1000,
      results = files,
      entry_maker = make_entry.gen_from_file(opts),
    },
    previewer = conf.file_previewer(opts),
    sorter = conf.file_sorter(opts),
  }):find()
end

find_files()
