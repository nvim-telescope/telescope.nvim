
local deprecated = {}

deprecated.picker_window_options = function(opts)
  local messages = {}

  -- Deprecated: PR:823, 2021/05/17
  -- Can be removed in a few weeks.

  if opts.width then
    table.insert(messages, "'width' is no longer valid. Please use 'layout_config.width' instead")
  end

  if opts.height then
    table.insert(messages, "'height' is no longer valid. Please use 'layout_config.height' instead")
  end

  if opts.results_height then
    table.insert(messages, "'results_height' is no longer valid. Please use 'layout_config.results_height' instead")
  end

  if opts.prompt_position then
    table.insert(messages,
      "'prompt_position' is no longer valid. Please use 'layout_config.prompt_position' instead."
      .. "\nOnly valid for the `horizontal` configuration"
    )
  end

  if opts.preview_cutoff then
    table.insert(messages, "'preview_cutoff' is no longer valid. Please use 'layout_config.preview_cutoff' instead.")
  end

  if #messages > 0 then
    table.insert(messages, 1, "Deprecated window options. Please see ':help telescope.changelog'")
    vim.api.nvim_err_write(table.concat(messages, "\n") .. "\n")
  end
end

return deprecated
