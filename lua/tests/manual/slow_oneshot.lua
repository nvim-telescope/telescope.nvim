RELOAD('telescope')

local actions = require('telescope.actions')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local previewers = require('telescope.previewers')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')
local utils = require('telescope.utils')

local slow_proc = function(opts)
  opts = opts or {}

  if opts.cwd then
    opts.cwd = vim.fn.expand(opts.cwd)
  end

  opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)

  local p = pickers.new(opts, {
    prompt = 'Slow Proc',
    finder = finders.new_oneshot_job(
      {"./scratch/slow_proc.sh"},
      opts
    ),
    previewer = previewers.cat.new(opts),
    sorter = sorters.get_fuzzy_file(),

    track = true,
  })

  local count = 0
  p:register_completion_callback(function(s)
    print(count, vim.inspect(s.stats, {
      process = function(item)
        if type(item) == 'string' and item:sub(1, 1) == '_' then
          return nil
        end

        return item
      end,
    }))

    count = count + 1
  end)

  local feed = function(text)
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(text, true, false, true), 'n', true)
  end

  if false then
    p:register_completion_callback(coroutine.wrap(function()
      local input = "pickers.lua"
      for i = 1, #input do
        feed(input:sub(i, i))
        coroutine.yield()
      end

      vim.wait(300, function() end)

      vim.cmd [[:q]]
      vim.cmd [[:Messages]]
      vim.cmd [[stopinsert]]
    end))
  end


  p:find()
end

slow_proc()
