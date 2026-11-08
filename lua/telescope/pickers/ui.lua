-- Picker windows: floating windows with native borders and titles, configured with the options that
-- layout strategies produce (see `telescope_popup_options` in `telescope.pickers`).

local api = vim.api
local utils = require "telescope.utils"

local M = {}

-- `borderchars` lists the characters in Vim's `popup_create()` order: top, right, bottom, left,
-- topleft, topright, botright, botleft (one entry: used for all; two: edges and corners).
-- Native borders only allow single-cell characters, so longer strings are cut to their first one.
local function expand_borderchars(chars)
  if #chars == 1 then
    chars = { chars[1], chars[1], chars[1], chars[1], chars[1], chars[1], chars[1], chars[1] }
  elseif #chars == 2 then
    chars = { chars[1], chars[1], chars[1], chars[1], chars[2], chars[2], chars[2], chars[2] }
  elseif #chars ~= 8 then
    error "borderchars: expected 1, 2 or 8 characters"
  end
  return vim.tbl_map(function(c)
    return vim.fn.strcharpart(c, 0, 1)
  end, chars)
end

-- The border state of a window: characters, thickness (top, right, bottom, left) and titles, kept in
-- a window variable so that `move` and `change_title` can recompute the border.
local function border_state(opts)
  if opts.border == false or not opts.borderchars then
    return nil
  end
  local thickness = { 1, 1, 1, 1 }
  if type(opts.border) == "table" and not vim.tbl_isempty(opts.border) then
    assert(#opts.border == 4, "border: expected a list of 4 numbers")
    thickness = vim.tbl_map(function(t)
      return t > 0 and 1 or 0
    end, opts.border)
  end
  local title = opts.title
  if type(title) == "string" then
    title = { { pos = "N", text = title } }
  end
  return {
    chars = expand_borderchars(opts.borderchars),
    thickness = thickness,
    titles = title or {},
  }
end

-- First title on the top (`side = "N"`) or bottom (`"S"`) border, as `text, align`.
local function find_title(titles, side, width)
  for _, title in ipairs(titles) do
    if title.pos:find(side) and title.text ~= "" then
      local text = title.text
      if vim.fn.strdisplaywidth(text) > width - 2 then
        text = utils.truncate(text, width - 2)
      end
      local align = title.pos:find "W" and "left" or title.pos:find "E" and "right" or "center"
      return " " .. text .. " ", align
    end
  end
  return "", nil
end

-- Window config for content at `row`, `col` (0-based) of size `width` x `height`.
local function win_config(state, row, col, width, height)
  local config = { relative = "editor", width = width, height = height }
  if not state then
    config.row, config.col, config.border = row, col, "none"
    return config
  end

  -- sides at the screen edge are dropped
  local t = state.thickness
  local top = t[1] == 1 and row > 0
  local right = t[2] == 1 and col + width < vim.o.columns
  local bot = t[3] == 1 and row + height < vim.o.lines
  local left = t[4] == 1 and col > 0
  local c = state.chars
  local function corner(i, a, b)
    -- an empty corner between two edges is not allowed
    return (a and b) and (c[i] ~= "" and c[i] or " ") or ""
  end
  config.border = {
    corner(5, top, left),
    top and c[1] or "",
    corner(6, top, right),
    right and c[2] or "",
    corner(7, bot, right),
    bot and c[3] or "",
    corner(8, bot, left),
    left and c[4] or "",
  }
  -- the native position is the outer corner of the border
  config.row = row - (top and 1 or 0)
  config.col = col - (left and 1 or 0)

  config.title, config.title_pos = "", nil
  config.footer, config.footer_pos = "", nil
  if top then
    config.title, config.title_pos = find_title(state.titles, "N", width)
  end
  if bot then
    config.footer, config.footer_pos = find_title(state.titles, "S", width)
  end
  return config
end

-- Content position and size from the options; `line` and `col` are 1-based, 0 or nil centers.
local function geometry(opts)
  local width = opts.width or 1
  local height = math.max(opts.height or 1, opts.minheight or 1)
  local row = (opts.line and opts.line ~= 0) and opts.line - 1 or math.floor((vim.o.lines - height) / 2)
  local col = (opts.col and opts.col ~= 0) and opts.col - 1 or math.floor((vim.o.columns - width) / 2)
  return row, col, width, height
end

local Border = {}
Border.__index = Border

--- Change the title, keeping its position unless `pos` is given ("NW", "N", "NE", "SW", "S", "SE").
function Border:change_title(title, pos)
  local win = self._win
  local state = api.nvim_win_is_valid(win) and vim.w[win].telescope_border
  if not state then
    return
  end
  pos = pos or (state.titles[1] and state.titles[1].pos) or "N"
  state.titles = { { pos = pos, text = title } }
  vim.w[win].telescope_border = state

  local cfg = api.nvim_win_get_config(win)
  local top, bot = cfg.border[2] ~= "", cfg.border[6] ~= ""
  local width = api.nvim_win_get_width(win)
  local new = {}
  new.title, new.title_pos = "", nil
  new.footer, new.footer_pos = "", nil
  if top then
    new.title, new.title_pos = find_title(state.titles, "N", width)
  end
  if bot then
    new.footer, new.footer_pos = find_title(state.titles, "S", width)
  end
  api.nvim_win_set_config(win, new)
end

--- Open a picker window.
---@param bufnr integer?: buffer to show (nil: a new scratch buffer)
---@param opts telescope_popup_options
---@return integer win
---@return table: `{ border = { change_title = … } }` (`border` is nil without a border)
function M.create(bufnr, opts)
  if not bufnr then
    bufnr = api.nvim_create_buf(false, true)
    vim.bo[bufnr].bufhidden = "wipe"
  end

  local state = border_state(opts)
  local config = win_config(state, geometry(opts))
  config.style = "minimal"
  config.focusable = opts.focusable or false
  config.zindex = opts.zindex or 50
  config.noautocmd = true
  local win = api.nvim_open_win(bufnr, opts.enter ~= false, config)

  local winhl = {}
  if opts.highlight then
    winhl[#winhl + 1] = ("Normal:%s,EndOfBuffer:%s"):format(opts.highlight, opts.highlight)
  end
  if opts.borderhighlight then
    winhl[#winhl + 1] = "FloatBorder:" .. opts.borderhighlight
  end
  local titlehl = opts.titlehighlight or opts.borderhighlight
  if titlehl then
    winhl[#winhl + 1] = ("FloatTitle:%s,FloatFooter:%s"):format(titlehl, titlehl)
  end
  if #winhl > 0 then
    vim.wo[win].winhighlight = table.concat(winhl, ",")
  end

  if not state then
    return win, {}
  end
  vim.w[win].telescope_border = state
  return win, { border = setmetatable({ _win = win }, Border) }
end

--- Move or resize a picker window; its border and titles are kept.
---@param win integer
---@param opts telescope_popup_options: only `line`, `col`, `width`, `height` and `minheight` are used
function M.move(win, opts)
  local config = win_config(vim.w[win].telescope_border, geometry(opts))
  if not vim.w[win].telescope_border then
    config.border = nil
  end
  api.nvim_win_set_config(win, config)
end

return M
