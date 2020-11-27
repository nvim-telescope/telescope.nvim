
" Sets the highlight for selected items within the picker.
highlight default link TelescopeSelection Visual
highlight default link TelescopeSelectionCaret TelescopeSelection
highlight default link TelescopeMultiSelection Type

" "Normal" in the floating windows created by telescope.
highlight default link TelescopeNormal Normal

" Border highlight groups.
"   Use TelescopeBorder to override the default.
"   Otherwise set them specifically
highlight default link TelescopeBorder TelescopeNormal
highlight default link TelescopePromptBorder TelescopeBorder
highlight default link TelescopeResultsBorder TelescopeBorder
highlight default link TelescopePreviewBorder TelescopeBorder

" Used for highlighting characters that you match.
highlight default link TelescopeMatching Special

" Used for the prompt prefix
highlight default link TelescopePromptPrefix Identifier

" This is like "<C-R>" in your terminal.
"   To use it, do `cmap <C-R> <Plug>(TelescopeFuzzyCommandSearch)
cnoremap <silent> <Plug>(TelescopeFuzzyCommandSearch) <C-\>e
      \ "lua require('telescope.builtin').command_history {
        \ default_text = [=[" . escape(getcmdline(), '"') . "]=]
        \ }"<CR><CR>
        
" Telescope builtin lists
function! s:telescope_complete(...)
  return join(luaeval('vim.tbl_keys(require("telescope.builtin"))'), "\n")
endfunction

" TODO: If the lua datatype contains complex type,It will cause convert to
" viml datatype failed. So current doesn't support config telescope.themes
function! s:load_command(builtin,...) abort
  let opts = {}

  " range command args
  " if arg in lua code is table type,we split command string by `,` to vimscript
  " list type.
  for arg in a:000
    let opt = split(arg,'=')
    if opt[0] == 'find_command' || opt[0] == 'vimgrep_arguments'
      let opts[opt[0]] = split(opt[1],',')
    else
      let opts[opt[0]] = opt[1]
    endif
  endfor

  let telescope = v:lua.require('telescope.builtin')
  call telescope[a:builtin](opts)
endfunction

" Telescope Commands with complete 
command! -nargs=+ -complete=custom,s:telescope_complete Telescope          call s:load_command(<f-args>)
