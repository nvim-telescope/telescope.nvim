
" Sets the highlight for selected items within the picker.
highlight default link TelescopeSelection Visual

" "Normal" in the floating windows created by telescope.
highlight default link TelescopeNormal Normal


" This is like "<C-R>" in your terminal.
"   To use it, do `cmap <C-R> <Plug>(TelescopeFuzzyCommandSearch)
cnoremap <silent> <Plug>(TelescopeFuzzyCommandSearch) <C-\>e
      \ "lua require('telescope.builtin').command_history {
        \ default_text = [=[" . escape(getcmdline(), '"') . "]=]
        \ }"<CR><CR>


lua PERF = function(...) end
