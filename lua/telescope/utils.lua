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

utils.diagnostics_to_tbl = function(opts)
  opts = opts or {}
  local items = {}
  local current_buf = vim.api.nvim_get_current_buf()
  local lsp_type_diagnostic = {[1] = "Error", [2] = "Warning", [3] = "Information", [4] = "Hint"}

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
    table.sort(buffer_diag, function(a, b) return a.lnum < b.lnum end)
    return buffer_diag
  end

  local buffer_diags = opts.get_all and vim.lsp.diagnostic.get_all() or
    {[current_buf] = vim.lsp.diagnostic.get(current_buf, opts.client_id)}
  for bufnr, diags in pairs(buffer_diags) do
    for _, diag in pairs(diags) do
      -- workspace diagnostics may include empty tables for unused bufnr
      if not vim.tbl_isempty(diag) then
        table.insert(items, preprocess_diag(diag, bufnr))
      end
    end
  end
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

utils.strdisplaywidth = (function()
  if jit and pathlib.separator ~= '\\' then
    local ffi = require('ffi')
    ffi.cdef[[
      typedef unsigned char char_u;
      int linetabsize_col(int startcol, char_u *s);
    ]]

    return function(str, col)
      local startcol = col or 0
      local s = ffi.new('char[?]', #str + 1)
      ffi.copy(s, str)
      return ffi.C.linetabsize_col(startcol, s) - startcol
    end
  else
    return function(str, col)
      return #str - (col or 0)
    end
  end
end)()

utils.utf_ptr2len = (function()
  if jit and pathlib.separator ~= '\\' then
    local ffi = require('ffi')
    ffi.cdef[[
      typedef unsigned char char_u;
      int utf_ptr2len(const char_u *const p);
    ]]

    return function(str)
      local c_str = ffi.new('char[?]', #str + 1)
      ffi.copy(c_str, str)
      return ffi.C.utf_ptr2len(c_str)
    end
  else
    return function(str)
      return str == '' and 0 or 1
    end
  end
end)()

function utils.strcharpart(str, nchar, charlen)
  local nbyte = 0
  if nchar > 0 then
    while nchar > 0 and nbyte < #str do
      nbyte = nbyte + utils.utf_ptr2len(str:sub(nbyte + 1))
      nchar = nchar - 1
    end
  else
    nbyte = nchar
  end

  local len = 0
  if charlen then
    while charlen > 0 and nbyte + len < #str do
      local off = nbyte + len
      if off < 0 then
        len = len + 1
      else
        len = len + utils.utf_ptr2len(str:sub(off + 1))
      end
      charlen = charlen - 1
    end
  else
    len = #str - nbyte
  end

  if nbyte < 0 then
    len = len + nbyte
    nbyte = 0
  elseif nbyte > #str then
    nbyte = #str
  end
  if len < 0 then
    len = 0
  elseif nbyte + len > #str then
    len = #str - nbyte
  end

  return str:sub(nbyte + 1, nbyte + len)
end

utils.align_str = function(string, width, right_justify)
  local str_len = utils.strdisplaywidth(string)
  return right_justify
    and string.rep(" ", width - str_len)..string
    or string..string.rep(" ", width - str_len)
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
