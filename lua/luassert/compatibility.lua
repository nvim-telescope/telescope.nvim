-- no longer needed, only for backward compatibility
local unpack = require("luassert.util").unpack

return {
  unpack = function(...)
    print(
      debug.traceback "WARN: calling deprecated function 'luassert.compatibility.unpack' use 'luassert.util.unpack' instead"
    )
    return unpack(...)
  end,
}
