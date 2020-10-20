local has_devicons, devicons = pcall(require, 'nvim-web-devicons')

local path = require('telescope.path')
local utils = require('telescope.utils')

local get_default = utils.get_default

local make_entry = {}

local transform_devicons
if has_devicons then
  transform_devicons = function(filename, display, disable_devicons)
    if disable_devicons or not filename then
      return display
    end

    local icon_display = (devicons.get_icon(filename, string.match(filename, '%a+$')) or ' ') .. ' ' .. display

    return icon_display
  end
else
  transform_devicons = function(_, display, _)
    return display
  end
end

do
  local lookup_keys = {
    display = 1,
    ordinal = 1,
    value = 1,
  }

  local mt_string_entry = {
    __index = function(t, k)
      return rawget(t, rawget(lookup_keys, k))
    end
  }

  function make_entry.gen_from_string()
    return function(line)
      return setmetatable({
        line,
      }, mt_string_entry)
    end
  end
end

do
  local lookup_keys = {
    ordinal = 1,
    value = 1,
    filename = 1,
    cwd = 2,
  }

  function make_entry.gen_from_file(opts)
    opts = opts or {}

    local cwd = vim.fn.expand(opts.cwd or vim.fn.getcwd())

    local disable_devicons = opts.disable_devicons
    local shorten_path = opts.shorten_path

    local mt_file_entry = {}

    mt_file_entry.cwd = cwd
    mt_file_entry.display = function(entry)
      local display = entry.value
      if shorten_path then
        display = utils.path_shorten(display)
      end

      return transform_devicons(entry.value, display, disable_devicons)
    end

    mt_file_entry.__index = function(t, k)
      local raw = rawget(mt_file_entry, k)
      if raw then return raw end

      if k == "path" then
        return t.cwd .. path.separator .. t.value
      end

      return rawget(t, rawget(lookup_keys, k))
    end

    return function(line)
      return setmetatable({line}, mt_file_entry)
    end
  end
end

do
  local lookup_keys = {
    value = 1,
    ordinal = 1,
  }

  -- Gets called only once to parse everything out for the vimgrep, after that looks up directly.
  local parse = function(t)
    local _, _, filename, lnum, col, text = string.find(t.value, [[([^:]+):(%d+):(%d+):(.*)]])

    local ok
    ok, lnum = pcall(tonumber, lnum)
    if not ok then lnum = nil end

    ok, col = pcall(tonumber, col)
    if not ok then col = nil end

    t.filename = filename
    t.lnum = lnum
    t.col = col
    t.text = text

    return {filename, lnum, col, text}
  end

  local execute_keys = {
    path = function(t) 
      return t.cwd .. path.separator .. t.filename, false
    end,

    filename = function(t)
      return parse(t)[1], true
    end,

    lnum = function(t)
      return parse(t)[2], true
    end,

    col = function(t)
      return parse(t)[3], true
    end,

    text = function(t)
      return parse(t)[4], true
    end,
  }

  function make_entry.gen_from_vimgrep(opts)
    opts = opts or {}

    local shorten_path = opts.shorten_path
    local disable_coordinates = opts.disable_coordinates
    local disable_devicons = opts.disable_devicons

    local display_string = "%s:%s%s"

    local mt_vimgrep_entry = {}

    mt_vimgrep_entry.cwd = vim.fn.expand(opts.cwd or vim.fn.getcwd())
    mt_vimgrep_entry.display = function(entry)
      local display = entry.value

      local display_filename
      if shorten_path then
        display_filename = utils.path_shorten(entry.filename)
      else
        display_filename = entry.filename
      end

      local coordinates = ""
      if not disable_coordinates then
        coordinates = string.format("%s:%s:", entry.lnum, entry.col)
      end

      display = transform_devicons(
        entry.filename,
        string.format(display_string, display_filename,  coordinates, entry.text),
        disable_devicons
      )

      return display
    end

    mt_vimgrep_entry.__index = function(t, k)
      local raw = rawget(mt_vimgrep_entry, k)
      if raw then return raw end

      local executor = rawget(execute_keys, k)
      if executor then
        local val, save = executor(t)
        if save then rawset(t, k, val) end
        return val
      end

      return rawget(t, rawget(lookup_keys, k))
    end

    return function(line)
      return setmetatable({line}, mt_vimgrep_entry)
    end
  end
end

function make_entry.gen_from_quickfix(opts)
  opts = opts or {}
  opts.tail_path = get_default(opts.tail_path, true)

  local make_display = function(entry)
    local to_concat = {}

    if not opts.hide_filename then
      local filename = entry.filename
      if opts.tail_path then
        filename = utils.path_tail(filename)
      elseif opts.shorten_path then
        filename = utils.path_shorten(filename)
      end

      table.insert(to_concat, filename)
      table.insert(to_concat, ":")
    end

    table.insert(to_concat, entry.text)

    return table.concat(to_concat, "")
  end

  return function(entry)
    local filename = entry.filename or vim.api.nvim_buf_get_name(entry.bufnr)

    return {
      valid = true,

      value = entry,
      ordinal = (
        not opts.ignore_filename and filename
        or ''
        ) .. ' ' .. entry.text,
      display = make_display,

      filename = filename,
      lnum = entry.lnum,
      col = entry.col,
      text = entry.text,
      start = entry.start,
      finish = entry.finish,
    }
  end
end

function make_entry.gen_from_buffer(opts)
  opts = opts or {}

  local cwd = vim.fn.expand(opts.cwd or vim.fn.getcwd())

  local get_position = function(entry)
    local tabpage_wins = vim.api.nvim_tabpage_list_wins(0)
    for k, v in ipairs(tabpage_wins) do
      if entry == vim.api.nvim_win_get_buf(v) then
        return vim.api.nvim_win_get_cursor(v)
      end
    end

    return {}
  end

  local make_display = function(entry)
    local display_bufname
    if opts.shorten_path then
      display_bufname = path.shorten(entry.filename)
    else
      display_bufname = entry.filename
    end

    return string.format("%" .. opts.bufnr_width .. "d : %s",
                         entry.bufnr, display_bufname)
  end

  return function(entry)
    local bufnr_str = tostring(entry)
    local bufname = path.normalize(vim.api.nvim_buf_get_name(entry), cwd)

    -- if bufname is inside the cwd, trim that part of the string

    local position = get_position(entry)

    if '' == bufname then
      return nil
    end

    return {
      valid = true,

      value = bufname,
      ordinal = bufnr_str .. " : " .. bufname,
      display = make_display,

      bufnr = entry,
      filename = bufname,

      lnum = position[1] or 1,
    }
  end
end

function make_entry.gen_from_treesitter(opts)
  opts = opts or {}

  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()

  local make_display = function(entry)
    if opts.show_line then
      if not tonumber(opts.show_line) then
        opts.show_line = 30
      end

      local spacing = string.rep(" ", opts.show_line - #entry.ordinal)

      return entry.ordinal .. spacing .. ": " .. (vim.api.nvim_buf_get_lines(
        bufnr,
        entry.lnum - 1,
        entry.lnum,
        false
      )[1] or '')
    else
      return entry.ordinal
    end
  end

  return function(entry)
    local ts_utils = require('nvim-treesitter.ts_utils')
    local start_row, start_col, end_row, end_col = ts_utils.get_node_range(entry.node)
    local node_text = ts_utils.get_node_text(entry.node)[1]
    return {
      valid = true,

      value = entry.node,
      ordinal = string.format("%s [%s]", node_text, entry.kind),
      display = make_display,

      node_text = node_text,

      filename = vim.api.nvim_buf_get_name(bufnr),
      -- need to add one since the previewer substacts one
      lnum = start_row + 1,
      col = start_col,
      text = node_text,
      start = start_row,
      finish = end_row
    }
  end
end

function make_entry.gen_from_tagfile(opts)
  local help_entry, version
  local delim = string.char(7)

  local make_display = function(line)
    help_entry = ""
    display    = ""
    version    = ""

    line = line .. delim
    for section in line:gmatch("(.-)" .. delim) do
      if section:find("^vim:") == nil then
        local ver = section:match("^neovim:(.*)")
        if ver == nil then
          help_entry = section
        else
          version = ver:sub(1, -2)
        end
      end
    end

    result = {}
    if version ~= "" then -- some Vim only entries are unversioned
      if opts.show_version then
        result.display = string.format("%s [%s]", help_entry, version)
      else
        result.display = help_entry
      end
      result.value = help_entry
    end

    return result
  end

  return function(line)
    local entry = {}
    local d = make_display(line)
    entry.valid   = next(d) ~= nil
    entry.display = d.display
    entry.value   = d.value
    entry.ordinal = d.value

    return entry
  end
end

function make_entry.gen_from_packages(opts)
  opts = opts or {}

  local make_display = function(module_name)
    local p_path = package.searchpath(module_name, package.path) or ""
    local display = string.format("%-" .. opts.column_len .. "s : %s", module_name, vim.fn.fnamemodify(p_path, ":~:."))

    return display
  end

  return function(module_name)
    local entry = {
      valid = module_name ~= "",
      value = module_name,
      ordinal = module_name,
    }
    entry.display = make_display(module_name)

    return entry
  end
end

function make_entry.gen_from_apropos(opts)
  opts = opts or {}

  return function(line)
    local cmd, _, desc = line:match("^(.*)%s+%((.*)%)%s+%-%s(.*)$")

    return {
      value = cmd,
      ordinal = cmd,
      display = string.format("%-30s : %s", cmd, desc)
    }
  end
end

function make_entry.gen_from_marks(_)
  return function(line)
    local split_value = utils.max_split(line, "%s+", 4)

    local mark_value = split_value[1]
    local cursor_position = vim.fn.getpos("'" .. mark_value)

    return {
      value = line,
      ordinal = line,
      display = line,
      lnum = cursor_position[2],
      col = cursor_position[3],
      start = cursor_position[2],
      filename = vim.api.nvim_buf_get_name(cursor_position[1])
    }
  end
end

return make_entry
