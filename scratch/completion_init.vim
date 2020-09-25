
set rtp+=.
set rtp+=../plenary.nvim/
set rtp+=../popup.nvim/

source plugin/telescope.vim

inoremap <tab> <c-n>

let case = 1

if case == 1
  set completeopt=menu
endif
