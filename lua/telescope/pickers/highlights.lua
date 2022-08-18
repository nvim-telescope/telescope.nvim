local a = vim.api
local conf = require("telescope.config").values

local highlights = {}

local ns_telescope_selection = a.nvim_create_namespace "telescope_selection"
local ns_telescope_multiselection = a.nvim_create_namespace "telescope_multiselection"
local ns_telescope_entry = a.nvim_create_namespace "telescope_entry"
local ns_telescope_matching = a.nvim_create_namespace "telescope_matching"

-- Priorities for extmark highlights. Example: Treesitter is set to 100
local SELECTION_MULTISELECT_PRIORITY = 100
local DISPLAY_HIGHLIGHTS_PRIORITY = 110
local SELECTION_HIGHLIGHTS_PRIORITY = 130
local SORTER_HIGHLIGHTS_PRIORITY = 140

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

  local results_bufnr = assert(self.picker.results_bufnr, "Must have a results bufnr")
  if not a.nvim_buf_is_valid(results_bufnr) then
    return
  end

  a.nvim_buf_clear_namespace(results_bufnr, ns_telescope_entry, row, row + 1)

  for _, hl_block in ipairs(display_highlights) do
    a.nvim_buf_set_extmark(results_bufnr, ns_telescope_entry, row, #prefix + hl_block[1][1], {
      end_col = #prefix + hl_block[1][2],
      hl_group = hl_block[2],
      priority = DISPLAY_HIGHLIGHTS_PRIORITY,
      strict = false,
    })
  end
end

function Highlighter:clear_display()
  if
    not self
    or not self.picker
    or not self.picker.results_bufnr
    or not vim.api.nvim_buf_is_valid(self.picker.results_bufnr)
  then
    return
  end

  a.nvim_buf_clear_namespace(self.picker.results_bufnr, ns_telescope_entry, 0, -1)
end

function Highlighter:hi_sorter(row, prompt, display)
  local picker = self.picker
  if not picker.sorter or not picker.sorter.highlighter then
    return
  end

  local results_bufnr = assert(self.picker.results_bufnr, "Must have a results bufnr")
  if not a.nvim_buf_is_valid(results_bufnr) then
    return
  end

  local sorter_highlights = picker.sorter:highlighter(prompt, display)

  if sorter_highlights then
    for _, hl in ipairs(sorter_highlights) do
      local highlight, start, finish
      if type(hl) == "table" then
        highlight = hl.highlight or "TelescopeMatching"
        start = hl.start
        finish = hl.finish or hl.start
      elseif type(hl) == "number" then
        highlight = "TelescopeMatching"
        start = hl
        finish = hl
      else
        error "Invalid highlight"
      end

      a.nvim_buf_set_extmark(results_bufnr, ns_telescope_matching, row, start - 1, {
        end_col = finish,
        hl_group = highlight,
        priority = SORTER_HIGHLIGHTS_PRIORITY,
        strict = false,
      })
    end
  end
end

function Highlighter:hi_selection(row, caret)
  caret = vim.F.if_nil(caret, "")
  local results_bufnr = assert(self.picker.results_bufnr, "Must have a results bufnr")

  a.nvim_buf_clear_namespace(results_bufnr, ns_telescope_selection, 0, -1)

  -- Skip if there is nothing on the actual line
  local line = a.nvim_buf_get_lines(results_bufnr, row, row + 1, false)[1]
  if line == nil or line == "" then
    return
  end

  local offset = #caret

  -- Highlight the caret
  a.nvim_buf_set_extmark(results_bufnr, ns_telescope_selection, row, 0, {
    virt_text = { { caret, "TelescopeSelectionCaret" } },
    virt_text_pos = "overlay",
    end_col = offset,
    hl_group = "TelescopeSelectionCaret",
    hl_mode = "combine",
    priority = SELECTION_HIGHLIGHTS_PRIORITY,
    strict = true,
  })

  -- Highlight the text after the caret
  a.nvim_buf_set_extmark(results_bufnr, ns_telescope_selection, row, offset, {
    end_line = row + 1,
    hl_eol = conf.hl_result_eol,
    hl_group = "TelescopeSelection",
    priority = SELECTION_HIGHLIGHTS_PRIORITY,
  })
end

function Highlighter:hi_multiselect(row, is_selected)
  local results_bufnr = assert(self.picker.results_bufnr, "Must have a results bufnr")

  if not a.nvim_buf_is_valid(results_bufnr) then
    return
  end

  a.nvim_buf_clear_namespace(results_bufnr, ns_telescope_multiselection, row, row + 1)

  local line = a.nvim_buf_get_lines(results_bufnr, row, row + 1, false)[1]
  if line == nil or line == "" then
    return
  end

  if is_selected then
    local multi_icon = self.picker.multi_icon
    local offset = #multi_icon

    a.nvim_buf_set_extmark(results_bufnr, ns_telescope_multiselection, row, offset, {
      virt_text = { { multi_icon, "TelescopeMultiIcon" } },
      virt_text_pos = "overlay",
      end_col = offset,
      hl_mode = "combine",
      hl_group = "TelescopeMultiIcon",
      priority = SELECTION_HIGHLIGHTS_PRIORITY,
    })
    -- highlight the caret
    a.nvim_buf_set_extmark(results_bufnr, ns_telescope_multiselection, row, 0, {
      end_col = #self.picker.selection_caret,
      hl_group = "TelescopeMultiSelection",
      priority = SELECTION_MULTISELECT_PRIORITY,
    })
    -- highlight the text after the multi_icon
    a.nvim_buf_set_extmark(results_bufnr, ns_telescope_multiselection, row, offset, {
      end_col = #line,
      hl_group = "TelescopeMultiSelection",
      priority = SELECTION_MULTISELECT_PRIORITY,
    })
  end
end

highlights.new = function(...)
  return Highlighter:new(...)
end

return highlights
