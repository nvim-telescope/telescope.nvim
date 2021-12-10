local Path = require "plenary.path"
local Job = require "plenary.job"

local log = require "telescope.log"

local truncate = require("plenary.strings").truncate
local get_status = require("telescope.state").get_status

local utils = {}

utils.get_separator = function()
  return Path.path.sep
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
  end,
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
    local vimgrep_str = entry.vimgrep_str
      or string.format(
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
    print "Please pass filtering symbols as either a string or a list of strings"
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
      symbol["bufnr"] = filename_to_bufnr[symbol.filename]
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
  local symbols = type(opts.symbols) == "string" and opts.symbols or table.concat(opts.symbols, ", ")
  print(string.format("%s symbol(s) were not part of the query results", symbols))
end

utils.path_smart = (function()
  local paths = {}
  return function(filepath)
    local final = filepath
    if #paths ~= 0 then
      local dirs = vim.split(filepath, "/")
      local max = 1
      for _, p in pairs(paths) do
        if #p > 0 and p ~= filepath then
          local _dirs = vim.split(p, "/")
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
            final = final .. (#final > 0 and "/" or "") .. v
          end
        end
      end
    end
    if not paths[filepath] then
      paths[filepath] = ""
      table.insert(paths, filepath)
    end
    if final and final ~= filepath then
      return "../" .. final
    else
      return filepath
    end
  end
end)()

utils.path_tail = (function()
  local os_sep = utils.get_separator()
  local match_string = "[^" .. os_sep .. "]*$"

  return function(path)
    return string.match(path, match_string)
  end
end)()

utils.is_path_hidden = function(opts, path_display)
  path_display = path_display or utils.get_default(opts.path_display, require("telescope.config").values.path_display)

  return path_display == nil
    or path_display == "hidden"
    or type(path_display) ~= "table"
    or vim.tbl_contains(path_display, "hidden")
    or path_display.hidden
end

local is_uri = function(filename)
  return string.match(filename, "^%w+://") ~= nil
end

local calc_result_length = function(truncate_len)
  local status = get_status(vim.api.nvim_get_current_buf())
  local len = vim.api.nvim_win_get_width(status.results_win) - status.picker.selection_caret:len() - 2
  return type(truncate_len) == "number" and len - truncate_len or len
end

utils.transform_path = function(opts, path)
  if is_uri(path) then
    return path
  end

  local path_display = utils.get_default(opts.path_display, require("telescope.config").values.path_display)

  local transformed_path = path

  if type(path_display) == "function" then
    return path_display(opts, transformed_path)
  elseif utils.is_path_hidden(nil, path_display) then
    return ""
  elseif type(path_display) == "table" then
    if vim.tbl_contains(path_display, "tail") or path_display.tail then
      transformed_path = utils.path_tail(transformed_path)
    elseif vim.tbl_contains(path_display, "smart") or path_display.smart then
      transformed_path = utils.path_smart(transformed_path)
    else
      if not vim.tbl_contains(path_display, "absolute") or path_display.absolute == false then
        local cwd
        if opts.cwd then
          cwd = opts.cwd
          if not vim.in_fast_event() then
            cwd = vim.fn.expand(opts.cwd)
          end
        else
          cwd = vim.loop.cwd()
        end
        transformed_path = Path:new(transformed_path):make_relative(cwd)
      end

      if vim.tbl_contains(path_display, "shorten") or path_display["shorten"] ~= nil then
        if type(path_display["shorten"]) == "table" then
          local shorten = path_display["shorten"]
          transformed_path = Path:new(transformed_path):shorten(shorten.len, shorten.exclude)
        else
          transformed_path = Path:new(transformed_path):shorten(path_display["shorten"])
        end
      end
      if vim.tbl_contains(path_display, "truncate") or path_display.truncate then
        if opts.__length == nil then
          opts.__length = calc_result_length(path_display.truncate)
        end
        transformed_path = truncate(transformed_path, opts.__length, nil, -1)
      end
    end

    return transformed_path
  else
    log.warn("`path_display` must be either a function or a table.", "See `:help telescope.defaults.path_display.")
    return transformed_path
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
  if bufnr == nil then
    return
  end

  -- Suppress the buffer deleted message for those with &report<2
  local start_report = vim.o.report
  if start_report < 2 then
    vim.o.report = 2
  end

  if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  if start_report < 2 then
    vim.o.report = start_report
  end
end

function utils.win_delete(name, win_id, force, bdelete)
  if win_id == nil or not vim.api.nvim_win_is_valid(win_id) then
    return
  end

  local bufnr = vim.api.nvim_win_get_buf(win_id)
  if bdelete then
    utils.buf_delete(bufnr)
  end

  if not vim.api.nvim_win_is_valid(win_id) then
    return
  end

  if not pcall(vim.api.nvim_win_close, win_id, force) then
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

function utils.data_directory()
  local sourced_file = require("plenary.debug_utils").sourced_filepath()
  local base_directory = vim.fn.fnamemodify(sourced_file, ":h:h:h")

  return Path:new({ base_directory, "data" }):absolute() .. Path.path.sep
end

function utils.buffer_dir()
  return vim.fn.expand "%:p:h"
end

function utils.display_termcodes(str)
  return str:gsub(string.char(9), "<TAB>"):gsub("", "<C-F>"):gsub(" ", "<Space>")
end

function utils.get_os_command_output(cmd, cwd)
  if type(cmd) ~= "table" then
    print "Telescope: [get_os_command_output]: cmd has to be a table"
    return {}
  end
  local command = table.remove(cmd, 1)
  local stderr = {}
  local stdout, ret = Job
    :new({
      command = command,
      args = cmd,
      cwd = cwd,
      on_stderr = function(_, data)
        table.insert(stderr, data)
      end,
    })
    :sync()
  return stdout, ret, stderr
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

utils.transform_devicons = load_once(function()
  local has_devicons, devicons = pcall(require, "nvim-web-devicons")

  if has_devicons then
    if not devicons.has_loaded() then
      devicons.setup()
    end

    return function(filename, display, disable_devicons)
      local conf = require("telescope.config").values
      if disable_devicons or not filename then
        return display
      end

      local icon, icon_highlight = devicons.get_icon(filename, string.match(filename, "%a+$"), { default = true })
      local icon_display = (icon or " ") .. " " .. (display or "")

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
end)

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

      local icon, icon_highlight = devicons.get_icon(filename, string.match(filename, "%a+$"), { default = true })
      if conf.color_devicons then
        return icon, icon_highlight
      else
        return icon
      end
    end
  else
    return function(_, _)
      return ""
    end
  end
end)

return utils
