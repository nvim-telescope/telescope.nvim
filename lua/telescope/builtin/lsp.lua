local actions = require('telescope.actions')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')
local utils = require('telescope.utils')

local conf = require('telescope.config').values

local lsp = {}

lsp.references = function(opts)
  opts.shorten_path = utils.get_default(opts.shorten_path, true)

  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = true }

  local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/references", params, opts.timeout or 10000)
  local locations = {}
  for _, server_results in pairs(results_lsp) do
    if server_results.result then
      vim.list_extend(locations, vim.lsp.util.locations_to_items(server_results.result) or {})
    end
  end

  if vim.tbl_isempty(locations) then
    return
  end

  pickers.new(opts, {
    prompt_title = 'LSP References',
    finder    = finders.new_table {
      results = locations,
      entry_maker = make_entry.gen_from_quickfix(opts),
    },
    previewer = previewers.qflist.new(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

lsp.document_symbols = function(opts)
  local params = vim.lsp.util.make_position_params()
  local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/documentSymbol", params, opts.timeout or 10000)

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from textDocument/documentSymbol")
    return
  end

  local locations = {}
  for _, server_results in pairs(results_lsp) do
    vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result, 0) or {})
  end

  if vim.tbl_isempty(locations) then
    return
  end

  pickers.new(opts, {
    prompt_title = 'LSP Document Symbols',
    finder    = finders.new_table {
      results = locations,
      entry_maker = make_entry.gen_from_quickfix(opts)
    },
    previewer = previewers.qflist.new(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

lsp.code_actions = function(opts)
  local params = opts.params or vim.lsp.util.make_range_params()

  params.context = {
    diagnostics = vim.lsp.diagnostic.get_line_diagnostics()
  }

  local results_lsp, err = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, opts.timeout or 10000)

  if err then
    print("ERROR: " .. err)
    return
  end

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from textDocument/codeAction")
    return
  end

  local results = (results_lsp[1] or results_lsp[2]).result;

  if not results or #results == 0 then
    print("No code actions available")
    return
  end

  for i,x in ipairs(results) do
    x.idx = i
  end

  pickers.new(opts, {
    prompt_title = 'LSP Code Actions',
    finder    = finders.new_table {
      results = results,
      entry_maker = function(line)
        return {
          valid = line ~= nil,
          value = line,
          ordinal = line.idx .. line.title,
          display = line.idx .. ': ' .. line.title
        }
      end
    },
    attach_mappings = function(prompt_bufnr)
      actions.goto_file_selection_edit:replace(function()
        local selection = actions.get_selected_entry()
        actions.close(prompt_bufnr)
        local val = selection.value

        if val.edit or type(val.command) == "table" then
          if val.edit then
            vim.lsp.util.apply_workspace_edit(val.edit)
          end
          if type(val.command) == "table" then
            vim.lsp.buf.execute_command(val.command)
          end
        else
          vim.lsp.buf.execute_command(val)
        end
      end)

      return true
    end,
    sorter = conf.generic_sorter(opts),
  }):find()
end

lsp.range_code_actions = function(opts)
 opts.params = vim.lsp.util.make_given_range_params()
 lsp.code_actions(opts)
end

lsp.workspace_symbols = function(opts)
  opts.shorten_path = utils.get_default(opts.shorten_path, true)

  local params = {query = opts.query or ''}
  local results_lsp = vim.lsp.buf_request_sync(0, "workspace/symbol", params, opts.timeout or 10000)

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from workspace/symbol")
    return
  end

  local locations = {}
  for _, server_results in pairs(results_lsp) do
    if server_results.result then
      vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result, 0) or {})
    end
  end

  if vim.tbl_isempty(locations) then
    return
  end

  pickers.new(opts, {
    prompt_title = 'LSP Workspace Symbols',
    finder    = finders.new_table {
      results = locations,
      entry_maker = make_entry.gen_from_quickfix(opts)
    },
    previewer = previewers.qflist.new(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

local function apply_checks(mod)
  for k, v in pairs(mod) do
    mod[k] = function(opts)
      opts = opts or {}

      v(opts)
    end
  end

  return mod
end

return apply_checks(lsp)
