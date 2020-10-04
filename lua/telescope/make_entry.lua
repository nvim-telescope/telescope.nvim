local has_devicons, devicons = pcall(require, 'nvim-web-devicons')

local path = require('telescope.path')
local utils = require('telescope.utils')

local get_default = utils.get_default

local make_entry = {}

make_entry.types = {
  GENERIC = 0,
  FILE    = 1,
}

local transform_devicons
if has_devicons then
  transform_devicons = function(filename, display, opts)
    if opts.disable_devicons or not filename then
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

function make_entry.gen_from_string()
  return function(line)
    return {
      valid = line ~= "",
      entry_type = make_entry.types.GENERIC,

      value = line,
      ordinal = line,
      display = line,
    }
  end
end

function make_entry.gen_from_file(opts)
  opts = opts or {}

  local cwd = vim.fn.expand(opts.cwd or vim.fn.getcwd())

  local make_display = function(line)
    local display = line
    if opts.shorten_path then
      display = utils.path_shorten(line)
    end

    display = transform_devicons(line, display, opts)

    return display
  end

  return function(line)
    local entry = {
      ordinal = line,
      value = line,

      entry_type = make_entry.types.FILE,
      filename = line,
      path = cwd .. utils.get_separator() .. line,
    }

    entry.display = make_display(line)

    return entry
  end
end

function make_entry.gen_from_vimgrep(opts)
  opts = opts or {}

  local display_string = "%s:%s%s"

  local make_display = function(entry)
    local display = entry.value

    local display_filename
    if opts.shorten_path then
      display_filename = utils.path_shorten(entry.filename)
    else
      display_filename = entry.filename
    end

    local coordinates = ""
    if not opts.disable_coordinates then
      coordinates = string.format("%s:%s:", entry.lnum, entry.col)
    end

    display = transform_devicons(
      entry.filename,
      string.format(display_string, display_filename,  coordinates, entry.text),
      opts
    )

    return display
  end

  return function(line)
    -- TODO: Consider waiting to do this string.find
    -- TODO: Is this the fastest way to get each of these?
    --         Or could we just walk the text and check for colons faster?
    local _, _, filename, lnum, col, text = string.find(line, [[([^:]+):(%d+):(%d+):(.*)]])

    local ok
    ok, lnum = pcall(tonumber, lnum)
    if not ok then lnum = nil end

    ok, col = pcall(tonumber, col)
    if not ok then col = nil end

    return {
      valid = line ~= "",

      value = line,
      ordinal = line,
      display = make_display,

      entry_type = make_entry.types.FILE,
      filename = filename,
      lnum = lnum,
      col = col,
      text = text,
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
    local entry = {
      entry_type = make_entry.types.GENERIC,

    }
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
    local path = package.searchpath(module_name, package.path) or ""
    local display = string.format("%-" .. opts.column_len .. "s : %s", module_name, vim.fn.fnamemodify(path, ":~:."))

    return display
  end

  return function(module_name)
    local entry = {
      valid = module_name ~= "",
      entry_type = make_entry.types.GENERIC,

      value = module_name,
      ordinal = module_name,
      }
    entry.display = make_display(module_name)

    return entry
  end
end

return make_entry
