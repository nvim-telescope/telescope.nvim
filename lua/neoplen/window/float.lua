_AssociatedBufs = {}

local M = {}

function M.clear(bufnr)
  if _AssociatedBufs[bufnr] == nil then
    return
  end

  for _, win_id in ipairs(_AssociatedBufs[bufnr]) do
    if vim.api.nvim_win_is_valid(win_id) then
      vim.api.nvim_win_close(win_id, true)
    end
  end

  _AssociatedBufs[bufnr] = nil
end

return M
