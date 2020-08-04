local telescope = require('telescope')

-- Goals:
-- 1. You pick a directory
-- 2. We `git ls-files` in that directory ONCE and ONLY ONCE to get the results.
-- 3. You can fuzzy find those results w/ fzf
-- 4. Select one and go to file.


--[[
ls_files_job.start()
fzf_job.stdin = ls_files_job.stdout

  self.stdin = vim.loop.new_pipe(false)
  -> self.stdin = finder.stdout


  -- Finder:
  intermediary_pipe = self.stdout

  -- repeat send this pipe when we want to get new filtering
  self.stdin = intermediary_pipe


  -- Filter + Sort
  ok, we could do scoring + cutoff and have that always be the case.

  OR

  filter takes a function, signature (prompt: str, line: str): number

  => echo $line | fzf --filter "prompt"
      return stdout != ""

  => lua_fuzzy_finder(prompt, line) return true if good enough

  TODO: Rename everything to be more clear like the name below.
  IFilterSorterAbstractFactoryGeneratorv1ProtoBeta

--]]


local file_finder = telescope.finders.new {
  static = true,

  -- self, prompt
  fn_command = function()
    return 'git ls-files'
  end,
}

local file_sorter = telescope.sorters.get_ngram_sorter()

-- local string_distance = require('telescope.algos.string_distance')
-- new {
--   scoring_function = function(self, prompt, line)
--     if prompt == '' then return 0 end
--     if not line then return -1 end

--     return tonumber(vim.fn.systemlist(string.format(
--       "echo '%s' | ~/tmp/fuzzy_test/target/debug/fuzzy_test '%s'",
--       line,
--       prompt
--     ))[1])
--   end
-- }


local file_previewer = telescope.previewers.vim_buffer_or_bat

local file_picker = telescope.pickers.new {
  previewer = file_previewer
}

file_picker:find {
  prompt = 'Find File',
  finder = file_finder,
  sorter = file_sorter,
}

