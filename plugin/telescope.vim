" let s:term_command = "rg preview_quit_map -l | fzf --preview 'bat --color=always --style=grid {-1}' --print0"
" let s:term_command = "rg preview_quit_map -l | fzf --preview 'bat --color=always --style=grid {-1}' > file.txt"
let s:term_command = "(rg preview_quit_map -l | fzf --preview 'bat --color=always --style=grid {-1}')"

function! s:on_exit() abort
  let g:result = readfile('file.txt')
endfunction

function! TestFunc() abort
  let g:term_output_stdout = []
  let g:term_output_stderr = []
  let g:term_output_onexit = []

  vnew
  let term_id = termopen(s:term_command, {
        \ 'on_stdout': { j, d, e -> add(g:term_output_stdout, d) },
        \ 'on_stderr': { j, d, e -> add(g:term_output_stderr, d) },
        \ 'on_exit': { j, d, e -> s:on_exit() },
        \ 'stdout_buffered': v:false,
        \ })
endfunction

function! PrintStuff() abort
  echo len(g:term_output_stdout) len(g:term_output_stderr) len(g:term_output_onexit)
endfunction

" call TestFunc()

" echo g:term_output_stdout[-1]
" echo g:term_output_stderr
" echo g:term_output_onexit
