local a = vim.api
local log = require "telescope.log"
local conf = require("telescope.config").values

local strdisplaywidth = require("plenary.strings").strdisplaywidth

local highlights = {}

local ns_telescope_matching = a.nvim_create_namespace "telescope_matching"
local ns_telescope_selection = a.nvim_create_namespace "telescope_selection"
local ns_telescope_multiselection = a.nvim_create_namespace "telescope_multiselection"
local ns_telescope_entry = a.nvim_create_namespace "telescope_entry"

local Highlighter = {}
Highlighter.__index = Highlighter

function Highlighter:new(picker)
  return setmetatable({
    picker = picker,
    offset = picker._prefix_width,
  }, self)
end

local DISPLAY_HIGHLIGHTS_PRIORITY = 110
local SORTER_HIGHLIGHTS_PRIORITY = 120
local SELECTION_HIGHLIGHTS_PRIORITY = 130

function Highlighter:highlight(row, opts)
  assert(row, "Must pass a row")

  local picker = self.picker

  local entry = opts.entry or picker:_get_entry_from_row(row)
  local prompt = opts.prompt or picker:_get_prompt()
  local is_selected = opts.is_selected or (picker._selection_row == row)
  local is_multi_selected = opts.is_multi_selected or picker:is_multi_selected(entry)

  if is_selected then
    self:hi_selection(row)
  end

  if not opts.skip_display then
    local display = opts.display
    local display_highlights = opts.display_highlights
    if not display then
      display, display_highlights = picker:_resolve_entry_display(entry)
    end

    self:hi_display(row, display_highlights)
    self:hi_sorter(row, prompt, display)
  end

  self:hi_multiselect(row, is_multi_selected)
end

function Highlighter:hi_display(row, display_highlights)
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
    a.nvim_buf_set_extmark(results_bufnr, ns_telescope_entry, row, self.offset + hl_block[1][1], {
      end_col = self.offset + hl_block[1][2],
      hl_group = hl_block[2],
      priority = DISPLAY_HIGHLIGHTS_PRIORITY,
      strict = false,
    })
  end
end

function Highlighter:clear()
  if
    not self
    or not self.picker
    or not self.picker.results_bufnr
    or not a.nvim_buf_is_valid(self.picker.results_bufnr)
  then
    return
  end

  a.nvim_buf_clear_namespace(self.picker.results_bufnr, ns_telescope_entry, 0, -1)
  a.nvim_buf_clear_namespace(self.picker.results_bufnr, ns_telescope_matching, 0, -1)
end

function Highlighter:hi_sorter(row, prompt, display)
  local picker = self.picker
  local sorter = picker.sorter
  if not picker.sorter or not picker.sorter.highlighter then
    return
  end

  local results_bufnr = assert(self.picker.results_bufnr, "Must have a results bufnr")
  if not a.nvim_buf_is_valid(results_bufnr) then
    return
  end

  local sorter_highlights = sorter:highlighter(prompt, display)

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
        error "Invalid higlighter fn"
      end

      a.nvim_buf_set_extmark(results_bufnr, ns_telescope_matching, row, start + self.offset - 1, {
        end_col = self.offset + finish,
        hl_group = highlight,
        priority = SORTER_HIGHLIGHTS_PRIORITY,
        strict = false,
      })
    end
  end
end

function Highlighter:hi_selection(row)
  local results_bufnr = assert(self.picker.results_bufnr, "Must have a results bufnr")
  if not a.nvim_buf_is_valid(results_bufnr) then
    return
  end

  a.nvim_buf_clear_namespace(results_bufnr, ns_telescope_selection, 0, -1)

  -- If there isn't anything _on_ the line, then it's some edge case with
  -- loading the buffer or something like that.
  --
  -- We can just skip and we'll get the updates later.
  if a.nvim_buf_get_lines(results_bufnr, row, row + 1, false)[1] == "" then
    return
  end

  -- TODO: Someone will complain about the highlighting here I'm sure.
  -- I don't know what to tell them except what are you doing w/ highlighting
  local caret = self.picker.selection_caret
  local offset = self.offset

  -- Highlight the caret
  a.nvim_buf_set_extmark(results_bufnr, ns_telescope_selection, row, 0, {
    virt_text = { { caret, "TelescopeSelectionCaret" } },
    virt_text_pos = "overlay",
    end_col = offset,
    hl_group = "TelescopeSelectionCaret",
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
  if not line then
    return
  end

  if is_selected then
    a.nvim_buf_set_extmark(results_bufnr, ns_telescope_multiselection, row, self.offset, {
      end_col = #line,
      hl_group = "TelescopeMultiSelection",
    })

    -- TEST WITH MULTI-BYTE CHARS
    if self.picker.multi_icon and self.offset > 0 then
      local icon = self.picker.multi_icon
      local cols = strdisplaywidth(icon)
      a.nvim_buf_set_extmark(results_bufnr, ns_telescope_multiselection, row, self.offset - cols, {
        end_col = self.offset,
        virt_text = { { self.picker.multi_icon, "TelescopeMultiIcon" } },
        virt_text_pos = "overlay",
      })
    end
  end
end

highlights.new = function(...)
  return Highlighter:new(...)
end

return highlights
