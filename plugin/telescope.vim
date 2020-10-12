
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
highlight default link TelescopeMatching NormalNC

" Used for the prompt prefix
highlight default link TelescopePromptPrefix Identifier

" This is like "<C-R>" in your terminal.
"   To use it, do `cmap <C-R> <Plug>(TelescopeFuzzyCommandSearch)
cnoremap <silent> <Plug>(TelescopeFuzzyCommandSearch) <C-\>e
      \ "lua require('telescope.builtin').command_history {
        \ default_text = [=[" . escape(getcmdline(), '"') . "]=]
        \ }"<CR><CR>
        
" Telescope Commands
command! -nargs=0 -bar TelescopeBuiltin lua require'telescope.builtin'.builtin{}
command! -nargs=0 -bar TelescopeFindFile lua require'telescope.builtin'.find_files{}
command! -nargs=0 -bar TelescopeLiveGrep lua require'telescope.builtin'.live_grep{}
command! -nargs=0 -bar TelescopeGrepString lua require'telescope.builtin'.grep_string{}
command! -nargs=0 -bar TelescopeFindGitFile lua require'telescope.builtin'.git_files{}
command! -nargs=0 -bar TelescopeOldFiles lua require'telescope.builtin'.oldfiles{}
command! -nargs=0 -bar TelescopeQuickFix lua require'telescope.builtin'.quickfix{}
command! -nargs=0 -bar TelescopeLocalList lua require'telescope.builtin'.loclist{}
command! -nargs=0 -bar TelescopeCommandHistory lua require'telescope.builtin'.command_history{}
command! -nargs=0 -bar TelescopeBuffers lua require'telescope.builtin'.buffers{}
command! -nargs=0 -bar TelescopeLspReferences lua require'telescope.builtin'.lsp_references{}
command! -nargs=0 -bar TelescopeLspDocumentSymbols lua require'telescope.builtin'.lsp_document_symbols{}
command! -nargs=0 -bar TelescopeLspWorkSpaceSymbols lua require'telescope.builtin'.lsp_workspace_symbols{}
command! -nargs=0 -bar TelescopeLspCodeActions lua require'telescope.builtin'.lsp_code_actions{}
command! -nargs=0 -bar TelescopeTreesitter lua require'telescope.builtin'.treesitter{}
command! -nargs=0 -bar TelescopePlanets lua require'telescope.builtin'.planets{}
command! -nargs=0 -bar TelescopeHelpTags lua require'telescope.builtin'.help_tags{}
command! -nargs=0 -bar TelescopeManPages lua require'telescope.builtin'.man_pages{}
command! -nargs=0 -bar TelescopeColorscheme lua require'telescope.builtin'.colorscheme{}
command! -nargs=0 -bar TelescopeMarks lua require'telescope.builtin'.marks{}

