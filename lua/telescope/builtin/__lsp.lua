local channel = require("plenary.async.control").channel
local actions = require "telescope.actions"
local sorters = require "telescope.sorters"
local conf = require("telescope.config").values
local finders = require "telescope.finders"
local make_entry = require "telescope.make_entry"
local pickers = require "telescope.pickers"
local utils = require "telescope.utils"

local lsp = {}

local function call_hierarchy(opts, method, title, direction, item)
  vim.lsp.buf_request(opts.bufnr, method, { item = item }, function(err, result)
    if err then
      vim.api.nvim_err_writeln("Error handling " .. title .. ": " .. err.message)
      return
    end

    if not result or vim.tbl_isempty(result) then
      return
    end

    local locations = {}
    for _, ch_call in pairs(result) do
      local ch_item = ch_call[direction]
      for _, rng in pairs(ch_call.fromRanges) do
        table.insert(locations, {
          filename = vim.uri_to_fname(ch_item.uri),
          text = ch_item.name,
          lnum = rng.start.line + 1,
          col = rng.start.character + 1,
        })
      end
    end

    pickers
      .new(opts, {
        prompt_title = title,
        finder = finders.new_table {
          results = locations,
          entry_maker = opts.entry_maker or make_entry.gen_from_quickfix(opts),
        },
        previewer = conf.qflist_previewer(opts),
        sorter = conf.generic_sorter(opts),
        push_cursor_on_edit = true,
        push_tagstack_on_edit = true,
      })
      :find()
  end)
end

local function pick_call_hierarchy_item(call_hierarchy_items)
  if not call_hierarchy_items then
    return
  end
  if #call_hierarchy_items == 1 then
    return call_hierarchy_items[1]
  end
  local items = {}
  for i, item in pairs(call_hierarchy_items) do
    local entry = item.detail or item.name
    table.insert(items, string.format("%d. %s", i, entry))
  end
  local choice = vim.fn.inputlist(items)
  if choice < 1 or choice > #items then
    return
  end
  return choice
end

local function calls(opts, direction)
  local params = vim.lsp.util.make_position_params()
  vim.lsp.buf_request(opts.bufnr, "textDocument/prepareCallHierarchy", params, function(err, result)
    if err then
      vim.api.nvim_err_writeln("Error when preparing call hierarchy: " .. err)
      return
    end

    local call_hierarchy_item = pick_call_hierarchy_item(result)
    if not call_hierarchy_item then
      return
    end

    if direction == "from" then
      call_hierarchy(opts, "callHierarchy/incomingCalls", "LSP Incoming Calls", direction, call_hierarchy_item)
    else
      call_hierarchy(opts, "callHierarchy/outgoingCalls", "LSP Outgoing Calls", direction, call_hierarchy_item)
    end
  end)
end

lsp.incoming_calls = function(opts)
  calls(opts, "from")
end

lsp.outgoing_calls = function(opts)
  calls(opts, "to")
end

--- convert `item` type back to something we can pass to `vim.lsp.util.jump_to_location`
--- stopgap for pre-nvim 0.10 - after which we can simply use the `user_data`
--- field on the items in `vim.lsp.util.locations_to_items`
---@param item vim.lsp.util.locations_to_items.ret
---@param offset_encoding string|nil utf-8|utf-16|utf-32
---@return lsp.Location
local function item_to_location(item, offset_encoding)
  local line = item.lnum - 1
  local character = vim.lsp.util._str_utfindex_enc(item.text, item.col, offset_encoding) - 1
  local uri
  if utils.is_uri(item.filename) then
    uri = item.filename
  else
    uri = vim.uri_from_fname(item.filename)
  end
  return {
    uri = uri,
    range = {
      start = {
        line = line,
        character = character,
      },
      ["end"] = {
        line = line,
        character = character,
      },
    },
  }
end

---@alias telescope.lsp.list_or_jump_action
---| "textDocument/references"
---| "textDocument/definition"
---| "textDocument/typeDefinition"
---| "textDocument/implementation"

---@param action telescope.lsp.list_or_jump_action
---@param items vim.lsp.util.locations_to_items.ret[]
---@param opts table
---@return vim.lsp.util.locations_to_items.ret[]
local apply_action_handler = function(action, items, opts)
  if action == "textDocument/references" and not opts.include_current_line then
    local lnum = vim.api.nvim_win_get_cursor(opts.winnr)[1]
    items = vim.tbl_filter(function(v)
      return not (v.filename == opts.curr_filepath and v.lnum == lnum)
    end, items)
  end

  return items
end

---@param items vim.lsp.util.locations_to_items.ret[]
---@param opts table
---@return vim.lsp.util.locations_to_items.ret[]
local function filter_file_ignore_patters(items, opts)
  local file_ignore_patterns = vim.F.if_nil(opts.file_ignore_patterns, conf.file_ignore_patterns)
  file_ignore_patterns = file_ignore_patterns or {}
  if vim.tbl_isempty(file_ignore_patterns) then
    return items
  end

  return vim.tbl_filter(function(item)
    for _, patt in ipairs(file_ignore_patterns) do
      if string.match(item.filename, patt) then
        return false
      end
    end
    return true
  end, items)
end

---@param action telescope.lsp.list_or_jump_action
---@param title string prompt title
---@param funname string: name of the calling function
---@param params lsp.TextDocumentPositionParams
---@param opts table
local function list_or_jump(action, title, funname, params, opts)
  opts.reuse_win = vim.F.if_nil(opts.reuse_win, false)
  opts.curr_filepath = vim.api.nvim_buf_get_name(opts.bufnr)

  vim.lsp.buf_request(opts.bufnr, action, params, function(err, result, ctx, _)
    if err then
      vim.api.nvim_err_writeln("Error when executing " .. action .. " : " .. err.message)
      return
    end

    if result == nil then
      return
    end

    local locations = {}
    if not utils.islist(result) then
      locations = { result }
    end
    vim.list_extend(locations, result)

    local offset_encoding = vim.lsp.get_client_by_id(ctx.client_id).offset_encoding
    local items = vim.lsp.util.locations_to_items(locations, offset_encoding)
    items = apply_action_handler(action, items, opts)
    items = filter_file_ignore_patters(items, opts)

    if vim.tbl_isempty(items) then
      utils.notify(funname, {
        msg = string.format("No %s found", title),
        level = "INFO",
      })
      return
    end

    if #items == 1 and opts.jump_type ~= "never" then
      local item = items[1]
      if opts.curr_filepath ~= item.filename then
        local cmd
        if opts.jump_type == "tab" then
          cmd = "tabedit"
        elseif opts.jump_type == "split" then
          cmd = "new"
        elseif opts.jump_type == "vsplit" then
          cmd = "vnew"
        elseif opts.jump_type == "tab drop" then
          cmd = "tab drop"
        end

        if cmd then
          vim.cmd(string.format("%s %s", cmd, item.filename))
        end
      end

      local location = item_to_location(item, offset_encoding)
      vim.lsp.util.jump_to_location(location, offset_encoding, opts.reuse_win)
    else
      pickers
        .new(opts, {
          prompt_title = title,
          finder = finders.new_table {
            results = items,
            entry_maker = opts.entry_maker or make_entry.gen_from_quickfix(opts),
          },
          previewer = conf.qflist_previewer(opts),
          sorter = conf.generic_sorter(opts),
          push_cursor_on_edit = true,
          push_tagstack_on_edit = true,
        })
        :find()
    end
  end)
end

lsp.references = function(opts)
  opts.include_current_line = vim.F.if_nil(opts.include_current_line, false)
  local params = vim.lsp.util.make_position_params(opts.winnr)
  params.context = { includeDeclaration = vim.F.if_nil(opts.include_declaration, true) }
  return list_or_jump("textDocument/references", "LSP References", "builtin.lsp_references", params, opts)
end

lsp.definitions = function(opts)
  local params = vim.lsp.util.make_position_params(opts.winnr)
  return list_or_jump("textDocument/definition", "LSP Definitions", "builtin.lsp_definitions", params, opts)
end

lsp.type_definitions = function(opts)
  local params = vim.lsp.util.make_position_params(opts.winnr)
  return list_or_jump(
    "textDocument/typeDefinition",
    "LSP Type Definitions",
    "builtin.lsp_type_definitions",
    params,
    opts
  )
end

lsp.implementations = function(opts)
  local params = vim.lsp.util.make_position_params(opts.winnr)
  return list_or_jump("textDocument/implementation", "LSP Implementations", "builtin.lsp_implementations", params, opts)
end

local symbols_sorter = function(symbols)
  if vim.tbl_isempty(symbols) then
    return symbols
  end

  local current_buf = vim.api.nvim_get_current_buf()

  -- sort adequately for workspace symbols
  local filename_to_bufnr = {}
  for _, symbol in ipairs(symbols) do
    if filename_to_bufnr[symbol.filename] == nil then
      filename_to_bufnr[symbol.filename] = vim.uri_to_bufnr(vim.uri_from_fname(symbol.filename))
    end
    symbol.bufnr = filename_to_bufnr[symbol.filename]
  end

  table.sort(symbols, function(a, b)
    if a.bufnr == b.bufnr then
      return a.lnum < b.lnum
    end
    if a.bufnr == current_buf then
      return true
    end
    if b.bufnr == current_buf then
      return false
    end
    return a.bufnr < b.bufnr
  end)

  return symbols
end

lsp.document_symbols = function(opts)
  local params = vim.lsp.util.make_position_params(opts.winnr)
  vim.lsp.buf_request(opts.bufnr, "textDocument/documentSymbol", params, function(err, result, _, _)
    if err then
      vim.api.nvim_err_writeln("Error when finding document symbols: " .. err.message)
      return
    end

    if not result or vim.tbl_isempty(result) then
      utils.notify("builtin.lsp_document_symbols", {
        msg = "No results from textDocument/documentSymbol",
        level = "INFO",
      })
      return
    end

    local locations = vim.lsp.util.symbols_to_items(result or {}, opts.bufnr) or {}
    locations = utils.filter_symbols(locations, opts, symbols_sorter)
    if locations == nil then
      -- error message already printed in `utils.filter_symbols`
      return
    end

    if vim.tbl_isempty(locations) then
      utils.notify("builtin.lsp_document_symbols", {
        msg = "No document_symbol locations found",
        level = "INFO",
      })
      return
    end

    opts.path_display = { "hidden" }
    pickers
      .new(opts, {
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
        push_cursor_on_edit = true,
        push_tagstack_on_edit = true,
      })
      :find()
  end)
end

lsp.workspace_symbols = function(opts)
  local params = { query = opts.query or "" }
  vim.lsp.buf_request(opts.bufnr, "workspace/symbol", params, function(err, server_result, _, _)
    if err then
      vim.api.nvim_err_writeln("Error when finding workspace symbols: " .. err.message)
      return
    end

    local locations = vim.lsp.util.symbols_to_items(server_result or {}, opts.bufnr) or {}
    locations = utils.filter_symbols(locations, opts, symbols_sorter)
    if locations == nil then
      -- error message already printed in `utils.filter_symbols`
      return
    end

    if vim.tbl_isempty(locations) then
      utils.notify("builtin.lsp_workspace_symbols", {
        msg = "No results from workspace/symbol. Maybe try a different query: "
          .. "'Telescope lsp_workspace_symbols query=example'",
        level = "INFO",
      })
      return
    end

    opts.ignore_filename = vim.F.if_nil(opts.ignore_filename, false)

    pickers
      .new(opts, {
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
      })
      :find()
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
      locations = utils.filter_symbols(locations, opts, symbols_sorter) or {}
    end
    return locations
  end
end

lsp.dynamic_workspace_symbols = function(opts)
  pickers
    .new(opts, {
      prompt_title = "LSP Dynamic Workspace Symbols",
      finder = finders.new_dynamic {
        entry_maker = opts.entry_maker or make_entry.gen_from_lsp_symbols(opts),
        fn = get_workspace_symbols_requester(opts.bufnr, opts),
      },
      previewer = conf.qflist_previewer(opts),
      sorter = sorters.highlighter_only(opts),
      attach_mappings = function(_, map)
        map("i", "<c-space>", actions.to_fuzzy_refine)
        return true
      end,
    })
    :find()
end

local function check_capabilities(method, bufnr)
  --TODO(clason): remove when dropping support for Nvim 0.9
  local get_clients = vim.fn.has "nvim-0.10" == 1 and vim.lsp.get_clients or vim.lsp.get_active_clients
  local clients = get_clients { bufnr = bufnr }

  for _, client in pairs(clients) do
    if client.supports_method(method, { bufnr = bufnr }) then
      return true
    end
  end

  if #clients == 0 then
    utils.notify("builtin.lsp_*", {
      msg = "no client attached",
      level = "INFO",
    })
  else
    utils.notify("builtin.lsp_*", {
      msg = "server does not support " .. method,
      level = "INFO",
    })
  end
  return false
end

local feature_map = {
  ["document_symbols"] = "textDocument/documentSymbol",
  ["references"] = "textDocument/references",
  ["definitions"] = "textDocument/definition",
  ["type_definitions"] = "textDocument/typeDefinition",
  ["implementations"] = "textDocument/implementation",
  ["workspace_symbols"] = "workspace/symbol",
  ["incoming_calls"] = "callHierarchy/incomingCalls",
  ["outgoing_calls"] = "callHierarchy/outgoingCalls",
}

local function apply_checks(mod)
  for k, v in pairs(mod) do
    mod[k] = function(opts)
      opts = opts or {}

      local method = feature_map[k]
      if method and not check_capabilities(method, opts.bufnr) then
        return
      end
      v(opts)
    end
  end

  return mod
end

return apply_checks(lsp)
