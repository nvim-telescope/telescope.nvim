---@brief
--- Utilities for writing telescope pickers

local api = vim.api

local log = require "telescope.log"

local get_status = require("telescope.state").get_status

local utils = {}

utils.iswin = vim.fn.has "win32" == 1
-- Paths are normalized to forward slashes where they enter telescope (see `utils.normalize_sep`), so
-- this is "/" on every platform. Kept for extensions.
utils.pathsep = "/"

-- Convert backslashes to forward slashes and capitalize the drive letter on Windows, like
-- `vim.fs.normalize()` but cheap enough for every entry (`win` overrides the platform check, for
-- tests). On other platforms, backslashes are valid in file names and are kept.
utils.normalize_sep = function(path, win)
  if win == nil then
    win = utils.iswin
  end
  if not win then
    return path
  end
  return (path:gsub("\\", "/"):gsub("^%a:", string.upper))
end

---@param t table
---@return table
utils.flatten = function(t)
  return vim.iter(t):flatten():totable()
end

local truncate = function(str, len, dots, direction)
  if vim.fn.strdisplaywidth(str) <= len then
    return str
  end
  local start = direction > 0 and 0 or str:len()
  local current = 0
  local result = ""
  local len_of_dots = vim.fn.strdisplaywidth(dots)
  local concat = function(a, b, dir)
    if dir > 0 then
      return a .. b
    else
      return b .. a
    end
  end
  while true do
    local part = vim.fn.strcharpart(str, start, 1)
    current = current + vim.fn.strdisplaywidth(part)
    if (current + len_of_dots) > len then
      result = concat(result, dots, direction)
      break
    end
    result = concat(result, part, direction)
    start = start + direction
  end
  return result
end

-- Truncate `str` to display width `len`, marking the cut with `dots` (default "…").
-- `direction`: 1 cuts at the end (default), -1 at the start, 0 in the middle.
-- (Re-exported as the public `entry_display.truncate`.)
utils.truncate = function(str, len, dots, direction)
  dots = dots or "…"
  direction = direction or 1
  if direction ~= 0 then
    return truncate(str, len, dots, direction)
  else
    if vim.fn.strdisplaywidth(str) <= len then
      return str
    end
    local len1 = math.floor((len + vim.fn.strdisplaywidth(dots)) / 2)
    local s1 = truncate(str, len1, dots, 1)
    local len2 = len - vim.fn.strdisplaywidth(s1) + vim.fn.strdisplaywidth(dots)
    local s2 = truncate(str, len2, dots, -1)
    return s1 .. s2:sub(dots:len() + 1)
  end
end

--- Hybrid of `vim.fn.expand()` and `vim.fs.normalize()`
---
--- Paths starting with '%', '#' or '<' are expanded with `vim.fn.expand()`.
--- Otherwise avoids using `vim.fn.expand()` due to its overly aggressive
--- expansion behavior which can sometimes lead to errors or the creation of
--- non-existent paths when dealing with valid absolute paths.
---
--- The result is normalized with `vim.fs.normalize()`: '~' and environment
--- variables are expanded, `.` and `..` are resolved, redundant and trailing
--- slashes are removed (except for root paths, e.g. `/` or `C:/`), and on
--- Windows backslashes are converted to forward slashes. URIs are returned
--- unchanged.
---
---@param path string
---@return string
utils.path_expand = function(path)
  vim.validate("path", path, "string")

  if utils.is_uri(path) then
    return path
  end

  if path:match "^[%%#<]" then
    path = vim.fn.expand(path)
  end

  return vim.fs.normalize(path, { win = utils.iswin })
end

utils.cycle = function(i, n)
  return i % n == 0 and n or i % n
end

utils.get_lazy_default = function(x, defaulter, ...)
  if x == nil then
    return defaulter(...)
  else
    return x
  end
end

utils.repeated_table = function(n, val)
  local empty_lines = {}
  for _ = 1, n do
    table.insert(empty_lines, val)
  end
  return empty_lines
end

utils.filter_symbols = function(results, opts, post_filter)
  local has_ignore = opts.ignore_symbols ~= nil
  local has_symbols = opts.symbols ~= nil

  if has_symbols and has_ignore then
    utils.notify("filter_symbols", {
      msg = "Either opts.symbols or opts.ignore_symbols, can't process opposing options at the same time!",
      level = "ERROR",
    })
    return {}
  elseif not (has_ignore or has_symbols) then
    return results
  end

  local key = has_ignore and "ignore_symbols" or "symbols"
  if type(opts[key]) == "string" then
    opts[key] = { opts[key] }
  end
  if type(opts[key]) ~= "table" then
    utils.notify("filter_symbols", {
      msg = has_ignore and "Please pass ignore_symbols as either a string or a list of strings"
        or "Please pass filtering symbols as either a string or a list of strings",
      level = "ERROR",
    })
    return {}
  end

  opts[key] = vim.tbl_map(string.lower, opts[key])
  local filtered_symbols = vim.tbl_filter(function(item)
    return vim.tbl_contains(opts[key], string.lower(item.kind)) ~= has_ignore
  end, results)

  if type(post_filter) == "function" then
    filtered_symbols = post_filter(filtered_symbols)
  end

  if not vim.tbl_isempty(filtered_symbols) then
    return filtered_symbols
  end

  utils.notify("filter_symbols", {
    msg = string.format(
      has_ignore and "%s ignore_symbol(s) have removed everything from the query result"
        or "%s symbol(s) were not part of the query results",
      table.concat(opts[key], ", ")
    ),
    level = "WARN",
  })
  return {}
end

local path_filename_first = function(path, reverse_directories)
  local pathsep = "/"
  local dirs = vim.split(path, pathsep)
  local filename

  if reverse_directories then
    dirs = utils.reverse_table(dirs)
    filename = table.remove(dirs, 1)
  else
    filename = table.remove(dirs, #dirs)
  end

  local tail = table.concat(dirs, pathsep)
  -- Trim prevents a top-level filename to have a trailing white space
  local transformed_path = vim.trim(filename .. " " .. tail)
  local path_style = { { { #filename, #transformed_path }, "TelescopeResultsComment" } }

  return transformed_path, path_style
end

local calc_result_length = function(truncate_len)
  local status = get_status(api.nvim_get_current_buf())
  local len = api.nvim_win_get_width(status.layout.results.winid) - status.picker.selection_caret:len() - 2
  return type(truncate_len) == "number" and len - truncate_len or len
end

local path_truncate = function(path, truncate_len, opts)
  if opts.__length == nil then
    opts.__length = calc_result_length(truncate_len)
  end
  if opts.__prefix == nil then
    opts.__prefix = 0
  end
  return utils.truncate(path, opts.__length - opts.__prefix, nil, -1)
end

local path_shorten = function(filename, len, exclude)
  len = len or 1
  exclude = exclude or { -1 }

  -- keep empty parts (leading `/`, `//`, trailing `/`) so they are joined back unchanged
  local parts = vim.split(filename, "/")
  local count = 0
  for _, part in ipairs(parts) do
    if part ~= "" then
      count = count + 1
    end
  end

  local exc = {}
  for _, v in pairs(exclude) do
    exc[v < 0 and v + count + 1 or v] = true
  end

  local i = 0
  for k, part in ipairs(parts) do
    if part ~= "" then
      i = i + 1
      if not exc[i] then
        parts[k] = part:sub(1, len)
      end
    end
  end

  return table.concat(parts, "/")
end

-- Pure Lua (safe in fast events): absolute Unix paths, Windows drive and UNC paths
utils.is_absolute = function(path)
  if path:sub(1, 1) == "/" then
    return true
  end
  return utils.iswin and (path:match "^%a:[/\\]" ~= nil or path:sub(1, 2) == "\\\\") or false
end

-- Make an absolute `path` relative to `cwd` (default: current working directory).
-- URIs, relative paths, and paths outside of `cwd` are returned unchanged.
utils.make_relative = function(path, cwd)
  path = utils.normalize_sep(path)
  if utils.is_uri(path) or not utils.is_absolute(path) then
    return path
  end
  return vim.fs.relpath(cwd or vim.uv.cwd(), path) or path
end

-- Display form of a file name (as plenary's `Path:normalize(cwd)`): relative to `cwd` if inside,
-- `~/...` if inside the home directory, otherwise (and for URIs) unchanged.
utils.display_path = function(path, cwd)
  path = utils.normalize_sep(path)
  local name = utils.make_relative(path, cwd)
  local home = utils.normalize_sep(vim.uv.os_homedir()) .. "/"
  if name == path and vim.startswith(name, home) then
    name = "~/" .. name:sub(#home + 1)
  end
  return name
end

local path_rel = function(path, opts)
  local cwd
  if opts.cwd then
    cwd = opts.cwd
    if not vim.in_fast_event() then
      cwd = utils.path_expand(opts.cwd)
    end
  end
  return utils.make_relative(path, cwd)
end

-- IMPORTANT: This function should have been a local function as it's only used
-- in this file, but the code was already exported a long time ago. By making it
-- local we would potential break consumers of this method.
utils.path_smart = (function()
  local paths = {}
  local pathsep = "/"
  return function(filepath)
    filepath = utils.normalize_sep(filepath)
    local final = filepath
    if #paths ~= 0 then
      local dirs = vim.split(filepath, pathsep)
      local max = 1
      for _, p in pairs(paths) do
        if #p > 0 and p ~= filepath then
          local _dirs = vim.split(p, pathsep)
          for i = 1, math.min(#dirs, #_dirs) do
            if (dirs[i] ~= _dirs[i]) and i > max then
              max = i
              break
            end
          end
        end
      end
      if #dirs ~= 0 then
        if max == 1 and #dirs >= 2 then
          max = #dirs - 2
        end
        final = ""
        for k, v in pairs(dirs) do
          if k >= max - 1 then
            final = final .. (#final > 0 and pathsep or "") .. v
          end
        end
      end
    end
    if not paths[filepath] then
      paths[filepath] = ""
      table.insert(paths, filepath)
    end
    if final and final ~= filepath then
      return ".." .. pathsep .. final
    else
      return filepath
    end
  end
end)()

-- Also accepts backslashes on Windows (extensions may pass native paths)
utils.path_tail = function(path)
  for i = #path, 1, -1 do
    local c = path:byte(i)
    if c == 47 or (c == 92 and utils.iswin) then -- `/` or `\`
      return path:sub(i + 1, -1)
    end
  end
  return path
end

utils.is_path_hidden = function(opts, path_display)
  path_display = path_display or vim.nonnil(opts.path_display, require("telescope.config").values.path_display)

  return path_display == nil
    or path_display == "hidden"
    or type(path_display) == "table" and (vim.tbl_contains(path_display, "hidden") or path_display.hidden)
end

-- Whether `filename` is a URI, as in Neovim's `path_with_url()`: an RFC 3986 scheme followed by `:/`
-- ("fugitive:///a", "deno:/a", "term://…"), but not a drive letter ("C:/a") and not "mailto:a".
utils.is_uri = function(filename)
  local scheme = filename:match "^(%a[%w+.-]*):/"
  return scheme ~= nil and #scheme > 1 and not scheme:match "[+.-]$"
end

--- Transform path is a util function that formats a path based on path_display
--- found in `opts` or the default value from config.
--- It is meant to be used in make_entry to have a uniform interface for
--- builtins as well as extensions utilizing the same user configuration
--- Note: It is only supported inside `make_entry`/`make_display` the use of
--- this function outside of telescope might yield to undefined behavior and will
--- not be addressed by us
---@param opts table: The opts the users passed into the picker. Might contains a path_display key
---@param path string|nil: The path that should be formatted
---@return string: path to be displayed
---@return table: The transformed path ready to be displayed with the styling
utils.transform_path = function(opts, path)
  if path == nil then
    return "", {}
  end
  if utils.is_uri(path) then
    return path, {}
  end
  path = utils.normalize_sep(path)

  ---@type fun(opts:table, path: string): string, table?
  local path_display = vim.nonnil(opts.path_display, require("telescope.config").values.path_display)

  local transformed_path = path
  local path_style = {}

  if type(path_display) == "function" then
    local custom_transformed_path, custom_path_style = path_display(opts, transformed_path)
    return custom_transformed_path, custom_path_style or path_style
  elseif utils.is_path_hidden(nil, path_display) then
    return "", path_style
  elseif type(path_display) == "table" then
    if vim.tbl_contains(path_display, "tail") or path_display.tail then
      return utils.path_tail(transformed_path), path_style
    end

    if not vim.tbl_contains(path_display, "absolute") and not path_display.absolute then
      transformed_path = path_rel(transformed_path, opts)
    end

    if vim.tbl_contains(path_display, "smart") or path_display.smart then
      transformed_path = utils.path_smart(transformed_path)
    end

    if vim.tbl_contains(path_display, "shorten") or path_display["shorten"] ~= nil then
      local length
      local exclude = nil

      if type(path_display["shorten"]) == "table" then
        local shorten = path_display["shorten"]
        length = shorten.len
        exclude = shorten.exclude
      else
        length = type(path_display["shorten"]) == "number" and path_display["shorten"]
      end

      transformed_path = path_shorten(transformed_path, length, exclude)
    end

    if vim.tbl_contains(path_display, "truncate") or path_display.truncate then
      transformed_path = path_truncate(transformed_path, path_display.truncate, opts)
    end

    if vim.tbl_contains(path_display, "filename_first") or path_display["filename_first"] ~= nil then
      local reverse_directories = false

      if type(path_display["filename_first"]) == "table" then
        local filename_first_opts = path_display["filename_first"]

        if filename_first_opts.reverse_directories == nil or filename_first_opts.reverse_directories == false then
          reverse_directories = false
        else
          reverse_directories = filename_first_opts.reverse_directories
        end
      end

      transformed_path, path_style = path_filename_first(transformed_path, reverse_directories)
    end

    return transformed_path, path_style
  else
    log.warn("`path_display` must be either a function or a table.", "See `:help telescope.defaults.path_display.")
    return transformed_path, path_style
  end
end

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
    end,
  })
end

function utils.job_is_running(job_id)
  if job_id == nil then
    return false
  end
  return vim.fn.jobwait({ job_id }, 0)[1] == -1
end

function utils.buf_delete(bufnr)
  if bufnr and api.nvim_buf_is_valid(bufnr) and api.nvim_buf_is_loaded(bufnr) then
    api.nvim_buf_delete(bufnr, { force = true })
  end
end

function utils.win_delete(name, win_id, force, bdelete)
  if win_id == nil or not api.nvim_win_is_valid(win_id) then
    return
  end

  local bufnr = api.nvim_win_get_buf(win_id)
  if bdelete then
    utils.buf_delete(bufnr)
  end

  if not api.nvim_win_is_valid(win_id) then
    return
  end

  if not pcall(api.nvim_win_close, win_id, force) then
    log.trace("Unable to close window: ", name, "/", win_id)
  end
end

function utils.max_split(s, pattern, maxsplit)
  pattern = pattern or " "
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

function utils.buffer_dir()
  return vim.fn.expand "%:p:h"
end

function utils.display_termcodes(str)
  return str:gsub(string.char(9), "<TAB>"):gsub("", "<C-F>"):gsub(" ", "<Space>")
end

-- Split command output into lines (without `\r`), without a trailing empty line; `{}` for no output.
utils.output_lines = function(s)
  s = (s or ""):gsub("\r", "")
  if s == "" then
    return {}
  end
  return vim.split((s:gsub("\n$", "")), "\n", { plain = true })
end

function utils.get_os_command_output(cmd, cwd)
  if type(cmd) ~= "table" then
    utils.notify("get_os_command_output", {
      msg = "cmd has to be a table",
      level = "ERROR",
    })
    return {}
  end
  -- on timeout (5 s), the process is stopped and the exit code is 124
  local result = vim.system(cmd, { cwd = cwd }):wait(5000)
  return utils.output_lines(result.stdout), result.code, utils.output_lines(result.stderr)
end

function utils.win_set_buf_noautocmd(win, buf)
  local save_ei = vim.o.eventignore
  vim.o.eventignore = "all"
  local ok, err = pcall(api.nvim_win_set_buf, win, buf)
  vim.o.eventignore = save_ei
  if not ok then
    error(err, 0)
  end
end

local load_once = function(f)
  local resolved = nil
  return function(...)
    if resolved == nil then
      resolved = f()
    end

    return resolved(...)
  end
end

-- IMPORTANT: This function should have been a local function as it's only used
-- in this file, but the code was already exported a long time ago. By making it
-- local we would potential break consumers of this method.
utils.file_extension = function(filename)
  local parts = vim.split(filename, "%.")
  -- this check enables us to get multi-part extensions, like *.test.js for example
  if #parts > 2 then
    return table.concat(vim.list_slice(parts, #parts - 1), ".")
  else
    return table.concat(vim.list_slice(parts, #parts), ".")
  end
end

utils.transform_devicons = function(filename, display, disable_devicons)
  local icon, icon_highlight = utils.get_devicons(filename, disable_devicons)
  if icon == "" then -- no devicons, disabled, or no file name
    return display
  end
  icon = icon or " "
  return icon .. " " .. (display or ""), icon_highlight, icon
end

utils.get_devicons = load_once(function()
  local has_devicons, devicons = pcall(require, "nvim-web-devicons")

  if has_devicons then
    if not devicons.has_loaded() then
      devicons.setup()
    end

    return function(filename, disable_devicons)
      local conf = require("telescope.config").values
      if disable_devicons or not filename then
        return ""
      end

      local basename = utils.path_tail(filename)
      local icon, icon_highlight = devicons.get_icon(basename, utils.file_extension(basename), { default = false })
      if not icon then
        icon, icon_highlight = devicons.get_icon(basename, nil, { default = true })
      end
      if conf.color_devicons then
        return icon, icon_highlight
      else
        return icon, nil
      end
    end
  else
    return function(_, _)
      return ""
    end
  end
end)

--- Telescope Wrapper around vim.notify
---@param funname string: name of the function that will be
---@param opts table: opts.level string, opts.msg string, opts.once bool
utils.notify = function(funname, opts)
  opts.once = vim.nonnil(opts.once, false)
  local level = vim.log.levels[opts.level]
  if not level then
    error("Invalid error level", 2)
  end
  local notify_fn = opts.once and vim.notify_once or vim.notify
  notify_fn(string.format("[telescope.%s]: %s", funname, opts.msg), level, {
    title = "telescope.nvim",
  })
end

utils.__warn_no_selection = function(name)
  utils.notify(name, {
    msg = "Nothing currently selected",
    level = "WARN",
  })
end

--- Generate git command optionally with git env variables
---@param args string[]
---@param opts? table
---@return string[]
-- Run `command` (e.g. "edit", "tab drop", "leftabove vnew") on `filename`, without expanding special
-- characters (`%`, `#`, `$VAR`, `~`, wildcards): `fnameescape()` does not escape all of them on
-- Windows. `:drop` takes a file list and expands it regardless, so it still needs `fnameescape()`.
utils.edit_file = function(command, filename)
  local cmd = api.nvim_parse_cmd(command, {})
  if cmd.cmd == "drop" then
    vim.cmd(string.format("%s %s", command, vim.fn.fnameescape(filename)))
    return
  end
  cmd.args = { filename }
  cmd.magic = { file = false, bar = false }
  api.nvim_cmd(cmd, {})
end

utils.__git_command = function(args, opts)
  opts = opts or {}

  local _args = { "git" }
  if opts.gitdir then
    vim.list_extend(_args, { "--git-dir", opts.gitdir })
  end
  if opts.toplevel then
    vim.list_extend(_args, { "--work-tree", opts.toplevel })
  end

  return vim.list_extend(_args, args)
end

utils.list_find = function(func, list)
  for i, v in ipairs(list) do
    if func(v, i, list) then
      return i, v
    end
  end
end

--- Takes the path and parses optional cursor location `$file:$line:$column`
--- If line or column not present `0` returned.
---@param path string
---@return string path
---@return integer? lnum
---@return integer? col
utils.__separate_file_path_location = function(path)
  local file, lnum, col = path:match "^(.-):%s*(%d+)%s*:%s*(%d+)%s*:*$"
  if file then
    return file, tonumber(lnum), tonumber(col)
  end
  file, lnum = path:match "^(.-):%s*(%d+)%s*:*$"
  if file then
    return file, tonumber(lnum), 0
  end
  return (path:gsub(":+$", "")), nil, nil
end

local function add_offset(offset, obj)
  return { obj[1] + offset, obj[2] + offset }
end

utils.merge_styles = function(style1, style2, offset)
  for _, item in ipairs(style2) do
    item[1] = add_offset(offset, item[1])
    table.insert(style1, item)
  end

  return style1
end

-- IMPORTANT: This function should have been a local function as it's only used
-- in this file, but the code was already exported a long time ago. By making it
-- local we would potential break consumers of this method.
utils.reverse_table = function(input_table)
  local temp_table = {}
  for index = 0, #input_table do
    temp_table[#input_table - index] = input_table[index + 1] -- Reverses the order
  end
  return temp_table
end

utils.split_lines = function(s, opts)
  return vim.split(s, "\r?\n", opts)
end

-- Contents of the file `filename` (errors if it can't be read).
function utils.read_file(filename)
  local file = assert(io.open(filename, "r"))
  local data = file:read "*a"
  file:close()
  return data
end

return utils
