# Changelog

Breaking changes and other notable changes.

## Rewrite for modern Nvim API (unreleased)

Telescope no longer depends on plenary.nvim: it now uses Neovim's own APIs
(`vim.fs`, `vim.system`, `vim.async`, `vim.log`, native float borders) and
requires Nvim 0.13. Along the way it got a much faster built-in sorter with
fzf's query syntax, a `vim.ui.select` replacement, and many fixes.

### Major changes

- **No plenary.nvim** ([#3703](https://github.com/nvim-telescope/telescope.nvim/pull/3703),
  [#3704](https://github.com/nvim-telescope/telescope.nvim/pull/3704),
  [#3716](https://github.com/nvim-telescope/telescope.nvim/pull/3716),
  [#3717](https://github.com/nvim-telescope/telescope.nvim/pull/3717)): paths
  use `vim.fs`/`vim.uv`, external commands `vim.system()`, logging `vim.log`,
  and pickers and finders run in `vim.async` tasks (a find is cancelled as soon
  as the prompt changes). Pickers use native float borders and titles: three
  windows per picker instead of six.
- **Nvim 0.13 required** ([#3715](https://github.com/nvim-telescope/telescope.nvim/pull/3715)),
  checked by `:checkhealth telescope` (which also warns without LuaJIT).
- **New default sorter** ([#3710](https://github.com/nvim-telescope/telescope.nvim/pull/3710),
  [#3711](https://github.com/nvim-telescope/telescope.nvim/pull/3711)): the
  built-in Lua fzy sorter is about as fast as telescope-fzf-native, so no native
  build is needed. It understands fzf's query syntax (`'exact`, `^prefix`,
  `suffix$`, `!inverse`, `a | b`, space-separated terms that must all match),
  takes `case_mode` (`ignore_case`, `respect_case`, `smart_case`) and ranks
  file extensions and word boundaries like fzf.
- **Faster pickers** ([#3705](https://github.com/nvim-telescope/telescope.nvim/pull/3705),
  [#3710](https://github.com/nvim-telescope/telescope.nvim/pull/3710),
  [#3713](https://github.com/nvim-telescope/telescope.nvim/pull/3713),
  [#3717](https://github.com/nvim-telescope/telescope.nvim/pull/3717)):
  results are drawn in batches and highlighted with extmarks, an extended
  prompt only rescores the previous matches, `file_ignore_patterns` are checked
  once per entry, and command output is read per chunk; e.g. `buffers` with
  thousands of buffers opens in about 0.1 s instead of 3 s.
- **`vim.ui.select` replacement** ([#3707](https://github.com/nvim-telescope/telescope.nvim/pull/3707)):
  `vim.ui.select = require("telescope").ui_select` (configured as
  `pickers.ui_select`); this replaces telescope-ui-select. `pickers.new` takes
  an `on_close` callback.
- **Bug fixes** ([#3714](https://github.com/nvim-telescope/telescope.nvim/pull/3714),
  [#3719](https://github.com/nvim-telescope/telescope.nvim/pull/3719)), e.g.
  full entries in `command_history`/`search_history`, `additional_args` no
  longer growing with every `live_grep` call, mappings for modes other than
  normal and insert, and file names with special characters in LSP jumps and
  the bcommits diff. The documentation was checked against the code and
  corrected throughout.

### Breaking changes

- **Nvim 0.13 is required.** On older versions, telescope fails when it is
  loaded (e.g. `telescope/log.lua:1: attempt to call field 'new' (a nil
  value)`). Update Nvim, or pin telescope to the previous release.
- **plenary.nvim is no longer a dependency.** Configurations that use plenary
  themselves fail with `module 'plenary.path' not found` once it is no longer
  installed.
  - Plugin spec: `dependencies = { 'nvim-lua/plenary.nvim' }` → no dependency
    (keep plenary only if other plugins need it).
  - Config: e.g. a `preview.filesize_hook` that read the head of a file with
    `require("plenary.path"):new(filepath):head(height)` →
    `vim.fn.readfile(filepath, "", height)`.
- **The default sorter parses the prompt.** A space separates terms that must
  all match (in any order), and `'`, `^`, `$`, `!` and ` | ` are operators. No
  error, but some prompts match differently: `!ls` in `command_history` now
  lists commands *without* `ls`. To match these characters literally, start the
  term with `'`: `!ls` → `'!ls`, `^foo` → `'^foo`.
- **telescope-fzy-native is ignored** (its C module lacks the query syntax);
  the built-in sorter is used instead. telescope-fzf-native still works.
  Remove `load_extension("fzy_native")` and the plugin.
- **`utils.if_nil` is removed.** Error: `attempt to call field 'if_nil' (a nil
  value)`. `require("telescope.utils").if_nil(a, b)` → `vim.nonnil(a, b)`.
- **`pickers.fd` in the setup has no effect**: `builtin.fd` is an alias of
  `find_files` and uses its configuration. `pickers = { fd = {...} }` →
  `pickers = { find_files = {...} }`.
- **`quickfixhistory` takes `entry_maker`** like every other picker.
  `quickfixhistory({ make_entry = f })` → `quickfixhistory({ entry_maker = f })`.
- **`builtin.planets` is removed.** `:Telescope planets` reports "Unknown
  command".
- **Log messages are not shown in `:messages`**; warnings meant for users use
  `vim.notify`. Read the log file (`stdpath("log")/telescope.log`) instead; the
  level is set with
  `vim.log.set_level(require("telescope.log"), vim.log.levels.DEBUG)`.
- **Border characters must be single cells**: longer strings in
  `borderchars` are cut to their first character. `borderchars` takes 1, 2 or 8
  characters; other counts raise "borderchars: expected 1, 2 or 8 characters".
- **Directory previews show names only** (directories first with a trailing
  `/`), not `ls -la` lines; `preview.ls_short` is removed (ignored if set).
- **Previews detect the filetype from the file name only** (no shebang or
  modeline). Add patterns for files that are not detected by name with
  `vim.filetype.add()`.
- **`grep_string` in linewise or blockwise visual mode** searches the selection
  instead of the word under the cursor.
- **On Windows, paths use `/`** in results, `cwd` and displayed paths. Neovim
  and external tools accept both; mappings or configs that match `\` in paths
  should match `/`.

### Migration guide for extension authors

**plenary.** Telescope no longer installs plenary.nvim. If your extension uses
it, depend on it yourself.

**Async.** Finders (including the `fn` of `finders.new_dynamic`) run inside the
picker's `vim.async` task and must wait with `vim.async`; waiting with
plenary.async inside a finder fails with "Unexpected coroutine.yield()". A task
your extension starts on its own (outside a finder) may keep using plenary.
Conversion table (the callback position counts the callback itself):

| before (plenary.async) | after (`vim.async`, `:help lua-async`) |
| --- | --- |
| `async.wrap(f, 2)(x)` | `vim.async.await(2, f, x)` |
| `local g = async.wrap(f, n)` | `local g = vim.async.wrap(n, f)` |
| `async.util.scheduler()` | `vim.async.await(1, vim.schedule)` |
| `async.util.sleep(ms)` | `vim.async.sleep(ms)` |
| `async.uv.fs_stat(p)` (other `fs_*` alike) | `vim.async.await(2, vim.uv.fs_stat, p)` |
| `async.run(f)`, `async.void(f)` | `vim.async.run(f)` |

A oneshot channel around a callback API becomes one `await`:

```lua
-- before
local tx, rx = require("plenary.async.control").channel.oneshot()
cancel = vim.lsp.buf_request_all(bufnr, "workspace/symbol", { query = prompt }, tx)
local results = rx()
-- after
local results = vim.async.await(1, function(callback)
  cancel = vim.lsp.buf_request_all(bufnr, "workspace/symbol", { query = prompt }, callback)
end)
```

A find is closed by the next prompt change: the finder stops at its next wait,
and `process_result` still returns `true` for a stale find. See "Finders" in
[DEVELOPERS.md](DEVELOPERS.md) for the finder interface.

**Logging.** ` is a `vim.log` logger with `trace`/`debug`/`info`/`warn`/`error`
(no `use_console`, `fmt_*`); create your own with `vim.log.new({ name =
"my_extension" })`. Messages for users belong in `vim.notify`.

**Paths.**

| before | after |
| --- | --- |
| `require("plenary.path"):new(p):make_relative(cwd)` | `utils.make_relative(p, cwd)` |
| `require("plenary.path"):new(p):normalize(cwd)` | `utils.display_path(p, cwd)` |
| `require("plenary.path"):new(p):is_absolute()` | `utils.is_absolute(p)` |
| `require("plenary.path"):new(p):read()` | `vim.fn.readfile(p)` (or `vim.uv.fs_*`) |
| `require("plenary.path").path.sep`, `utils.get_separator()` | `"/"` (`utils.pathsep` is always `"/"`) |
| `require("plenary.strings").strdisplaywidth(s)` | `vim.fn.strdisplaywidth(s)` |

(`utils` is `require("telescope.utils")`.) Paths entering telescope are
normalized to `/` on Windows; `utils.path_tail()` still accepts `\`.
`utils.is_uri()` follows Neovim (`scheme:/…`; drive letters and `mailto:` are
not URIs).

**Removed functions and fields.**

- `utils.if_nil` → `vim.nonnil`; `utils.file_extension` → none (it was only
  used for devicons); `actions.insert_value` → none (it was unfinished).
- `require("telescope.algos.fzy")` → `require("telescope.algos.matcher")`
  (`has_match`, `score` and `positions` take an optional `case_sensitive`;
  scores differ for non-ASCII text and around punctuation). The `fzy_mod` option
  of `sorters.get_fzy_sorter` and `sorters.highlighter_only` is removed.
- `telescope.algos.linked_list` and the entry manager's `linked_states`,
  `get_container(i)` and `get_ordinal(i)` → `manager:num_results()`,
  `get_entry(i)` (`.ordinal`), `iter()`, `truncate(n)`.
- `Picker:entry_adder`, `Picker:_decrement` and `Picker:_next_find_id` are
  removed; `Picker:get_result_processor` and `get_result_completor` no longer
  take a find id. `picker.stats` keeps only `processed` and `filtered`.
- Border windows: `picker.layout.*.border.winid`/`bufnr` and the
  `{prompt,results,preview}_border_win` status entries are gone (the borders
  are part of the windows; `border:change_title()` still works).
- Jobs: `finders._new` is removed; `writer` in `finders.new_async_job` and
  `previewers.utils.job_maker` is removed, and `job_maker`'s `env` is added to
  the environment instead of replacing it. `telescope.async_job`: `NullPipe`,
  `convert_opts`, the `stdin`/`stderr` options and the `force` argument of
  `close` are removed; `spawn` takes only `command` and `args`.
- `previewers.utils.filetype_detect()` only uses the file name.
- `telescope.testharness` is removed; test with Neovim's test harness, as
  described in [CONTRIBUTING.md](CONTRIBUTING.md).

## Use `vim.filetype` in previewers ([#2529](https://github.com/nvim-telescope/telescope.nvim/pull/2529), June 09, 2023)

We finally removed usage of `plenary.filetype` to determine filetypes for
previewing and replaced it with `vim.filetype`. So if you have highlighting
issues you no longer have to configure `plenary`, but rather read
`:help vim.filetype`.

## Neovim 0.9.0 required ([#2499](https://github.com/nvim-telescope/telescope.nvim/pull/2499), May 24, 2023)

We decided to bump the minimum Neovim version to 0.9.0, in order to remove a
couple of no longer required workarounds. That includes using upstream
treesitter implementation in favor of nvim-treesitter.
If you still have a requirement for Neovim 0.7 or 0.8, we also have a stable
branch 0.1.x (or version, currently 0.1.1) which will not receive this version
bump and will continue to offer support for older Neovim versions.

## Dev branch merge before 0.1 ([#1945](https://github.com/nvim-telescope/telescope.nvim/pull/1945), July 01, 2022)

This is our dev branch which contains a lot of PRs, a lot of fixes,
refactoring and general quality of life improvements. It also contains new
features, the most noteworthy are the following (mostly developed by the
community):
- feat: none strategy & control attachment (#1867)
- feat: force buffer delete for terminal and improvements for
  Picker:delete_selection (#1943)
- feat(tags): process tagfiles on the fly (#1989)
- feat(builtin.lsp): implement builtin handlers for
  lsp.(incoming|outgoing)_calls (#1484)
- feat: clear previewer if no item is selected (#2004)
- feat: add min max boundary to width, height resolver (#2002)
- feat: Add entry_index for entry_makers (#1850)
- feat: refine with new_table (#1115)

The last one is one of the most exciting new features, because it allows you
to go from live_grep into a fuzzy environment with the following mapping
`<C-Space>`. It's a general interface we now implemented for `live_grep` and
`lsp_dynamic_workspace_symbols` but it could also be easily implemented for
other builtins, by us or the user. It's now available for extension developers.
We will add documentation in the next couple of days and improve it by adding
more options to configure it after the initial 0.1 release.

But as with all longer development phases, there are also some breaking
changes. This is the main reason we moved development to a separate branch, for
the past two months. We can't promise that there won't be more breaking
changes, but it is the plan that this is the last set of breaking changes prior
to the 0.1 release on July, 12. We are deeply sorry for the inconvenience. The
following breaking changes are included in this PR:
- break(git_files): change `show_untracked` default to false. Can be changed
  back with `:Telescope git_files show_untracked=true`
- break: deprecate `utils.get_default` `utils.if_nil`, will be removed prior
  to 0.1, so if you use it in your config, please move to `vim.F.if_nil`
- break: drops `ignore_filename` option, use `path_display= { "hidden" }`
  instead
- break: prefix internal interfaces with __ so
  `require("telescope.builtin.files").find_files` will show a notify error but
  still works for now. The error will be removed prior to 0.1! You should use
  `require("telescope.builtin").find_files` because we wrap all the functions
  that are exposed in this module.
- break: defaults.preview.treesitter rework that allows you to either enable a
  list of languages, or enable all and disable some. Please read
  `:help telescope.defaults.preview` for more information.
  Something like this is now possible:
  ```lua
  treesitter = {
    enable = false,
    -- or
    enable = { "c" },
    -- disable can be set if enable isn't set
    disable = { "perl", "javascript" },
  },
  ```

## Remove `lsp_code_actions` and `lsp_range_code_actions` ([#1866](https://github.com/nvim-telescope/telescope.nvim/pull/1866), April 25, 2022)

We decided to remove both `lsp_code_actions` and `lsp_range_code_actions`.
Currently, both functions are highly duplicated code from neovim, with fewer
features, because it's out of date. So rather that we copy over the required
changes to fix some bugs or implement client side code actions, we decided to
remove both of them and suggest you use `vim.lsp.buf.code_action` and
`vim.lsp.buf.range_code_action`. The transition to it is easy thanks to
`vim.ui.select` which allows you to override the select UI. We provide a small
extension for quite some time that make it easy to use telescope for
`vim.ui.select`. You can found the code here
https://github.com/nvim-telescope/telescope-ui-select.nvim. It offers the same
displaying as the current version of `lsp_code_actions`. An alternative is
https://github.com/stevearc/dressing.nvim which has support for multiple
different backends including telescope.

## Neovim 0.7.0 required ([#1851](https://github.com/nvim-telescope/telescope.nvim/pull/1851), April 22, 2022)

Telescope requires now Neovim release 0.7.0 or a more recent nightly.
If you are running Neovim nightly, you need to make sure that you are on the
LATEST version. Every other commit is not supported. So make sure you build
the newest nightly before reporting issues.
In the future, we will adopt a different release strategy. This release
strategy follows the approach that the latest telescope.nvim master will only
work with latest Neovim nightly and we will provide tags for specific Neovim
versions. You can read more about this strategy here:
https://github.com/nvim-telescope/telescope.nvim/issues/1772

## Move from `vim.lsp.diagnostic` to `vim.diagnostic` ([#1553](https://github.com/nvim-telescope/telescope.nvim/pull/1553), December 10, 2021)

Because the newly added `vim.diagnostic` has no longer anything to do with lsp
we also decided to rename our diagnostic functions:
- `Telescope lsp_document_diagnostics` -> `Telescope diagnostics bufnr=0`
- `Telescope lsp_workspace_diagnostics` -> `Telescope diagnostics`

Because of that the `lsp_*_diagnostics` inside Telescope will be deprecated
and removed soon. The new `diagnostics` works almost identical to the previous
functions. Note that there is no longer a workspace diagnostics. You can only
get all diagnostics for all open buffers.

## Neovim 0.6.0 required ([#1549](https://github.com/nvim-telescope/telescope.nvim/pull/1549), December 10, 2021)

Telescope requires now Neovim release 0.6.0 or a more recent nightly.
If you are running neovim nightly, you need to make sure that you are on the
LATEST version. Every other commit is not supported. So make sure you build
the newest nightly before reporting issues.

## Neovim 0.5.1 required ([#1406](https://github.com/nvim-telescope/telescope.nvim/pull/1406), November 4, 2021)

Due to making use of newly implemented extmark features, Telescope now
requires users to be on Neovim 0.5.1 (the most recent stable version) or on
the LATEST version of Neovim nightly.

## Deprecation of `telescope.path` ([#473](https://github.com/nvim-telescope/telescope.nvim/pull/473), July 14, 2021)

Extension developers need to move to plenary.path, because we will remove the
telescope.path module soon.

Guide to switch over to plenary.path:
- separator
  - before: `require("telescope.path").separator`
  - now: `require("plenary.path").path.sep`
- home
  - before: `require("telescope.path").home`
  - now: `require("plenary.path").path.home`
- make_relative
  - before: `require("telescope.path").make_relative(filepath, cwd)`
  - now: `require("plenary.path"):new(filepath):make_relative(cwd)`
- shorten
  - before: `require("telescope.path").shorten(filepath)`
  - now: `require("plenary.path"):new(filepath):shorten()` (with optional len,
    default is 1)
- normalize
  - before: `require("telescope.path").normalize(filepath, cwd)`
  - now: `require("plenary.path"):new(filepath):normalize(cwd)`
- read_file
  - before: `require("telescope.path").read_file(filepath)`
  - now: `require("plenary.path"):new(filepath):read()`
- read_file_async
  - before: `require("telescope.path").read_file_async(filepath, callback)`
  - now: `require("plenary.path"):new(filepath):read(callback)`

## `path_display` replaces `shorten_path` and `hide_filename` ([#839](https://github.com/nvim-telescope/telescope.nvim/pull/839), July 7, 2021)

Small breaking change regarding `shorten_path` and `hide_filename`.
This allows to configure path displays on a global level and offers a way for
extension developers to make use of the same configuration, offering a better
overall experience.

The new way to configure path displays is with `path_display`. It is a table
and accepts multiple values:
- `"hidden"`: hide file names
- `"tail"`: only display the file name, and not the path
- `"absolute"`: display absolute paths
- `"shorten"`: only display the first character of each directory in the path

See `:help telescope.defaults.path_display`.

Example would be for a global configuration:
```lua
require("telescope").setup{
  defaults = {
    path_display = {
      "shorten",
      "absolute",
    },
  }
}
```

You can also still pass this to a single builtin call:
```lua
require("telescope.builtin").find_files {
  path_display = { "shorten" }
}
```

For extension developers there is a new util function that can be used to
display a path:
```lua
local filename = utils.transform_path(opts, entry.filename)
```

## Layout configuration ([#922](https://github.com/nvim-telescope/telescope.nvim/pull/922), May 17, 2021)

This is one of our largest breaking changes thus far, so I (TJ) am adding some
information here so that you can more easily update (without having to track
down the commit, etc.).

The goal of these breaking changes is to greatly simplify the way
configuration for layouts happen. This should make it much easier to configure
each picker, layout_strategy, and more. Please report any bugs or behavior
that is broken / confusing upstream and we can try and make the configuration
better.

`telescope.setup()` has changed `layout_defaults` -> `layout_config`.
This makes it so that the setup and the pickers share the same key,
otherwise it is too confusing which key is for which.

`picker:find()` now has different values available for configuring the UI.
All configuration for the layout must be passed in the key `layout_config`.

Previously, these keys were passed via `picker:find(opts)`, but should be
passed via `opts.layout_config` now:
- `height`
- `width`
- `prompt_position`
- `preview_cutoff`

These keys are removed:
- `results_height`: This key is no longer valid. Instead, use `height` and the
  corresponding `preview_*` options for the layout strategy to get the correct
  results height. This simplifies the configuration for many of the existing
  strategies.
- `results_width`: This key actually never did anything. It was leftover from
  some hacking that I had attempted before. Instead you should be using
  something like the `preview_width` configuration option for the horizontal
  layout strategy (`:help telescope.layout_strategies.horizontal`).

You should get error messages when you try and use any of the above keys now.
