
set rtp+=.
set rtp+=../plenary.nvim
set rtp+=../popup.nvim

packadd popup.nvim
packadd plenary.nvim

nnoremap ,,x :luafile %<CR>
nnoremap ,x :execute 'lua ' . getline('.')<CR>
