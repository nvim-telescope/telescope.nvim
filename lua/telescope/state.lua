local state = {}

TelescopeGlobalState = TelescopeGlobalState or {}

--- Set the status for a particular prompt bufnr
function state.set_status(prompt_bufnr, status)
  TelescopeGlobalState[prompt_bufnr] = status
end

function state.get_status(prompt_bufnr)
  return TelescopeGlobalState[prompt_bufnr] or {}
end

function state.clear_status(prompt_bufnr)
  state.set_status(prompt_bufnr, nil)
end

return state
