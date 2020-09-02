--[[
A collection of builtin pipelines for telesceope.

Meant for both example and for easy startup.
--]]

local finders = require('telescope.finders')
local previewers = require('telescope.previewers')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')
local utils = require('telescope.utils')

local builtin = {}

builtin.git_files = function(opts)
  opts = opts or {}

  local make_entry = (
    opts.shorten_path
    and function(value)
      local result = {
        valid = true,
        display = utils.path_shorten(value),
        ordinal = value,
        value = value
      }

      return result
    end)

    or nil

  pickers.new(opts, {
    prompt    = 'Git File',
    finder    = finders.new_oneshot_job({ "git", "ls-files" }, make_entry),
    previewer = previewers.cat,
    sorter    = sorters.get_fuzzy_file(),
  }):find()

end

builtin.live_grep = function(opts)
  local live_grepper = finders.new {
    maximum_results = 1000,

    fn_command = function(self, prompt)
      -- TODO: Make it so that we can start searching on the first character.
      if not prompt or prompt == "" then
        return nil
      end

      return {
        command = 'rg',
        args = {"--vimgrep", prompt},
      }
    end
  }

  pickers.new(opts, {
    prompt    = 'Live Grep',
    finder    = live_grepper,
    previewer = previewers.vimgrep,
  }):find()

  -- TODO: Incorporate this.
  -- Weight the results somehow to be more likely to be the ones that you've opened.
  -- local old_files = {}
  -- for _, f in ipairs(vim.v.oldfiles) do
  --   old_files[f] = true
  -- end

  -- local oldfiles_sorter = sorters.new {
  --   scoring_function = function(prompt, entry)
  --     local line = entry.value

  --     if not line then
  --       return
  --     end

  --     local _, finish = string.find(line, ":")
  --     local filename = string.sub(line, 1, finish - 1)
  --     local expanded_fname = vim.fn.fnamemodify(filename, ':p')
  --     if old_files[expanded_fname] then
  --       print("Found oldfiles: ", entry.value)
  --       return 0
  --     else
  --       return 1
  --     end
  --   end
  -- }
end

-- TODO: document_symbol
-- TODO: workspace_symbol

builtin.lsp_references = function(opts)
  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = true }

  local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/references", params)
  local locations = {}
  for _, server_results in pairs(results_lsp) do
    vim.list_extend(locations, vim.lsp.util.locations_to_items(server_results.result) or {})
  end

  local results = utils.quickfix_items_to_entries(locations)

  if vim.tbl_isempty(results) then
    return
  end

  local reference_picker = pickers.new(opts, {
    prompt    = 'LSP References',
    finder    = finders.new_table(results),
    previewer = previewers.qflist,
    sorter    = sorters.get_norcalli_sorter(),
  }):find()
end

builtin.quickfix = function(opts)
  local locations = vim.fn.getqflist()
  local results = utils.quickfix_items_to_entries(locations)

  if vim.tbl_isempty(results) then
    return
  end

  pickers.new(opts, {
    prompt    = 'Quickfix',
    finder    = finders.new_table(results),
    previewer = previewers.qflist,
    sorter    = sorters.get_norcalli_sorter(),
  }):find()
end

builtin.grep_string = function(opts)
  opts = opts or {}

  local search = opts.search or vim.fn.expand("<cword>")

  local file_picker = pickers.new(opts, {
    prompt = 'Find Word',
    finder = finders.new_oneshot_job {'rg', '--vimgrep', search},
    previewer = previewers.vimgrep,
    sorter = sorters.get_norcalli_sorter(),
  }):find()
end

builtin.oldfiles = function(opts)
  pickers.new(opts, {
    prompt = 'Oldfiles',
    finder = finders.new_table(vim.tbl_filter(function(val)
      return 0 ~= vim.fn.filereadable(val)
    end, vim.v.oldfiles)),
    sorter = sorters.get_norcalli_sorter(),
    previewer = previewers.cat,
  }):find()
end

builtin.command_history = function(opts)
  local history_string = vim.fn.execute('history cmd')
  local history_list = vim.split(history_string, "\n")

  local results = {}
  for i = 3, #history_list do
    local item = history_list[i]
    local start, finish = string.find(item, "%d+ +")
    table.insert(results, string.sub(item, finish + 1))
  end

  pickers.new(opts, {
    prompt = 'Command History',
    finder = finders.new_table(results),
    sorter = sorters.get_norcalli_sorter(),

    -- TODO: Adapt `help` to this.
    -- previewer = previewers.cat,
  }):find()
end

return builtin
