local Previewer = {}
Previewer.__index = Previewer

function Previewer:new(opts)
  opts = opts or {}

  return setmetatable({
    state = nil,
    _title_fn = opts.title,
    _dyn_title_fn = opts.dyn_title,
    _setup_func = opts.setup,
    _teardown_func = opts.teardown,
    _send_input = opts.send_input,
    _scroll_fn = opts.scroll_fn,
    preview_fn = opts.preview_fn,
  }, Previewer)
end

function Previewer:preview(entry, status)
  if not entry then
    return
  end

  if not self.state then
    if self._setup_func then
      self.state = self:_setup_func(status)
    else
      self.state = {}
    end
  end

  return self:preview_fn(entry, status)
end

function Previewer:title()
  if self._title_fn then
    return self:_title_fn()
  end
  return "Preview"
end

function Previewer:dynamic_title(entry)
  if self._title_fn then
    return self:_dyn_title_fn(entry)
  end
  return "Preview"
end

function Previewer:teardown()
  if self._teardown_func then
    self:_teardown_func()
  end
end

function Previewer:send_input(input)
  if self._send_input then
    self:_send_input(input)
  else
    vim.api.nvim_err_writeln "send_input is not defined for this previewer"
  end
end

function Previewer:scroll_fn(direction)
  if self._scroll_fn then
    self:_scroll_fn(direction)
  else
    vim.api.nvim_err_writeln "scroll_fn is not defined for this previewer"
  end
end

return Previewer
