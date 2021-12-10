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

  vim.lsp.buf_request(0, "textDocument/references", params, function(err, result, _ctx, _config)
    if err then
      vim.api.nvim_err_writeln("Error when finding references: " .. err.message)
      return
    end

    local locations = {}
    if result then
      vim.list_extend(locations, vim.lsp.util.locations_to_items(result) or {})
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
  end)
end

local function list_or_jump(action, title, opts)
  opts = opts or {}

  local params = vim.lsp.util.make_position_params()
  vim.lsp.buf_request(0, action, params, function(err, result, _ctx, _config)
    if err then
      vim.api.nvim_err_writeln("Error when executing " .. action .. " : " .. err.message)
      return
    end
    local flattened_results = {}
    if result then
      -- textDocument/definition can return Location or Location[]
      if not vim.tbl_islist(result) then
        flattened_results = { result }
      end

      vim.list_extend(flattened_results, result)
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
  end)
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
  local bufnr = vim.api.nvim_get_current_buf()
  local params = vim.lsp.util.make_position_params()
  vim.lsp.buf_request(0, "textDocument/documentSymbol", params, function(err, result, _ctx, _config)
    if err then
      vim.api.nvim_err_writeln("Error when finding document symbols: " .. err.message)
      return
    end

    if not result or vim.tbl_isempty(result) then
      print "No results from textDocument/documentSymbol"
      return
    end

    local locations = vim.lsp.util.symbols_to_items(result or {}, bufnr) or {}
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
  end)
end

lsp.code_actions = function(opts)
  local params = vim.F.if_nil(opts.params, vim.lsp.util.make_range_params())

  params.context = {
    diagnostics = vim.lsp.diagnostic.get_line_diagnostics(),
  }

  local results_lsp, err = vim.lsp.buf_request_sync(
    0,
    "textDocument/codeAction",
    params,
    vim.F.if_nil(opts.timeout, 10000)
  )

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
          client = client,
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
      { entry.value.idx .. ":", "TelescopePromptPrefix" },
      { entry.value.command_title },
      { entry.value.client_name, "TelescopeResultsComment" },
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
      -- Is only run on the "java.apply.workspaceEdit" codeaction.
      -- Fixed Java/jdtls compatibility with Telescope
      -- See fix_zero_version commentary for more information
      local command = (action.command and action.command.command) or action.command
      if not (command == "java.apply.workspaceEdit") then
        return action
      end
      local arguments = (action.command and action.command.arguments) or action.arguments
      action.edit = fix_zero_version(arguments[1])
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
      entry_maker = function(action)
        return {
          value = action,
          ordinal = action.idx .. action.command_title,
          display = make_display,
        }
      end,
    },
    attach_mappings = function(prompt_bufnr)
      actions.select_default:replace(function()
        local selection = action_state.get_selected_entry()
        actions.close(prompt_bufnr)
        local action = selection.value.command
        local client = selection.value.client
        if
          not action.edit
          and client
          and type(client.resolved_capabilities.code_action) == "table"
          and client.resolved_capabilities.code_action.resolveProvider
        then
          client.request("codeAction/resolve", action, function(resolved_err, resolved_action)
            if resolved_err then
              vim.notify(resolved_err.code .. ": " .. resolved_err.message, vim.log.levels.ERROR)
              return
            end
            if resolved_action then
              execute_action(transform_action(resolved_action))
            else
              execute_action(transform_action(action))
            end
          end)
        else
          execute_action(transform_action(action))
        end
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
  local bufnr = vim.api.nvim_get_current_buf()
  local params = { query = opts.query or "" }
  vim.lsp.buf_request(0, "workspace/symbol", params, function(err, server_result, _ctx, _config)
    if err then
      vim.api.nvim_err_writeln("Error when finding workspace symbols: " .. err.message)
      return
    end

    local locations = vim.lsp.util.symbols_to_items(server_result or {}, bufnr) or {}
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
  end)
end

local function get_workspace_symbols_requester(bufnr, opts)
  local cancel = function() end

  return function(prompt)
    local tx, rx = channel.oneshot()
    cancel()
    _, cancel = vim.lsp.buf_request(bufnr, "workspace/symbol", { query = prompt }, tx)

    -- Handle 0.5 / 0.5.1 handler situation
    local err, res = rx()
    assert(not err, err)

    local locations = vim.lsp.util.symbols_to_items(res or {}, bufnr) or {}
    if not vim.tbl_isempty(locations) then
      locations = utils.filter_symbols(locations, opts) or {}
    end
    return locations
  end
end

lsp.dynamic_workspace_symbols = function(opts)
  local curr_bufnr = vim.api.nvim_get_current_buf()

  pickers.new(opts, {
    prompt_title = "LSP Dynamic Workspace Symbols",
    finder = finders.new_dynamic {
      entry_maker = opts.entry_maker or make_entry.gen_from_lsp_symbols(opts),
      fn = get_workspace_symbols_requester(curr_bufnr, opts),
    },
    previewer = conf.qflist_previewer(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
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
