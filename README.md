# telescope.nvim

Gaze deeply into unknown regions using the power of the moon.

![Example](./media/simple_rg_v1.gif)

## Installation

```vim
Plug 'nvim-lua/popup.nvim'
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-lua/telescope.nvim'
```

## Usage

(I will write a longer description later about how to create each of the objects described in Pipeline)

There is currently a fuzzy finder for git files builtin:

```lua
-- Fuzzy find over git files in your directory
require('telescope.builtin').git_files()

-- Grep as you type (requires rg currently)
require('telescope.builtin').live_grep()

-- Use builtin LSP to request references under cursor. Fuzzy find over results.
require('telescope.builtin').lsp_references()

-- Convert currently quickfixlist to telescope
require('telescope.builtin').quickfix()
```

## Status (Unstable API)

While the underlying API & Infrastructure (A.K.A. Spaghetti Code) is still very much WIP and
will probably change quite a bit, the functions in `builtin` should be relatively stable (as
in, you can report bugs if they don't work, you should be able to keep them around in your config
even if everything inside of those functions is rewritten. They provide pretty simple, easy to use
wrappers over common tasks).


## Goals


### Pipeline Different Objects

(Please note, this section is still in progress)

"finder":
- executable: rg, git ls-files, ...
- things in lua already
- vim things

"picker":
- fzf
- sk
- does this always need to be fuzzy?
    - you'll map what you want to do with vimscript / lua mappings

"previewer":
- sometimes built-in
- sometimes a lua callback


As an example, you could pipe your inputs into fzf, and then it can sort them for you.

fzf:
- have a list of inputs
- i have a prompt/things people typed
- instantly return the stuff via stdout
