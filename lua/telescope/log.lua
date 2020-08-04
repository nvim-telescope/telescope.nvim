-- https://raw.githubusercontent.com/rxi/log.lua/master/log.lua
-- log.lua
--
-- Copyright (c) 2016 rxi
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

local log = { _version = "0.1.0" }

log.usecolor = true
log.outfile = vim.fn.stdpath('data') .. '/telescope.log'
log.console = false
log.level = "trace"


local modes = {
  { name = "trace", color = "\27[34m", },
  { name = "debug", color = "\27[36m", },
  { name = "info",  color = "\27[32m", },
  { name = "warn",  color = "\27[33m", },
  { name = "error", color = "\27[31m", },
  { name = "fatal", color = "\27[35m", },
}


local levels = {}
for i, v in ipairs(modes) do
  levels[v.name] = i
end


local round = function(x, increment)
  increment = increment or 1
  x = x / increment
  return (x > 0 and math.floor(x + .5) or math.ceil(x - .5)) * increment
end

for i, x in ipairs(modes) do
  local nameupper = x.name:upper()
  log[x.name] = function(...)
    -- Return early if we're below the log level
    if i < levels[log.level] then
      return
    end

    local passed = {...}
    local fmt = table.remove(passed, 1)
    local inspected = {}
    for _, v in ipairs(passed) do
      table.insert(inspected, vim.inspect(v))
    end
    local msg = string.format(fmt, unpack(inspected))
    local info = debug.getinfo(2, "Sl")
    local lineinfo = info.short_src .. ":" .. info.currentline

    -- Output to console
    if log.console then
      print(string.format("%s[%-6s%s]%s %s: %s",
                          log.usecolor and x.color or "",
                          nameupper,
                          os.date("%H:%M:%S"),
                          log.usecolor and "\27[0m" or "",
                          lineinfo,
                          msg))
    end

    -- Output to log file
    if log.outfile then
      local fp = io.open(log.outfile, "a")
      local str = string.format("[%-6s%s] %s: %s\n",
                                nameupper, os.date(), lineinfo, msg)
      fp:write(str)
      fp:close()
    end

  end
end

log.info("Logger Succesfully Loaded")

return log
