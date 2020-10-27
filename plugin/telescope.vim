
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
        
" Telescope Commands
function! s:telescope_complete(...)
  let telescope_builtin = [
      \ 'builtin','find_files','live_grep','grep_string','git_files',
      \ 'oldfiles','quickfix','loclist','command_history','buffers',
      \ 'lsp_references','lsp_document_symbol','lsp_workspace_symbol',
      \ 'lsp_code_actions','treesitter','planets','help_tags','man_pages',
      \ 'colorscheme','marks'
      \]
  return telescope_builtin
endfunction

function! s:load_command(builtin,...) abort
  let opts = {}

  " range command args
  for arg in a:000
    let opt = split(arg,'=')
    if opt[0] == 'theme'
      let theme = opt[1]
    else
      let opts[opt[0]] = opt[1]
    endif
  endfor

  let telescope = v:lua.require('telescope.builtin')
  call telescope[a:builtin](opts)
endfunction

" Telescope Commands
command! -nargs=+ -complete=customlist,s:telescope_complete Telescope          call s:load_command(<f-args>)
