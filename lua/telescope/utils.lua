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

function utils.get_os_command_output(cmd)
  if type(cmd) ~= "table" then
    print('Telescope: [get_os_command_output]: cmd has to be a table')
    return {}
  end
  local command = table.remove(cmd, 1)
  return Job:new({ command = command, args = cmd }):sync()
end

utils.strdisplaywidth = (function()
  if jit then
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
  if jit then
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


function utils.get_visual_pos(exit_visual_mode)
    exit_visual_mode = exit_visual_mode or true

    -- get {start: 'v', end: curpos} of visual selection 0-indexed
    local line_v, column_v = unpack(vim.fn.getpos("v"), 2, 3)
    local line_cur, column_cur = unpack(vim.fn.getcurpos(), 2, 3)

    if exit_visual_mode then
      vim.cmd [[normal :esc<CR>]]
    end

    -- backwards visual selection
    if line_v > line_cur then
        line_cur, line_v = line_v, line_cur
    end
    if column_v > column_cur then
        column_cur, column_v = column_v, column_cur
    end
    return line_v, column_v, line_cur, column_cur
end


-- Recursively resolve beginning or ending byte column for multi-width characters
--  Example: multi-width Japanese Zenkaku, see change in columns from left to right char
--  全角
-- @param line string: buffer line
-- @param byte_col integer: initial byte column
-- @param offset integer: resolver char border towards char beginning (-1) or char end (+1)
-- return byte_col integer: byte column of char beginning or end
function utils.resolve_col(line, byte_col, offset)
    local utf_start, _ = vim.str_utfindex(line, math.min(byte_col, #line))
    local utf_start_offset, _ = vim.str_utfindex(line, math.min(byte_col + offset, #line))
    if utf_start == utf_start_offset and byte_col + offset <= #line then
        return utils.resolve_col(line, byte_col + offset, offset)
    else
        return byte_col
    end
end

function utils.get_visual_selection(delimiter, trim, exit_visual_mode)
    delimiter = delimiter or ' '
    trim = trim or true
    exit_visual_mode = exit_visual_mode or ' '

    local mode = vim.api.nvim_get_mode().mode
    local line_start, column_start, line_end, column_end = utils.get_visual_pos(exit_visual_mode)
    local lines = vim.api.nvim_buf_get_lines(0, line_start - 1, line_end, false)

    local concat = {}
    local first_line = 1
    local last_line = line_end - (line_start - 1)

    if first_line == last_line or mode == '' then
        -- get difference in columns, inclusive
        column_end =  column_end - column_start + 1
    end
    for row=first_line,last_line do
        local line = lines[row]
        if mode ~= 'V' then
            if row == first_line or mode == '' then
                -- Recursively get first byte index of utf char for initial byte column selection
                --  Example: multi-width Japanese Zenkaku, see change in columns from left to right char
                --  全角
                local byte_col = utils.resolve_col(line, column_start, -1)
                line = line:sub(byte_col)
            end
            if row == last_line or mode == '' then
                -- Recursively get last byte index of utf char for last byte column selection
                local byte_col = utils.resolve_col(line, column_end, 1)
                if mode == '' then
                    -- if column was resolved and not initial char did not surpass column end, extra character required
                    local char_begin_col = utils.resolve_col(line, byte_col, -1)
                    if char_begin_col < column_end and byte_col >= column_end and row ~= last_line then
                        byte_col = utils.resolve_col(line, byte_col+1, 1)
                    end
                end
                -- math.min(byte_col, #line) covers block mode edge case: selection over relative line ends
                -- |--| <-- indicates selection by row
                -- 全角
                -- |-----------|
                -- 全角全角全角
                -- + covers potential end-of-line selection
                line = line:sub(1, math.min(byte_col, #line))
            end
        end
        if trim then
            line = vim.trim(line)
        end
        table.insert(concat, line)
    end
    return table.concat(concat, delimiter)
end

return utils
