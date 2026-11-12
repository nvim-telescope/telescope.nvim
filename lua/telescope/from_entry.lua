--[[ =============================================================================

Get metadata from entries.

This file is still WIP, so expect some changes if you're trying to consume these APIs.

This will provide standard mechanism for accessing information from an entry.

--============================================================================= ]]
local utils = require "telescope.utils"

local from_entry = {}

function from_entry.path(entry, validate, escape)
  escape = vim.nonnil(escape, true)
  local path = entry.path or entry.filename or entry.value
  if path == nil then
    utils.notify("from_entry.path", { msg = ("Invalid entry: '%s'"):format(vim.inspect(entry)), level = "ERROR" })
    return
  end

  -- only 0 if neither filereadable nor directory
  if validate and path ~= "[No Name]" then
    -- We need to expand for filereadable and isdirectory
    -- TODO(conni2461): we are not going to return the expanded path because
    --                  this would lead to cache misses in the perviewer.
    --                  Requires overall refactoring in previewer interface
    local expanded = utils.path_expand(path)
    if (vim.fn.filereadable(expanded) + vim.fn.isdirectory(expanded)) == 0 then
      return
    end
  end
  if escape then
    return vim.fn.fnameescape(path)
  end
  return path
end

return from_entry
