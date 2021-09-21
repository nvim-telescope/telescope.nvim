local channel = require("plenary.async.control").channel

local action_state = require "telescope.actions.state"
local actions = require "telescope.actions"
local conf = require("telescope.config").values
local entry_display = require "telescope.pickers.entry_display"
local finders = require "telescope.finders"
local make_entry = require "telescope.make_entry"
local pickers = require "telescope.pickers"
local strings = require "plenary.strings"
local utils = require "telescope.utils"

local lsp = {}

lsp.references = function(opts)
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
    prompt_title = "LSP References",
    finder = finders.new_table {
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
      -- textDocument/definition can return Location or Location[]
      if not vim.tbl_islist(server_results.result) then
        flattened_results = { server_results.result }
        break
      end

      vim.list_extend(flattened_results, server_results.result)
    end
  end

  if #flattened_results == 0 then
    return
  elseif #flattened_results == 1 and opts.jump_type ~= "never" then
    if opts.jump_type == "tab" then
      vim.cmd "tabedit"
    elseif opts.jump_type == "split" then
      vim.cmd "new"
    elseif opts.jump_type == "vsplit" then
      vim.cmd "vnew"
    end
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
  return list_or_jump("textDocument/definition", "LSP Definitions", opts)
end

lsp.type_definitions = function(opts)
  return list_or_jump("textDocument/typeDefinition", "LSP Type Definitions", opts)
end

lsp.implementations = function(opts)
  return list_or_jump("textDocument/implementation", "LSP Implementations", opts)
end

lsp.document_symbols = function(opts)
  local params = vim.lsp.util.make_position_params()
  local results_lsp, err = vim.lsp.buf_request_sync(0, "textDocument/documentSymbol", params, opts.timeout or 10000)
  if err then
    vim.api.nvim_err_writeln("Error when finding document symbols: " .. err)
    return
  end

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print "No results from textDocument/documentSymbol"
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
    prompt_title = "LSP Document Symbols",
    finder = finders.new_table {
      results = locations,
      entry_maker = opts.entry_maker or make_entry.gen_from_lsp_symbols(opts),
    },
    previewer = conf.qflist_previewer(opts),
    sorter = conf.prefilter_sorter {
      tag = "symbol_type",
      sorter = conf.generic_sorter(opts),
    },
  }):find()
end

lsp.code_actions = function(opts)
  local params = opts.params or vim.lsp.util.make_range_params()

  params.context = {
    diagnostics = vim.lsp.diagnostic.get_line_diagnostics(),
  }

  local results_lsp, err = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, opts.timeout or 10000)

  if err then
    print("ERROR: " .. err)
    return
  end

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print "No results from textDocument/codeAction"
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
          command_title = result.title:gsub("\r\n", "\\r\\n"):gsub("\n", "\\n"),
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
    print "No code actions available"
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
      { entry.idx .. ":", "TelescopePromptPrefix" },
      { entry.command_title },
      { entry.client_name, "TelescopeResultsComment" },
    }
  end

  -- If the text document version is 0, set it to nil instead so that Neovim
  -- won't refuse to update a buffer that it believes is newer than edits.
  -- See: https://github.com/eclipse/eclipse.jdt.ls/issues/1695
  -- Source:
  -- https://github.com/neovim/nvim-lspconfig/blob/486f72a25ea2ee7f81648fdfd8999a155049e466/lua/lspconfig/jdtls.lua#L62
  local function fix_zero_version(workspace_edit)
    if workspace_edit and workspace_edit.documentChanges then
      for _, change in pairs(workspace_edit.documentChanges) do
        local text_document = change.textDocument
        if text_document and text_document.version and text_document.version == 0 then
          text_document.version = nil
        end
      end
    end
    return workspace_edit
  end

  --[[
  -- actions is (Command | CodeAction)[] | null
  -- CodeAction
  --      title: String
  --      kind?: CodeActionKind
  --      diagnostics?: Diagnostic[]
  --      isPreferred?: boolean
  --      edit?: WorkspaceEdit
  --      command?: Command
  --
  -- Command
  --      title: String
  --      command: String
  --      arguments?: any[]
  --]]
  local transform_action = opts.transform_action
    or function(action)
      -- Remove 0 -version from LSP codeaction request payload.
      -- Is only run on lsp codeactions which contain a comand or a arguments field
      -- Fixed Java/jdtls compatibility with Telescope
      -- See fix_zero_version commentary for more information
      if (action.command and action.command.arguments) or action.arguments then
        if action.command.command then
          action.edit = fix_zero_version(action.command.arguments[1])
        else
          action.edit = fix_zero_version(action.arguments[1])
        end
      end
      return action
    end

  local execute_action = opts.execute_action
    or function(action)
      if action.edit or type(action.command) == "table" then
        if action.edit then
          vim.lsp.util.apply_workspace_edit(action.edit)
        end
        if type(action.command) == "table" then
          vim.lsp.buf.execute_command(action.command)
        end
      else
        vim.lsp.buf.execute_command(action)
      end
    end

  pickers.new(opts, {
    prompt_title = "LSP Code Actions",
    finder = finders.new_table {
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
      end,
    },
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        local action = selection.value

        execute_action(transform_action(action))
      end)

      return true
    end,
    sorter = conf.generic_sorter(opts),
  }):find()
end

lsp.range_code_actions = function(opts)
  opts.params = vim.lsp.util.make_given_range_params({ opts.start_line, 1 }, { opts.end_line, 1 })
  lsp.code_actions(opts)
end

lsp.workspace_symbols = function(opts)
  local params = { query = opts.query or "" }
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
    print(
      "No results from workspace/symbol. Maybe try a different query: "
        .. "Telescope lsp_workspace_symbols query=example"
    )
    return
  end

  opts.ignore_filename = utils.get_default(opts.ignore_filename, false)

  pickers.new(opts, {
    prompt_title = "LSP Workspace Symbols",
    finder = finders.new_table {
      results = locations,
      entry_maker = opts.entry_maker or make_entry.gen_from_lsp_symbols(opts),
    },
    previewer = conf.qflist_previewer(opts),
    sorter = conf.prefilter_sorter {
      tag = "symbol_type",
      sorter = conf.generic_sorter(opts),
    },
  }):find()
end

local function get_workspace_symbols_requester(bufnr)
  local cancel = function() end

  return function(prompt)
    local tx, rx = channel.oneshot()
    cancel()
    _, cancel = vim.lsp.buf_request(bufnr, "workspace/symbol", { query = prompt }, tx)

    -- Handle 0.5 / 0.5.1 handler situation
    local err, res_1, res_2 = rx()
    local results_lsp
    if type(res_1) == "table" then
      results_lsp = res_1
    else
      results_lsp = res_2
    end
    assert(not err, err)

    local locations = vim.lsp.util.symbols_to_items(results_lsp or {}, bufnr) or {}
    return locations
  end
end

lsp.dynamic_workspace_symbols = function(opts)
  local curr_bufnr = vim.api.nvim_get_current_buf()

  pickers.new(opts, {
    prompt_title = "LSP Dynamic Workspace Symbols",
    finder = finders.new_dynamic {
      entry_maker = opts.entry_maker or make_entry.gen_from_lsp_symbols(opts),
      fn = get_workspace_symbols_requester(curr_bufnr),
    },
    previewer = conf.qflist_previewer(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

lsp.diagnostics = function(opts)
  local locations = utils.diagnostics_to_tbl(opts)

  if vim.tbl_isempty(locations) then
    print "No diagnostics found"
    return
  end

  opts.path_display = utils.get_default(opts.path_display, "hidden")
  pickers.new(opts, {
    prompt_title = "LSP Document Diagnostics",
    finder = finders.new_table {
      results = locations,
      entry_maker = opts.entry_maker or make_entry.gen_from_lsp_diagnostics(opts),
    },
    previewer = conf.qflist_previewer(opts),
    sorter = conf.prefilter_sorter {
      tag = "type",
      sorter = conf.generic_sorter(opts),
    },
  }):find()
end

lsp.workspace_diagnostics = function(opts)
  opts = utils.get_default(opts, {})
  opts.path_display = utils.get_default(opts.path_display, {})
  opts.prompt_title = "LSP Workspace Diagnostics"
  opts.get_all = true
  lsp.diagnostics(opts)
end

local function check_capabilities(feature)
  local clients = vim.lsp.buf_get_clients(0)

  local supported_client = false
  for _, client in pairs(clients) do
    supported_client = client.resolved_capabilities[feature]
    if supported_client then
      break
    end
  end

  if supported_client then
    return true
  else
    if #clients == 0 then
      print "LSP: no client attached"
    else
      print("LSP: server does not support " .. feature)
    end
    return false
  end
end

local feature_map = {
  ["code_actions"] = "code_action",
  ["document_symbols"] = "document_symbol",
  ["references"] = "find_references",
  ["definitions"] = "goto_definition",
  ["type_definitions"] = "type_definition",
  ["implementations"] = "implementation",
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
