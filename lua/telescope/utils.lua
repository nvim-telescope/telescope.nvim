local has_devicons, devicons = pcall(require, 'nvim-web-devicons')

local pathlib = require('telescope.path')
local Job     = require('plenary.job')

local utils = {}

utils.get_separator = function()
  return pathlib.separator
end

utils.if_nil = function(x, was_nil, was_not_nil)
  if x == nil then
    return was_nil
  else
    return was_not_nil
  end
end

utils.get_default = function(x, default)
  return utils.if_nil(x, default, x)
end

utils.get_lazy_default = function(x, defaulter, ...)
  if x == nil then
    return defaulter(...)
  else
    return x
  end
end

local function reversedipairsiter(t, i)
  i = i - 1
  if i ~= 0 then
    return i, t[i]
  end
end

utils.reversed_ipairs = function(t)
  return reversedipairsiter, t, #t + 1
end

utils.default_table_mt = {
  __index = function(t, k)
    local obj = {}
    rawset(t, k, obj)
    return obj
  end
}

utils.repeated_table = function(n, val)
  local empty_lines = {}
  for _ = 1, n do
    table.insert(empty_lines, val)
  end
  return empty_lines
end

utils.quickfix_items_to_entries = function(locations)
  local results = {}

  for _, entry in ipairs(locations) do
    local vimgrep_str = entry.vimgrep_str or string.format(
      "%s:%s:%s: %s",
      vim.fn.fnamemodify(entry.display_filename or entry.filename, ":."),
      entry.lnum,
      entry.col,
      entry.text
    )

    table.insert(results, {
      valid = true,
      value = entry,
      ordinal = vimgrep_str,
      display = vimgrep_str,

      start = entry.start,
      finish = entry.finish,
    })
  end

  return results
end

utils.filter_symbols = function(results, opts)
  if opts.symbols == nil then
    return results
  end
  local valid_symbols = vim.tbl_map(string.lower, vim.lsp.protocol.SymbolKind)

  local filtered_symbols = {}
  if type(opts.symbols) == "string" then
    opts.symbols = string.lower(opts.symbols)
    if vim.tbl_contains(valid_symbols, opts.symbols) then
      for _, result in ipairs(results) do
        if string.lower(result.kind) == opts.symbols then
          table.insert(filtered_symbols, result)
        end
      end
    else
      print(string.format("%s is not a valid symbol per `vim.lsp.protocol.SymbolKind`", opts.symbols))
    end
  elseif type(opts.symbols) == "table" then
    opts.symbols = vim.tbl_map(string.lower, opts.symbols)
    local mismatched_symbols = {}
    for _, symbol in ipairs(opts.symbols) do
      if vim.tbl_contains(valid_symbols, symbol) then
        for _, result in ipairs(results) do
          if string.lower(result.kind) == symbol then
            table.insert(filtered_symbols, result)
          end
        end
      else
        table.insert(mismatched_symbols, symbol)
        mismatched_symbols = table.concat(mismatched_symbols, ", ")
        print(string.format("%s are not valid symbols per `vim.lsp.protocol.SymbolKind`", mismatched_symbols))
      end
    end
  else
    print("Please pass filtering symbols as either a string or a list of strings")
    return
  end

  local current_buf = vim.api.nvim_get_current_buf()
  if not vim.tbl_isempty(filtered_symbols) then
    -- filter adequately for workspace symbols
    local filename_to_bufnr = {}
    for _, symbol in ipairs(filtered_symbols) do
      if filename_to_bufnr[symbol.filename] == nil then
        filename_to_bufnr[symbol.filename] = vim.uri_to_bufnr(vim.uri_from_fname(symbol.filename))
      end
      symbol['bufnr'] = filename_to_bufnr[symbol.filename]
    end
    table.sort(filtered_symbols, function(a, b)
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
  return filtered_symbols
  end
  -- only account for string|table as function otherwise already printed message and returned nil
  local symbols = type(opts.symbols) == 'string' and opts.symbols or table.concat(opts.symbols, ', ')
  print(string.format("%s symbol(s) were not part of the query results", symbols))
  return
end

local convert_diagnostic_type = function(severity)
  -- convert from string to int
  if type(severity) == 'string' then
    -- make sure that e.g. error is uppercased to Error
    return vim.lsp.protocol.DiagnosticSeverity[severity:gsub("^%l", string.upper)]
  end
  -- otherwise keep original value, incl. nil
  return severity
end

local filter_diag_severity = function(opts, severity)
  if opts.severity ~= nil then
    return opts.severity == severity
  elseif opts.severity_limit ~= nil then
    return severity <= opts.severity_limit
  elseif opts.severity_bound ~= nil then
    return severity >= opts.severity_bound
  else
    return true
  end
end

utils.diagnostics_to_tbl = function(opts)
  opts = opts or {}
  local items = {}
  local lsp_type_diagnostic = vim.lsp.protocol.DiagnosticSeverity
  local current_buf = vim.api.nvim_get_current_buf()

  opts.severity = convert_diagnostic_type(opts.severity)
  opts.severity_limit = convert_diagnostic_type(opts.severity_limit)
  opts.severity_bound = convert_diagnostic_type(opts.severity_bound)

  local validate_severity = 0
  for _, v in ipairs({opts.severity, opts.severity_limit, opts.severity_bound}) do
    if v ~= nil then
      validate_severity = validate_severity + 1
    end
    if validate_severity > 1 then
      print('Please pass valid severity parameters')
      return {}
    end
  end

  local preprocess_diag = function(diag, bufnr)
    local filename = vim.api.nvim_buf_get_name(bufnr)
    local start = diag.range['start']
    local finish = diag.range['end']
    local row = start.line
    local col = start.character

    local buffer_diag = {
      bufnr = bufnr,
      filename = filename,
      lnum = row + 1,
      col = col + 1,
      start = start,
      finish = finish,
      -- remove line break to avoid display issues
      text = vim.trim(diag.message:gsub("[\n]", "")),
      type = lsp_type_diagnostic[diag.severity] or lsp_type_diagnostic[1]
    }
    return buffer_diag
  end

  local buffer_diags = opts.get_all and vim.lsp.diagnostic.get_all() or
    {[current_buf] = vim.lsp.diagnostic.get(current_buf, opts.client_id)}
  for bufnr, diags in pairs(buffer_diags) do
    for _, diag in ipairs(diags) do
      -- workspace diagnostics may include empty tables for unused bufnr
      if not vim.tbl_isempty(diag) then
        if filter_diag_severity(opts, diag.severity) then
          table.insert(items, preprocess_diag(diag, bufnr))
        end
      end
    end
  end

  -- sort results by bufnr (prioritize cur buf), severity, lnum
  table.sort(items, function(a, b)
    if a.bufnr == b.bufnr then
      if a.type == b.type then
        return a.lnum < b.lnum
      else
        return a.type < b.type
      end
    else
      -- prioritize for current bufnr
      if a.bufnr == current_buf then
        return true
      end
      if b.bufnr == current_buf then
        return false
      end
      return a.bufnr < b.bufnr
    end
  end)

  return items
end

-- TODO: Figure out how to do this... could include in plenary :)
-- NOTE: Don't use this yet. It will segfault sometimes.
--
-- opts.shorten_path and function(value)
--     local result = {
--       valid = true,
--       display = utils.path_shorten(value),
--       ordinal = value,
--       value = value
--     }

--     return result
--   end or nil)
utils.path_shorten = pathlib.shorten

utils.path_tail = (function()
  local os_sep = utils.get_separator()
  local match_string = '[^' .. os_sep .. ']*$'

  return function(path)
    return string.match(path, match_string)
  end
end)()

-- local x = utils.make_default_callable(function(opts)
--   return function()
--     print(opts.example, opts.another)
--   end
-- end, { example = 7, another = 5 })

-- x()
-- x.new { example = 3 }()
function utils.make_default_callable(f, default_opts)
  default_opts = default_opts or {}

  return setmetatable({
    new = function(opts)
      opts = vim.tbl_extend("keep", opts, default_opts)
      return f(opts)
    end,
  }, {
    __call = function()
      local ok, err = pcall(f(default_opts))
      if not ok then
        error(debug.traceback(err))
      end
    end
  })
end

function utils.job_is_running(job_id)
  if job_id == nil then return false end
  return vim.fn.jobwait({job_id}, 0)[1] == -1
end

function utils.buf_delete(bufnr)
  if bufnr == nil then return end

  -- Suppress the buffer deleted message for those with &report<2
  local start_report = vim.o.report
  if start_report < 2 then vim.o.report = 2 end

  if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  if start_report < 2 then vim.o.report = start_report end
end

function utils.max_split(s, pattern, maxsplit)
  pattern = pattern or ' '
  maxsplit = maxsplit or -1

  local t = {}

  local curpos = 0
  while maxsplit ~= 0 and curpos < #s do
    local found, final = string.find(s, pattern, curpos, false)
    if found ~= nil then
      local val = string.sub(s, curpos, found - 1)

      if #val > 0 then
        maxsplit = maxsplit - 1
        table.insert(t, val)
      end

      curpos = final + 1
    else
      table.insert(t, string.sub(s, curpos))
      break
      -- curpos = curpos + 1
    end

    if maxsplit == 0 then
      table.insert(t, string.sub(s, curpos))
    end
  end

  return t
end


function utils.data_directory()
  local sourced_file = require('plenary.debug_utils').sourced_filepath()
  local base_directory = vim.fn.fnamemodify(sourced_file, ":h:h:h")

  return base_directory .. pathlib.separator .. 'data' .. pathlib.separator
end

function utils.display_termcodes(str)
  return str:gsub(string.char(9), "<TAB>"):gsub("", "<C-F>"):gsub(" ", "<Space>")
end

function utils.get_os_command_output(cmd, cwd)
  if type(cmd) ~= "table" then
    print('Telescope: [get_os_command_output]: cmd has to be a table')
    return {}
  end
  local command = table.remove(cmd, 1)
  local stderr = {}
  local stdout, ret = Job:new({ command = command, args = cmd, cwd = cwd, on_stderr = function(_, data)
    table.insert(stderr, data)
  end }):sync()
  return stdout, ret, stderr
end

utils.strdisplaywidth = function()
  error("strdisplaywidth deprecated. please use plenary.strings.strdisplaywidth")
end

utils.utf_ptr2len = function()
  error("utf_ptr2len deprecated. please use plenary.strings.utf_ptr2len")
end

utils.strcharpart = function()
  error("strcharpart deprecated. please use plenary.strings.strcharpart")
end

utils.align_str = function()
  error("align_str deprecated. please use plenary.strings.align_str")
end

utils.transform_devicons = (function()
  if has_devicons then
    if not devicons.has_loaded() then
      devicons.setup()
    end

    return function(filename, display, disable_devicons)
      local conf = require('telescope.config').values
      if disable_devicons or not filename then
        return display
      end

      local icon, icon_highlight = devicons.get_icon(filename, string.match(filename, '%a+$'), { default = true })
      local icon_display = (icon or ' ') .. ' ' .. display

      if conf.color_devicons then
        return icon_display, icon_highlight
      else
        return icon_display
      end
    end
  else
    return function(_, display, _)
      return display
    end
  end
end)()

utils.get_devicons = (function()
  if has_devicons then
    if not devicons.has_loaded() then
      devicons.setup()
    end

    return function(filename, disable_devicons)
      local conf = require('telescope.config').values
      if disable_devicons or not filename then
        return ''
      end

      local icon, icon_highlight = devicons.get_icon(filename, string.match(filename, '%a+$'), { default = true })
      if conf.color_devicons then
        return icon, icon_highlight
      else
        return icon
      end
    end
  else
    return function(_, _)
      return ''
    end
  end
end)()

return utils
