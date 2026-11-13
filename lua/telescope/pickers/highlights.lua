local api = vim.api
local hl = vim.hl
local log = require("telescope.log")
local conf = require("telescope.config").values

local M = {}

local ns_telescope_selection = api.nvim_create_namespace("telescope_selection")
local ns_telescope_multiselection = api.nvim_create_namespace("telescope_multiselection")
local ns_telescope_entry = api.nvim_create_namespace("telescope_entry")

---@class telescope.pickers.Highlighter
local Highlighter = {}
Highlighter.__index = Highlighter

function Highlighter:new(picker)
  return setmetatable({
    picker = picker,
  }, self)
end

function Highlighter:hi_display(row, prefix, display_highlights)
  -- This is the bug that made my highlight fixes not work.
  -- We will leave the solution commented, so the test fails.
  if not display_highlights or vim.tbl_isempty(display_highlights) then
    return
  end

  local results_bufnr = self.picker.results_bufnr

  api.nvim_buf_clear_namespace(results_bufnr, ns_telescope_entry, row, row + 1)
  local len_prefix = #prefix

  for _, hl_block in ipairs(display_highlights) do
    -- extmark instead of `vim.hl.range()`, which is much slower (runs for every displayed row)
    api.nvim_buf_set_extmark(results_bufnr, ns_telescope_entry, row, len_prefix + hl_block[1][1], {
      end_col = len_prefix + hl_block[1][2],
      hl_group = hl_block[2],
      priority = hl.priorities.user,
      strict = false,
    })
  end
end

--- Clear the entry highlights (of rows `first` to `last` - 1, default: all).
function Highlighter:clear_display(first, last)
  if
    not self
    or not self.picker
    or not self.picker.results_bufnr
    or not api.nvim_buf_is_valid(self.picker.results_bufnr)
  then
    return
  end

  api.nvim_buf_clear_namespace(self.picker.results_bufnr, ns_telescope_entry, first or 0, last or -1)
end

function Highlighter:hi_sorter(row, prompt, display)
  local picker = self.picker
  if not picker.sorter or not picker.sorter.highlighter then
    return
  end

  local results_bufnr = picker.results_bufnr
  picker:highlight_one_row(results_bufnr, prompt, display, row)
end

function Highlighter:hi_selection(row, caret)
  caret = vim.nonnil(caret, "")
  local results_bufnr = self.picker.results_bufnr

  api.nvim_buf_clear_namespace(results_bufnr, ns_telescope_selection, 0, -1)
  hl.range(results_bufnr, ns_telescope_selection, "TelescopeSelectionCaret", { row, 0 }, { row, #caret })

  api.nvim_buf_set_extmark(
    results_bufnr,
    ns_telescope_selection,
    row,
    #caret,
    { end_line = row + 1, hl_eol = conf.hl_result_eol, hl_group = "TelescopeSelection" }
  )
end

---@param row integer
---@param is_selected any
function Highlighter:hi_multiselect(row, is_selected)
  local results_bufnr = self.picker.results_bufnr

  if is_selected then
    hl.range(results_bufnr, ns_telescope_multiselection, "TelescopeMultiSelection", { row, 0 }, { row, -1 })
    if self.picker.multi_icon then
      local line = api.nvim_buf_get_lines(results_bufnr, row, row + 1, false)[1]
      local pos = line and line:find(self.picker.multi_icon)
      if pos and pos <= math.max(#self.picker.selection_caret, #self.picker.entry_prefix) then
        hl.range(
          results_bufnr,
          ns_telescope_multiselection,
          "TelescopeMultiIcon",
          { row, pos - 1 },
          { row, pos - 1 + #self.picker.multi_icon }
        )
      end
    end
  else
    local existing_marks = api.nvim_buf_get_extmarks(
      results_bufnr,
      ns_telescope_multiselection,
      { row, 0 },
      { row, -1 },
      {}
    )

    -- This is still kind of weird to me, since it seems like I'm erasing stuff
    -- when I shouldn't... Perhaps it's about the gravity of the extmark?
    if #existing_marks > 0 then
      log.trace("Clearing highlight multi select row: ", row)

      api.nvim_buf_clear_namespace(results_bufnr, ns_telescope_multiselection, row, row + 1)
    end
  end
end

M.new = function(...)
  return Highlighter:new(...)
end

return M
