set rtp+=.
set rtp+=../plenary.nvim/
set rtp+=../popup.nvim/


set statusline=""
set statusline+=%<%f:%l:%v " filename:col:line/total lines
set statusline+=\ "
set statusline+=%h%m%r " help/modified/readonly
set statusline+=\ "
set statusline+=[%{&ft}] " filetype
set statusline+=%= " alignment group
set statusline+=\ "

" nnoremap <silent> <c-p> :lua require('telescope.builtin').git_files()<CR>
nnoremap <silent> <c-p> :lua require("telescope.builtin").find_files{ find_command = { "rg", "--smart-case", "--files", "--hidden", "--follow", "-g", "!.git/*" } }<CR>
