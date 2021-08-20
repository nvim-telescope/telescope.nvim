local user = vim.loop.os_getenv "USER"

return require("plenary.log").new {
  plugin = "telescope",
  level = ((user == "tj" or user == "tjdevries") and "debug") or "warn",
}
