local M = {}

M.set_prompt = function(self)
  self._current_prefix_hl_group = hl_group or nil

  if self.prompt_prefix ~= "" then
    vim.api.nvim_buf_add_highlight(
      self.prompt_bufnr,
      ns_telescope_prompt_prefix,
      self._current_prefix_hl_group or "TelescopePromptPrefix",
      0,
      0,
      strdisplaywidth(self.prompt_prefix)
    )
  end
end

return M
