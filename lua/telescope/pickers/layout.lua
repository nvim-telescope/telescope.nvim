---@tag telescope.pickers.layout
---@config { ["module"] = "telescope.pickers.layout" }

---@brief [[
--- The telescope pickers layout can be configured using the
--- |telescope.defaults.create_layout| option.
---
--- Parameters: ~
---   - picker : A Picker object.
---
--- Return: ~
---   - layout : instance of `TelescopeLayout` class.
---
--- Example: ~
--- <code>
--- local Layout = require "telescope.pickers.layout"
---
--- require("telescope").setup {
---   create_layout = function(picker)
---     local function create_window(enter, width, height, row, col, title)
---       local bufnr = vim.api.nvim_create_buf(false, true)
---       local winid = vim.api.nvim_open_win(bufnr, enter, {
---         style = "minimal",
---         relative = "editor",
---         width = width,
---         height = height,
---         row = row,
---         col = col,
---         border = "single",
---         title = title,
---       })
---
---       vim.wo[winid].winhighlight = "Normal:Normal"
---
---       return Layout.Window {
---         bufnr = bufnr,
---         winid = winid,
---       }
---     end
---
---     local function destory_window(window)
---       if window then
---         if vim.api.nvim_win_is_valid(window.winid) then
---           vim.api.nvim_win_close(window.winid, true)
---         end
---         if vim.api.nvim_buf_is_valid(window.bufnr) then
---           vim.api.nvim_buf_delete(window.bufnr, { force = true })
---         end
---       end
---     end
---
---     local layout = Layout {
---       picker = picker,
---       mount = function(self)
---         self.results = create_window(false, 40, 20, 0, 0, "Results")
---         self.preview = create_window(false, 40, 23, 0, 42, "Preview")
---         self.prompt = create_window(true, 40, 1, 22, 0, "Prompt")
---       end,
---       unmount = function(self)
---         destory_window(self.results)
---         destory_window(self.preview)
---         destory_window(self.prompt)
---       end,
---       update = function(self) end,
---     }
---
---     return layout
---   end,
--- }
--- </code>
---@brief ]]

local function wrap_instance(class, instance)
  local self = instance
  if not getmetatable(instance) then
    self = setmetatable(instance, { __index = class })
  end
  return self
end

---@class TelescopeWindowBorder.config
---@field bufnr integer
---@field winid integer|nil
---@field change_title nil|function: (self: TelescopeWindowBorder, title: string, pos?: "NW"|"N"|"NE"|"SW"|"S"|"SE"):nil

---@param class TelescopeWindowBorder
---@param config TelescopeWindowBorder.config
---@return TelescopeWindowBorder
local function init_border(class, config)
  config = config or {}

  ---@type TelescopeWindowBorder
  local self = wrap_instance(class, config)
  if not self.change_title then
    self.change_title = class.change_title
  end

  return self
end

---@class TelescopeWindowBorder
---@field bufnr integer|nil
---@field winid integer|nil
local Border = setmetatable({}, {
  __call = init_border,
  __name = "TelescopeWindowBorder",
})

---@param title string
---@param pos "NW"|"N"|"NE"|"SW"|"S"|"SE"|nil
function Border:change_title(title, pos) end

---@class TelescopeWindow.config
---@field bufnr integer
---@field winid integer|nil
---@field border TelescopeWindowBorder.config|nil

---@param class TelescopeWindow
---@param config TelescopeWindow.config
---@return TelescopeWindow
local function init_window(class, config)
  config = config or {}

  ---@type TelescopeWindow
  local self = wrap_instance(class, config)
  self.border = Border(config.border)

  return self
end

---@class TelescopeWindow
---@field border TelescopeWindowBorder
---@field bufnr integer
---@field winid integer
local Window = setmetatable({}, {
  __call = init_window,
  __name = "TelescopeWindow",
})

---@class TelescopeLayout.config
---@field mount function: (self: TelescopeLayout):nil
---@field unmount function: (self: TelescopeLayout):nil
---@field update function: (self: TelescopeLayout):nil
---@field prompt TelescopeWindow|nil
---@field results TelescopeWindow|nil
---@field preview TelescopeWindow|nil

---@param class TelescopeLayout
---@param config TelescopeLayout.config
---@return TelescopeLayout
local function init_layout(class, config)
  config = config or {}

  ---@type TelescopeLayout
  local self = wrap_instance(class, config)

  assert(config.mount, "missing layout:mount")
  assert(config.unmount, "missing layout:unmount")
  assert(config.update, "missing layout:update")

  return self
end

---@class TelescopeLayout
---@field prompt TelescopeWindow
---@field results TelescopeWindow
---@field preview TelescopeWindow|nil
local Layout = setmetatable({
  Window = Window,
}, {
  __call = init_layout,
  __name = "TelescopeLayout",
})

--- Create the layout.
--- This needs to ensure the required properties are populated.
function Layout:mount() end

--- Destroy the layout.
--- This is responsible for performing clean-up, for example:
---  - deleting buffers
---  - closing windows
---  - clearing autocmds
function Layout:unmount() end

--- Refresh the layout.
--- This is called when, for example, vim is resized.
function Layout:update() end

---@alias TelescopeWindow.constructor fun(config: TelescopeWindow.config): TelescopeWindow
---@alias TelescopeLayout.constructor fun(config: TelescopeLayout.config): TelescopeLayout

return Layout --[[@as TelescopeLayout.constructor|{ Window: TelescopeWindow.constructor }]]
