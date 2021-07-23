local log = require "telescope.log"

local deprecated = {}

deprecated.picker_window_options = function(opts)
  local messages = {}

  -- Deprecated: PR:922, 2021/06/25
  -- Can be removed in a few weeks.

  if opts.shorten_path then
    table.insert(
      messages,
      "'opts.shorten_path' is no longer valid. Please use 'opts.path_display' instead. "
        .. "Please See ':help telescope.changelog-839'"
    )
  end

  if opts.hide_filename then
    table.insert(
      messages,
      "'opts.hide_filename' is no longer valid. Please use 'opts.path_display' instead. "
        .. "Please See ':help telescope.changelog-839'"
    )
  end

  if opts.width then
    table.insert(messages, "'opts.width' is no longer valid. Please use 'layout_config.width' instead")
  end

  if opts.height then
    table.insert(messages, "'opts.height' is no longer valid. Please use 'layout_config.height' instead")
  end

  if opts.results_height then
    table.insert(messages, "'opts.results_height' is no longer valid. Please see ':help telescope.changelog-922'")
  end

  if opts.results_width then
    table.insert(
      messages,
      "'opts.results_width' actually didn't do anything. Please see ':help telescope.changelog-922'"
    )
  end

  if opts.prompt_position then
    table.insert(
      messages,
      "'opts.prompt_position' is no longer valid. Please use 'layout_config.prompt_position' instead."
    )
  end

  if opts.preview_cutoff then
    table.insert(
      messages,
      "'opts.preview_cutoff' is no longer valid. Please use 'layout_config.preview_cutoff' instead."
    )
  end

  if #messages > 0 then
    table.insert(messages, 1, "Deprecated window options. Please see ':help telescope.changelog'")
    vim.api.nvim_err_write(table.concat(messages, "\n \n   ") .. "\n \nPress <Enter> to continue\n")
  end
end

deprecated.layout_configuration = function(user_defaults)
  if user_defaults.layout_defaults then
    if user_defaults.layout_config == nil then
      log.warn "Using 'layout_defaults' in setup() is deprecated. Use 'layout_config' instead."
      user_defaults.layout_config = user_defaults.layout_defaults
    else
      error "Using 'layout_defaults' in setup() is deprecated. Remove this key and use 'layout_config' instead."
    end
  end
  return user_defaults
end

return deprecated
