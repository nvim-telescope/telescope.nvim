local utils = require "telescope.utils"
--[[ =============================================================================

Get metadata from entries.

This file is still WIP, so expect some changes if you're trying to consume these APIs.

This will provide standard mechanism for accessing information from an entry.

--============================================================================= ]]

local from_entry = {}

function from_entry.path(entry, validate, escape)
  escape = vim.F.if_nil(escape, true)
  local path
  if escape then
    path = entry.path and vim.fn.fnameescape(entry.path) or nil
  else
    path = entry.path
  end

  if path == nil then
    path = entry.filename
  end
  if path == nil then
    path = entry.value
  end
  if path == nil then
    utils.notify("from_entry.path", {
      msg = "Invalid Entry:" .. vim.inspect(entry),
      level = "ERROR",
      report = true,
    })
    return
  end

  if validate and not vim.fn.filereadable(path) then
    return
  end

  return path
end

return from_entry
