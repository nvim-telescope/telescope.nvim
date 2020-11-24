local has_devicons, devicons = pcall(require, 'nvim-web-devicons')

local conf = require('telescope.config').values
local entry_display = require('telescope.pickers.entry_display')
local path = require('telescope.path')
local utils = require('telescope.utils')

local get_default = utils.get_default

local make_entry = {}

local transform_devicons
if has_devicons then
  if not devicons.has_loaded() then
    devicons.setup()
  end

  transform_devicons = function(filename, display, disable_devicons)
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
      local display, hl_group = entry.value, nil
      if shorten_path then
        display = utils.path_shorten(display)
      end

      display, hl_group = transform_devicons(entry.value, display, disable_devicons)

      if hl_group then
        return display, { { {1, 3}, hl_group } }
      else
        return display
      end
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
      local display, hl_group = entry.value, nil

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

      display, hl_group = transform_devicons(
        entry.filename,
        string.format(display_string, display_filename,  coordinates, entry.text),
        disable_devicons
      )

      if hl_group then
        return display, { { {1, 3}, hl_group } }
      else
        return display
      end
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

function make_entry.gen_from_git_commits(opts)
  opts = opts or {}

  return function(entry)
    if entry == "" then
      return nil
    end

    local sha, msg = string.match(entry, '([^ ]+) (.+)')

    return {
      value = sha,
      ordinal = sha .. ' ' .. msg,
      display = sha .. ' ' .. msg,
    }
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

  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = opts.bufnr_width },
      { width = 4 },
      { remaining = true },
    },
  }

  local cwd = vim.fn.expand(opts.cwd or vim.fn.getcwd())

  local make_display = function(entry)
    local display_bufname
    if opts.shorten_path then
      display_bufname = path.shorten(entry.filename)
    else
      display_bufname = entry.filename
    end

    return displayer {
      entry.bufnr,
      entry.indicator,
      display_bufname .. ":" .. entry.lnum,
    }
  end

  return function(entry)
    local bufname = entry.info.name ~= "" and entry.info.name or '[No Name]'
    -- if bufname is inside the cwd, trim that part of the string
    bufname = path.normalize(bufname, cwd)

    local hidden = entry.info.hidden == 1 and 'h' or 'a'
    local readonly = vim.api.nvim_buf_get_option(entry.bufnr, 'readonly') and '=' or ' '
    local changed = entry.info.changed == 1 and '+' or ' '
    local indicator = entry.flag .. hidden .. readonly .. changed

    return {
      valid = true,

      value = bufname,
      ordinal = entry.bufnr .. " : " .. bufname,
      display = make_display,

      bufnr = entry.bufnr,
      filename = bufname,

      lnum = entry.info.lnum and entry.info.lnum or 1,
      indicator = indicator,
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

function make_entry.gen_from_taglist(_)
  local delim = string.char(9)

  return function(line)
    local entry = {}
    local tag = (line..delim):match("(.-)" .. delim)
    entry.valid   = tag ~= ""
    entry.display = tag
    entry.value   = tag
    entry.ordinal = tag

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

function make_entry.gen_from_registers(_)
  local displayer = entry_display.create {
    separator = ":",
    items = {
      { width = 4 },
      { remaining = true },
    },
  }

  local make_display = function(entry)
    return displayer {
      string.format("[%s]", entry.value),
      entry.content
    }
  end

  return function(entry)
    return {
      valid = true,
      value = entry,
      ordinal = entry,
      content = vim.fn.getreg(entry),
      display = make_display
    }
  end
end

function make_entry.gen_from_highlights()
  return function(entry)
    local make_display = function(entry)
      local display = entry.value
      return display, { { { 0, #display }, display } }
    end

    local preview_command = function(entry, bufnr)
      local hl = entry.value
      vim.api.nvim_buf_set_option(bufnr, 'filetype', 'vim')
      local output = vim.split(vim.fn.execute('hi ' .. hl), '\n')
      local start = string.find(output[2], 'xxx', 1, true)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, output)
      vim.api.nvim_buf_add_highlight(bufnr, -1, hl, 1, start - 1, start + 2)
    end

    return {
      value = entry,
      display = make_display,
      ordinal = entry,

      preview_command = preview_command

    }
  end
end

function make_entry.gen_from_vimoptions()

  -- TODO: Can we just remove this from `options.lua`?
  function N_(s)
    return s
  end

  local process_one_opt = function(o)
    local ok, value_origin

    local option = {
      name          = "",
      description   = "",
      current_value = "",
      default_value = "",
      value_type    = "",
      set_by_user   = false,
      last_set_from = "",
    }

    local is_global = false
    for _, v in ipairs(o.scope) do
      if v == "global" then
        is_global = true
      end
    end

    if not is_global then
      return
    end

    if is_global then
      option.name = o.full_name

      ok, option.current_value = pcall(vim.api.nvim_get_option, o.full_name)
      if not ok then
        return
      end

      local str_funcname = o.short_desc()
      option.description = assert(loadstring("return " .. str_funcname))()
      -- if #option.description > opts.desc_col_length then
      --   opts.desc_col_length = #option.description
      -- end

      if o.defaults ~= nil then
        option.default_value = o.defaults.if_true.vim or o.defaults.if_true.vi
      end

      if type(option.default_value) == "function" then
        option.default_value = "Macro: " .. option.default_value()
      end

      option.value_type = (type(option.current_value) == "boolean" and "bool" or type(option.current_value))

      if option.current_value ~= option.default_value then
        option.set_by_user = true
        value_origin = vim.fn.execute("verbose set " .. o.full_name .. "?")
        if string.match(value_origin, "Last set from") then
          -- TODO: parse file and line number as separate items
          option.last_set_from = value_origin:gsub("^.*Last set from ", "")
        end
      end

      return option
    end
  end

  local displayer = entry_display.create {
    separator = "│",
    items = {
      { width = 25 },
      { width = 50 },
      { remaining = true },
    },
  }

  local make_display = function(entry)

    return displayer {
      entry.name,
      string.format(
        "[%s] %s",
        entry.value_type,
        utils.display_termcodes(tostring(entry.current_value))),
      entry.description,
    }
  end

  return function(line)
    local entry = process_one_opt(line)
    if not entry then
      return
    end

    entry.valid   = true
    entry.display = make_display
    entry.value   = line
    entry.ordinal = line.full_name
    -- entry.raw_value = d.raw_value
    -- entry.last_set_from = d.last_set_from

    return entry
  end
end

function make_entry.gen_from_ctags(opts)
  opts = opts or {}

  local cwd = vim.fn.expand(opts.cwd or vim.fn.getcwd())
  local current_file = path.normalize(vim.fn.expand('%'), cwd)

  local display_items = {
    { width = 30 },
    { remaining = true },
  }

  if opts.show_line then
    table.insert(display_items, 2, { width = 30 })
  end

  local displayer = entry_display.create {
    separator = " │ ",
    items = display_items,
  }

  local make_display = function(entry)
    local filename
    if not opts.hide_filename then
      if opts.shorten_path then
        filename = path.shorten(entry.filename)
      else
        filename = entry.filename
      end
    end

    local scode
    if opts.show_line then
      scode = entry.scode
    end

    return displayer {
      filename,
      entry.tag,
      scode,
    }
  end

  return function(line)
    if line == '' or line:sub(1, 1) == '!' then
      return nil
    end

    local tag, file, scode = string.match(line, '([^\t]+)\t([^\t]+)\t/^\t?(.*)/;"\t+.*')

    if opts.only_current_file and file ~= current_file then
      return nil
    end

    return {
      valid = true,

      ordinal = file .. ': ' .. tag,
      display = make_display,
      scode = scode,
      tag = tag,

      filename = file,

      col = 1,
      lnum = 1,
    }
  end
end

return make_entry
