--[[
A collection of builtin pipelines for telesceope.

Meant for both example and for easy startup.
--]]

local finders = require('telescope.finders')
local previewers = require('telescope.previewers')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')

local builtin = {}

local ifnil = function(x, was_nil, was_not_nil)
  if x == nil then
    return was_nil
  else
    return was_not_nil
  end
end

builtin.git_files = function(opts)
  opts = opts or {}

  local show_preview = ifnil(opts.show_preview, true, opts.show_preview)

  -- TODO: Auto select bottom row
  -- TODO: filter out results when they don't match at all anymore.

  local file_finder = finders.new {
    static = true,

    fn_command = function(self)
      return {
        command = 'git',
        args = {'ls-files'}
      }
    end,
  }

  local file_previewer = previewers.cat

  local file_picker = pickers.new {
    previewer = show_preview and file_previewer,
  }

  -- local file_sorter = telescope.sorters.get_ngram_sorter()
  -- local file_sorter = require('telescope.sorters').get_levenshtein_sorter()
  local file_sorter = sorters.get_norcalli_sorter()

  file_picker:find {
    prompt = 'Simple File',
    finder = file_finder,
    sorter = file_sorter,
  }
end

builtin.live_grep = function()
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

  local file_previewer = previewers.vimgrep
  local file_picker = pickers.new {
    previewer = file_previewer
  }

  -- local file_sorter = telescope.sorters.get_ngram_sorter()
  -- local file_sorter = require('telescope.sorters').get_levenshtein_sorter()
  -- local file_sorter = sorters.get_norcalli_sorter()

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

  file_picker:find {
    prompt = 'Live Grep',
    finder = live_grepper,
    sorter = oldfiles_sorter,
  }
end

builtin.lsp_references = function()
  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = true }

  local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/references", params)
  local locations = {}
  for _, server_results in pairs(results_lsp) do
    vim.list_extend(locations, vim.lsp.util.locations_to_items(server_results.result) or {})
  end

  local results = {}
  for _, entry in ipairs(locations) do
    local vimgrep_str = string.format(
      "%s:%s:%s: %s",
      vim.fn.fnamemodify(entry.filename, ":."),
      entry.lnum,
      entry.col,
      entry.text
    )

    table.insert(results, {
      valid = true,
      value = entry,
      ordinal = vimgrep_str,
      display = vimgrep_str,
    })
  end

  if vim.tbl_isempty(results) then
    return
  end

  local lsp_reference_finder = finders.new {
    results = results
  }

  local reference_previewer = previewers.qflist
  local reference_picker = pickers.new {
    previewer = reference_previewer
  }

  reference_picker:find {
    prompt = 'LSP References',
    finder = lsp_reference_finder,
    sorter = sorters.get_norcalli_sorter(),
  }
end

builtin.quickfix = function()
  local locations = vim.fn.getqflist()

  local results = {}
  for _, entry in ipairs(locations) do
    if not entry.filename then
      entry.filename = vim.api.nvim_buf_get_name(entry.bufnr)
    end

    local vimgrep_str = string.format(
      "%s:%s:%s: %s",
      vim.fn.fnamemodify(entry.filename, ":."),
      entry.lnum,
      entry.col,
      entry.text
    )

    table.insert(results, {
      valid = true,
      value = entry,
      ordinal = vimgrep_str,
      display = vimgrep_str,
    })
  end

  if vim.tbl_isempty(results) then
    return
  end

  local lsp_reference_finder = finders.new {
    results = results
  }

  local reference_previewer = previewers.qflist
  local reference_picker = pickers.new {
    previewer = reference_previewer
  }

  reference_picker:find {
    prompt = 'LSP References',
    finder = lsp_reference_finder,
    sorter = sorters.get_norcalli_sorter(),
  }
end



return builtin
