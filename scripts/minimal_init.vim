set rtp+=.
set rtp+=deps/plenary.nvim/
set rtp+=deps/tree-sitter-lua/
set rtp+=deps/nvim-web-devicons/

runtime! plugin/plenary.vim
runtime! plugin/telescope.lua
" runtime! plugin/ts_lua.vim

let g:telescope_test_delay = 100
