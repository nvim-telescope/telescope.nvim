
return require('plenary.log').new {
  plugin = 'telescope',
  level = (vim.loop.os_getenv("USER") == 'tj' and 'debug') or 'warn',
}
