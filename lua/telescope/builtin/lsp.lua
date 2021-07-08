local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')
local entry_display = require('telescope.pickers.entry_display')
local utils = require('telescope.utils')
local strings = require('plenary.strings')
local a = require('plenary.async_lib')
local async, await = a.async, a.await
local channel = a.util.channel

local conf = require('telescope.config').values

local lsp = {}

lsp.references = function(opts)
  opts.shorten_path = utils.get_default(opts.shorten_path, true)

  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = true }

  local results_lsp, err = vim.lsp.buf_request_sync(0, "textDocument/references", params, opts.timeout or 10000)
  if err then
    vim.api.nvim_err_writeln("Error when finding references: " .. err)
    return
  end

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
      entry_maker = opts.entry_maker or make_entry.gen_from_quickfix(opts),
    },
    previewer = conf.qflist_previewer(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

local function list_or_jump(action, title, opts)
  opts = opts or {}

  local params = vim.lsp.util.make_position_params()
  local result, err = vim.lsp.buf_request_sync(0, action, params, opts.timeout or 10000)
  if err then
    vim.api.nvim_err_writeln("Error when executing " .. action .. " : " .. err)
    return
  end
  local flattened_results = {}
  for _, server_results in pairs(result) do
    if server_results.result then
      vim.list_extend(flattened_results, server_results.result)
    end
  end

  if #flattened_results == 0 then
    return
  elseif #flattened_results == 1 then
    vim.lsp.util.jump_to_location(flattened_results[1])
  else
    local locations = vim.lsp.util.locations_to_items(flattened_results)
    pickers.new(opts, {
      prompt_title = title,
      finder = finders.new_table {
        results = locations,
        entry_maker = opts.entry_maker or make_entry.gen_from_quickfix(opts),
      },
      previewer = conf.qflist_previewer(opts),
      sorter = conf.generic_sorter(opts),
    }):find()
  end
end

lsp.definitions = function(opts)
  return list_or_jump("textDocument/definition",  'LSP Definitions', opts)
end

lsp.implementations = function(opts)
  return list_or_jump("textDocument/implementation",  'LSP Implementations', opts)
end

lsp.document_symbols = function(opts)
  local params = vim.lsp.util.make_position_params()
  local results_lsp, err = vim.lsp.buf_request_sync(0, "textDocument/documentSymbol", params, opts.timeout or 10000)
  if err then
    vim.api.nvim_err_writeln("Error when finding document symbols: " .. err)
    return
  end

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from textDocument/documentSymbol")
    return
  end

  local locations = {}
  for _, server_results in pairs(results_lsp) do
    vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result, 0) or {})
  end

  locations = utils.filter_symbols(locations, opts)
  if locations == nil then
    -- error message already printed in `utils.filter_symbols`
    return
  end

  if vim.tbl_isempty(locations) then
    return
  end

  opts.ignore_filename = opts.ignore_filename or true
  pickers.new(opts, {
    prompt_title = 'LSP Document Symbols',
    finder    = finders.new_table {
      results = locations,
      entry_maker = opts.entry_maker or make_entry.gen_from_lsp_symbols(opts)
    },
    previewer = conf.qflist_previewer(opts),
    sorter = conf.prefilter_sorter{
      tag = "symbol_type",
      sorter = conf.generic_sorter(opts)
    }
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

  local idx = 1
  local results = {}
  local widths = {
    idx = 0,
    command_title = 0,
    client_name = 0,
  }

  for client_id, response in pairs(results_lsp) do
    if response.result then
      local client = vim.lsp.get_client_by_id(client_id)

      for _, result in pairs(response.result) do
        local entry = {
          idx = idx,
          command_title = result.title,
          client_name = client and client.name or "",
          command = result,
        }

        for key, value in pairs(widths) do
          widths[key] = math.max(value, strings.strdisplaywidth(entry[key]))
        end

        table.insert(results, entry)
        idx = idx + 1
      end
    end
  end

  if #results == 0 then
    print("No code actions available")
    return
  end

  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = widths.idx + 1 }, -- +1 for ":" suffix
      { width = widths.command_title },
      { width = widths.client_name },
    },
  }

  local function make_display(entry)
    return displayer {
      {entry.idx .. ":", "TelescopePromptPrefix"},
      {entry.command_title},
      {entry.client_name, "TelescopeResultsComment"},
    }
  end

  pickers.new(opts, {
    prompt_title = 'LSP Code Actions',
    finder    = finders.new_table {
      results = results,
      entry_maker = function(line)
        return {
          valid = line ~= nil,
          value = line.command,
          ordinal = line.idx .. line.command_title,
          command_title = line.command_title,
          idx = line.idx,
          client_name = line.client_name,
          display = make_display,
        }
      end
    },
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
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
  local results_lsp, err = vim.lsp.buf_request_sync(0, "workspace/symbol", params, opts.timeout or 10000)
  if err then
    vim.api.nvim_err_writeln("Error when finding workspace symbols: " .. err)
    return
  end

  local locations = {}

  if results_lsp and not vim.tbl_isempty(results_lsp) then
    for _, server_results in pairs(results_lsp) do
      -- Some LSPs (like Clangd and intelephense) might return { { result = {} } }, so make sure we have result
      if server_results and server_results.result and not vim.tbl_isempty(server_results.result) then
        vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result, 0) or {})
      end
    end
  end

  locations = utils.filter_symbols(locations, opts)
  if locations == nil then
    -- error message already printed in `utils.filter_symbols`
    return
  end

  if vim.tbl_isempty(locations) then
    print("No results from workspace/symbol. Maybe try a different query: " ..
      "Telescope lsp_workspace_symbols query=example")
    return
  end

  opts.ignore_filename = utils.get_default(opts.ignore_filename, false)
  opts.hide_filename = utils.get_default(opts.hide_filename, false)

  pickers.new(opts, {
    prompt_title = 'LSP Workspace Symbols',
    finder    = finders.new_table {
      results = locations,
      entry_maker = opts.entry_maker or make_entry.gen_from_lsp_symbols(opts)
    },
    previewer = conf.qflist_previewer(opts),
    sorter = conf.prefilter_sorter{
      tag = "symbol_type",
      sorter = conf.generic_sorter(opts)
    }
  }):find()
end

local function get_workspace_symbols_requester(bufnr)
  local cancel = function() end

  return async(function(prompt)
    local tx, rx = channel.oneshot()
    cancel()
    _, cancel = vim.lsp.buf_request(bufnr, "workspace/symbol", {query = prompt}, tx)

    local err, _, results_lsp = await(rx())
    assert(not err, err)

    local locations = vim.lsp.util.symbols_to_items(results_lsp or {}, bufnr) or {}
    return locations
  end)
end

lsp.dynamic_workspace_symbols = function(opts)
  local curr_bufnr = vim.api.nvim_get_current_buf()

  pickers.new(opts, {
    prompt_title = 'LSP Dynamic Workspace Symbols',
    finder    = finders.new_dynamic {
      entry_maker = opts.entry_maker or make_entry.gen_from_lsp_symbols(opts),
      fn = get_workspace_symbols_requester(curr_bufnr),
    },
    previewer = conf.qflist_previewer(opts),
    sorter = conf.generic_sorter()
  }):find()
end

lsp.diagnostics = function(opts)
  local locations = utils.diagnostics_to_tbl(opts)

  if vim.tbl_isempty(locations) then
    print('No diagnostics found')
    return
  end

  opts.hide_filename = utils.get_default(opts.hide_filename, true)
  pickers.new(opts, {
    prompt_title = 'LSP Document Diagnostics',
    finder = finders.new_table {
      results = locations,
      entry_maker = opts.entry_maker or make_entry.gen_from_lsp_diagnostics(opts)
    },
    previewer = conf.qflist_previewer(opts),
    sorter = conf.prefilter_sorter{
      tag = "type",
      sorter = conf.generic_sorter(opts)
    }
  }):find()
end

lsp.workspace_diagnostics = function(opts)
  opts = utils.get_default(opts, {})
  opts.hide_filename = utils.get_default(opts.hide_filename, false)
  opts.prompt_title = 'LSP Workspace Diagnostics'
  opts.get_all = true
  lsp.diagnostics(opts)
end

local function check_capabilities(feature)
  local clients = vim.lsp.buf_get_clients(0)

  local supported_client = false
  for _, client in pairs(clients) do
    supported_client = client.resolved_capabilities[feature]
    if supported_client then break end
  end

  if supported_client then
    return true
  else
    if #clients == 0 then
      print("LSP: no client attached")
    else
      print("LSP: server does not support " .. feature)
    end
    return false
  end
end

local feature_map = {
  ["code_actions"]      = "code_action",
  ["document_symbols"]  = "document_symbol",
  ["references"]        = "find_references",
  ["definitions"]       = "goto_definition",
  ["implementations"]   = "implementation",
  ["workspace_symbols"] = "workspace_symbol",
}

local function apply_checks(mod)
  for k, v in pairs(mod) do
    mod[k] = function(opts)
      opts = opts or {}

      local feature_name = feature_map[k]
      if feature_name and not check_capabilities(feature_name) then
        return
      end
      v(opts)
    end
  end

  return mod
end

return apply_checks(lsp)
