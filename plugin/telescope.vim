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
  let ext_type = v:lua.require('telescope._extensions').manager
  let l:ext_type_list = []

  if !empty(ext_type)
    for val in values(ext_type)
      if type(val) == 3
        call extend(l:ext_type_list,keys(val))
      endif
    endfor
  endif

  let list = [extend(l:builtin_list,l:extensions_list),l:options_list]
  let l = split(a:line[:a:pos-1], '\%(\%(\%(^\|[^\\]\)\\\)\@<!\s\)\+', 1)
  let n = len(l) - index(l, 'Telescope') - 2

  if n == 0
    return join(list[0],"\n")
  endif

  if n == 1
    if index(l:extensions_list,l[1]) >= 0
      return join(l:ext_type_list,"\n")
    endif
    return join(list[1],"\n")
  endif

  if n > 1
    return join(list[1],"\n")
  endif
endfunction

function! s:load_command(builtin,...) abort
  let user_opts = {}
  let user_opts.cmd = a:builtin
  let user_opts.opts = {}

  " range command args
  " if arg in lua code is table type,we split command string by `,` to vimscript
  " list type.
  for arg in a:000
    if stridx(arg,'=') < 0
      let user_opts.extension_type = arg
      continue
    endif
    " split args by =
    let arg_list = split(arg,'=')
    if arg_list[0] == 'find_command' || arg_list[0] == 'vimgrep_arguments'
      let user_opts.opts[arg_list[0]] = split(arg_list[1],',')
    elseif arg_list[0] == 'theme'
      let user_opts.theme = arg_list[1]
    else
      let user_opts.opts[arg_list[0]] = arg_list[1]
    endif
  endfor

  call v:lua.require('telescope.command').run_command(user_opts)
endfunction

" Telescope Commands with complete
command! -nargs=+ -complete=custom,s:telescope_complete Telescope          call s:load_command(<f-args>)
