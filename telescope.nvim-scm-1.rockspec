local MODREV, SPECREV = 'scm', '-1'
rockspec_format = '3.0'
package = 'telescope.nvim'
version = MODREV .. SPECREV

description = {
  summary = 'Find, Filter, Preview, Pick. All lua, all the time.',
  detailed = [[
  A highly extendable fuzzy finder over lists. 
  Built on the latest awesome features from neovim core. 
  Telescope is centered around modularity, allowing for easy customization.
  ]],
  labels = { 'neovim', 'plugin', },
  homepage = 'https://github.com/nvim-telescope/telescope.nvim',
  license = 'MIT',
}

dependencies = {
  'lua == 5.1',
  'plenary.nvim',
}

source = {
  url = 'https://github.com/nvim-telescope/telescope.nvim/archive/refs/tags/' .. MODREV .. '.zip',
  dir = 'telescope.nvim-' .. MODREV
}

if MODREV == 'scm' then
  source = {
    url = 'git://github.com/nvim-telescope/telescope.nvim',
  }
end

build = {
  type = 'builtin',
  copy_directories = {
    'doc',
    'ftplugin',
    'plugin',
    'scripts',
    'autoload',
    'data',
  }
}
