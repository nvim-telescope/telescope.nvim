local log = require('telescope.log')

local M = {}

function M.score_entry(prompt, entry, picker)
  local worker = vim.loop.new_work(function(path, prompt, entry)
    package.path = path

    if not FuzzySorter then
      FuzzySorter = require('telescope.sorters').get_fuzzy_file()
    end

    -- return pcall(FuzzySorter.score, FuzzySorter, prompt, entry)
    return true, 3
  end, vim.schedule_wrap(function(score_ok, sort_score)
    -- TODO: we should totally make sure that this picker is still doing stuff...
    -- it could otherwise be done.
    if not score_ok or sort_score == -1 then
      log.warn("Sorting failed with:", prompt, entry, sort_score)
      return
    end

    -- picker.manager:add_entry(sort_score, entry)
    print(score_ok, sort_score)
  end))

  worker:queue(package.path, prompt, type(entry) == "string" and entry or entry.ordinal)
end

return M
