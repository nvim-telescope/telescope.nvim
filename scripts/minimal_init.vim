set rtp+=.
set rtp+=../plenary.nvim/
set rtp+=../tree-sitter-lua/

runtime! plugin/plenary.vim
runtime! plugin/telescope.lua
runtime! plugin/ts_lua.vim

lua << EOF

require('telescope').setup {
  pickers = {
    find_files = {
      find_command = { 'fdfind', '--strip-cwd-prefix', '--type', 'f', }
    }
  }
}

EOF
