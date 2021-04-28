local state = {}

_TelescopeGlobalState = _TelescopeGlobalState or {}
_TelescopeGlobalState.global = _TelescopeGlobalState.global or {}
_TelescopeGlobalState.prompt = _TelescopeGlobalState.prompt or {}

function state.set_global_key(key, value)
  _TelescopeGlobalState.global[key] = value
end

function state.get_global_key(key)
  return _TelescopeGlobalState.global[key]
end

function state.set_current_picker(picker)
  local old_picker = state.get_current_picker()
  if old_picker then
    old_picker:teardown()
    old_picker = nil
  end

  state.set_global_key('picker', picker)
end

function state.get_current_picker()
  return state.get_global_key('picker')
end

--- Set the status for a particular prompt bufnr
function state.set_status(prompt_bufnr, status)
  _TelescopeGlobalState.prompt[prompt_bufnr] = status
end

function state.get_status(prompt_bufnr)
  return _TelescopeGlobalState.prompt[prompt_bufnr] or {}
end

function state.clear_status(prompt_bufnr)
  state.set_status(prompt_bufnr, nil)
end

function state.get_existing_prompts()
  return vim.tbl_keys(_TelescopeGlobalState.prompt)
end

return state
