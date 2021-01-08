local a = vim.api

local highlights = {}

local ns_telescope_selection = a.nvim_create_namespace('telescope_selection')
local ns_telescope_multiselection = a.nvim_create_namespace('telescope_mulitselection')
local ns_telescope_entry = a.nvim_create_namespace('telescope_entry')

local Highlighter = {}
Highlighter.__index = Highlighter

function Highlighter:new(picker)
  return setmetatable({
    picker = picker,
  }, self)
end

function Highlighter:hi_display(row, prefix, display_highlights)
  -- This is the bug that made my highlight fixes not work.
  -- We will leave the solutino commented, so the test fails.
  if not display_highlights or vim.tbl_isempty(display_highlights) then
    return
  end

  local results_bufnr = assert(self.picker.results_bufnr, "Must have a results bufnr")

  a.nvim_buf_clear_namespace(results_bufnr, ns_telescope_entry, row, row + 1)
  local len_prefix = #prefix

  for _, hl_block in ipairs(display_highlights) do
    a.nvim_buf_add_highlight(
      results_bufnr,
      ns_telescope_entry,
      hl_block[2],
      row,
      len_prefix + hl_block[1][1],
      len_prefix + hl_block[1][2]
    )
  end
end

function Highlighter:clear_display()
  a.nvim_buf_clear_namespace(self.picker.results_bufnr, ns_telescope_entry, 0, -1)
end

function Highlighter:hi_sorter(row, prompt, display)
  local picker = self.picker
  if not picker.sorter or not picker.sorter.highlighter then
    return
  end

  local results_bufnr = assert(self.picker.results_bufnr, "Must have a results bufnr")
  picker:highlight_one_row(results_bufnr, prompt, display, row)
end

function Highlighter:hi_selection(row, caret)
  local results_bufnr = assert(self.picker.results_bufnr, "Must have a results bufnr")

  a.nvim_buf_clear_namespace(results_bufnr, ns_telescope_selection, 0, -1)
  a.nvim_buf_add_highlight(
    results_bufnr,
    ns_telescope_selection,
    'TelescopeSelectionCaret',
    row,
    0,
    #caret
  )

  a.nvim_buf_add_highlight(
    results_bufnr,
    ns_telescope_selection,
    'TelescopeSelection',
    row,
    #caret,
    -1
  )
end

function Highlighter:hi_multiselect(row, entry)
  local results_bufnr = assert(self.picker.results_bufnr, "Must have a results bufnr")

  if self.picker.multi_select[entry] then
    vim.api.nvim_buf_add_highlight(
      results_bufnr,
      ns_telescope_multiselection,
      "TelescopeMultiSelection",
      row,
      0,
      -1
    )
  else
    vim.api.nvim_buf_clear_namespace(
      results_bufnr,
      ns_telescope_multiselection,
      row,
      row + 1
    )
  end
end

highlights.new = function(...)
  return Highlighter:new(...)
end

return highlights
