if !has('nvim-0.5')
  echoerr "Telescope.nvim requires at least nvim-0.5. Please update or uninstall"
  finish
end

if exists('g:loaded_telescope')
  finish
endif
let g:loaded_telescope = 1

" Sets the highlight for selected items within the picker.
highlight default link TelescopeSelection Visual
highlight default link TelescopeSelectionCaret TelescopeSelection
highlight default link TelescopeMultiSelection Type

" "Normal" in the floating windows created by telescope.
highlight default link TelescopeNormal Normal

" "Normal" in the preview floating windows created by telescope.
highlight default link TelescopePreviewNormal Normal

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

" Used for highlighting the matched line inside Previewer. Works only for (vim_buffer_ previewer)
highlight default link TelescopePreviewLine Visual
highlight default link TelescopePreviewMatch Search

highlight default link TelescopePreviewPipe Constant
highlight default link TelescopePreviewCharDev Constant
highlight default link TelescopePreviewDirectory Directory
highlight default link TelescopePreviewBlock Constant
highlight default link TelescopePreviewLink Special
highlight default link TelescopePreviewSocket Statement
highlight default link TelescopePreviewNormal Normal
highlight default link TelescopePreviewRead Constant
highlight default link TelescopePreviewWrite Statement
highlight default link TelescopePreviewExecute String
highlight default link TelescopePreviewHyphen NonText
highlight default link TelescopePreviewSticky Keyword
highlight default link TelescopePreviewSize String
highlight default link TelescopePreviewUser Constant
highlight default link TelescopePreviewGroup Constant
highlight default link TelescopePreviewDate Directory

" Used for Picker specific Results highlighting
highlight default link TelescopeResultsClass Function
highlight default link TelescopeResultsConstant Constant
highlight default link TelescopeResultsField Function
highlight default link TelescopeResultsFunction Function
highlight default link TelescopeResultsMethod Method
highlight default link TelescopeResultsOperator Operator
highlight default link TelescopeResultsStruct Struct
highlight default link TelescopeResultsVariable SpecialChar

highlight default link TelescopeResultsLineNr LineNr
highlight default link TelescopeResultsIdentifier Identifier
highlight default link TelescopeResultsNumber Number
highlight default link TelescopeResultsComment Comment
highlight default link TelescopeResultsSpecialComment SpecialComment

" Used for git status Results highlighting
highlight default link TelescopeResultsDiffChange DiffChange
highlight default link TelescopeResultsDiffAdd DiffAdd
highlight default link TelescopeResultsDiffDelete DiffDelete
highlight default link TelescopeResultsDiffUntracked NonText

" This is like "<C-R>" in your terminal.
"   To use it, do `cmap <C-R> <Plug>(TelescopeFuzzyCommandSearch)
cnoremap <silent> <Plug>(TelescopeFuzzyCommandSearch) <C-\>e
      \ "lua require('telescope.builtin').command_history {
        \ default_text = [=[" . escape(getcmdline(), '"') . "]=]
        \ }"<CR><CR>

" Telescope builtin lists
function! s:telescope_complete(arg,line,pos)
  let l:builtin_list = luaeval('vim.tbl_keys(require("telescope.builtin"))')
  let l:extensions_list = luaeval('vim.tbl_keys(require("telescope._extensions").manager)')
  let l:options_list = luaeval('vim.tbl_keys(require("telescope.config").values)')
  let l:extensions_subcommand_dict = luaeval('require("telescope.command").get_extensions_subcommand()')

  let list = [extend(l:builtin_list,l:extensions_list),l:options_list]
  let l = split(a:line[:a:pos-1], '\%(\%(\%(^\|[^\\]\)\\\)\@<!\s\)\+', 1)
  let n = len(l) - index(l, 'Telescope') - 2

  if n == 0
    return join(list[0],"\n")
  endif

  if n == 1
    if index(l:extensions_list,l[1]) >= 0
      return join(get(l:extensions_subcommand_dict, l[1], []),"\n")
    endif
    return join(list[1],"\n")
  endif

  if n > 1
    return join(list[1],"\n")
  endif
endfunction

" Telescope Commands with complete
command! -nargs=* -complete=custom,s:telescope_complete Telescope    lua require('telescope.command').load_command(<f-args>)
