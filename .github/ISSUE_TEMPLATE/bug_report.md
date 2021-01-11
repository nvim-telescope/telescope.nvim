---
name: Bug report
about: Create a report to help us improve
title: ''
labels: bug
assignees: ''

---

<!-- @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
> Please make sure to take the time adhere fully the following template.
> So that the team can understand the issue and solve it very quickly,
> else the issue will be marked "missing issue template" and
> close right away!!!!!

TODO:
- Include test.vim content in details section (see configuration sec)
- Add description
- Add reproduce steps
- Add Expected and Actual behavior
- Include Environment information

TIP: copy the template to your vim buffer
@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@ -->

### Description
<!-- Whats wrong? what is not working? what Issue(s) are you facing?, when ....  -->

**Expected Behavior**
<!-- what is the Expected Behaviour in the steps you've defined above? -->

**Actual Behavior**
<!-- what is the Actual Behaviour your getting from the steps you've defined above? -->

### Details

<!-- Steps to reproduce -->
<details><summary>Reproduce</summary>

<!--
Example:

1. nvim -nu test.vim
2. :Telescope live_grep or git_commits
3. .... bang here is the issue
...
-->

1. nvim -nu test.vim
2. 
3. 
</details>

<!-- Environment Information -->
<details><summary>Environment</summary>

<!--
- nvim --version
- Operating system
- git log --pretty=format:'%h' -n 1
...
-->
- nvim --version output: 
- Operating system: 
- Telescope commit: 

</details>

<!-- Configuration -->
<details><summary>Configuration</summary>
<p>
<!-- adopt your telescope configuration to the following template,
save it to test.vim then execute `nvim -NU test.vim` -->

```viml
set nocompatible hidden laststatus=2

if !filereadable('/tmp/plug.vim')
  silent !curl --insecure -fLo /tmp/plug.vim
    \ https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
endif

source /tmp/plug.vim
call plug#begin('/tmp/plugged')
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim'
call plug#end()

autocmd VimEnter * PlugClean! | PlugUpdate --sync | close
lua << EOF

require('telescope').setup{
  defaults = {
    vimgrep_arguments = {
      'rg',
      '--color=never',
      '--no-heading',
      '--with-filename',
      '--line-number',
      '--column',
      '--smart-case'
    },
    prompt_position = "bottom",
    prompt_prefix = ">",
    selection_strategy = "reset",
    sorting_strategy = "descending",
    layout_strategy = "horizontal",
    layout_defaults = {},
    file_ignore_patterns = {},
    shorten_path = true,
    winblend = 0,
    width = 0.75,
    preview_cutoff = 120,
    results_height = 1,
    results_width = 0.8,
    border = {},
    borderchars = { '─', '│', '─', '│', '╭', '╮', '╯', '╰'},
    color_devicons = true,
    use_less = true,
  }
}
EOF
```
