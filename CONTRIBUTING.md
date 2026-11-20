# Contributing

At this time, we are content with the number and functionality of the pickers we offer built
in with Telescope and so we are currently not accepting new pickers
(see this [issue](https://github.com/nvim-telescope/telescope.nvim/issues/1228) for a discussion on this).

We are also conservative with integrating picker specific actions and features.
If you're still interested in filling a particular picker need, we encourage packaging it up as its own Telescope extension.
Read our [Bundling as extension](https://github.com/nvim-telescope/telescope.nvim/blob/master/developers.md#bundling-as-extension) guide here for more info on this.
See other Telescope extensions (and add yours) [here](https://github.com/nvim-telescope/telescope.nvim/wiki/Extensions).

That said, we welcome bug fixes, documentation improvements and non-picker specific features.
If you're submitting a new feature, it is a good idea to create an issue first to gauge interest and feasibility.

Before opening a pull request, run the tests, the type check and the formatter, and regenerate the
documentation (see below); CI runs the same checks.

## Development

The `Makefile` downloads everything it needs into `.deps/` (`make clean` removes it, e.g. to update a
nightly build):

| Command | What it does |
| --- | --- |
| `make test` | Runs the test suite (see [Tests](#tests)). |
| `make lint` | Checks the types and annotations with [emmylua_check](https://github.com/EmmyLuaLs/emmylua-analyzer-rust) (downloaded on Linux and macOS; elsewhere set `EMMYLUALS` to the directory of your `emmylua_check`); it must report "No issues found". |
| `make docs` | Regenerates `doc/telescope.txt` from the annotations and checks that every `\|tag\|` reference exists. |
| `stylua .` | Formats the code with [StyLua](https://github.com/JohnnyMorganz/StyLua) (configured in `.stylua.toml`; CI runs `stylua --check .`). |

All targets use Neovim release builds downloaded from GitHub: `make test` and `make lint` the one
given by `NVIM_VERSION` (default `nightly`), `make docs` the host Neovim of the tests (see
[Tests](#tests)).

## Tests

```sh
make test                                              # all tests
make test TEST_FILE=tests/automated/utils_spec.lua     # one file (or a directory)
make test NVIM_VERSION=<tag>                           # against another Neovim release (e.g. stable)
```

CI runs the tests on Linux, macOS and Windows.

### How the tests run

The tests use Neovim's own test harness (the one for its functional tests), with two Neovim
processes:

- The **host** Neovim (`NVIM_HOST_VERSION` in the `Makefile`) runs the test runner and the spec
  files: `describe`/`it` blocks, hooks and assertions all run here.
- The **Nvim under test** (`NVIM_VERSION`) runs telescope. `sut.setup()` at the top of a spec file
  starts one for that file, with `--clean` and `tests/minimal_init.lua` (telescope on the
  runtimepath, no other plugins or user config). The tests of a file share it, so a test that
  changes state (opens a picker, creates buffers, sets options) must restore it, e.g. in an
  `after_each`.

The spec talks to the Nvim under test through `exec_lua()`, `api` and `fn` from
`test/functional/testnvim.lua`:

- `exec_lua(function() ... end)` runs the function in the Nvim under test and returns its result.
- `n.api.nvim_*` and `n.fn.*` call API and Vimscript functions there (for editor state that doesn't
  need telescope code).

The harness modules (`test.testutil`, `test.functional.testnvim`, ...) are downloaded with the host
Neovim; `tests/helper.lua` sets up the environment for them.

### Adding a test

Specs live in `tests/automated/` and end in `_spec.lua` (picker tests in `tests/automated/pickers/`).
A spec file starts like this:

```lua
local t = require("test.testutil")
local sut = require("tests.sut")
local describe, it, eq = t.describe, t.it, t.eq
local n = require("test.functional.testnvim")()
local exec_lua = n.exec_lua

sut.setup()

-- a wrapper for a function you call in several tests
local function path_tail(path)
  return exec_lua(function()
    return require("telescope.utils").path_tail(path)
  end)
end

describe("path_tail", function()
  it("returns the last component", function()
    eq("init.lua", path_tail("lua/telescope/init.lua"))
  end)
end)
```

- For a single value, call the code with `exec_lua()` and check the result in the host with
  `t.eq`, `t.ok`, `t.matches`, `t.pcall_err`, ...; give calls you repeat a wrapper as above.
- For a scenario with several steps (a picker, callbacks, state that is not plain data), write one
  `exec_lua()` chunk and assert inside it with `require("test.assert")` (`eq`, `ok`, ...):

  ```lua
  it("finds the readme", function()
    exec_lua(function()
      local h = require("tests.picker_helpers")
      local eq = require("test.assert").eq
      local picker = h.picker("find_files", { disable_devicons = true })
      h.type(picker, "README.md")
      eq("README.md", h.select(picker))
    end)
  end)
  ```

  `tests/picker_helpers.lua` (loaded in the Nvim under test) opens a builtin picker, types into the
  prompt and waits for the results, reads the prompt and results, selects an entry and cleans up
  (call `cleanup()` in an `after_each`). The picker tests search the files in `tests/fixtures/`.
- Use `t.is_os("win")` for behaviour that differs on Windows.

Things to keep in mind with `exec_lua()`:

- The function is sent to the Nvim under test as bytecode: upvalues (local variables of the spec
  that the function uses), arguments and return values must be plain data (strings, numbers,
  booleans, tables of those), not functions or userdata. A function gives "can't serialize object
  of type 6", and the following tests of the file fail as well.
- A table with both list items and keys loses its list part.
- An error inside the function is reported at the line of the `exec_lua()` call, not at the line in
  the function.
- Don't set globals in the Nvim under test to pass state between calls; put the steps into one
  chunk instead.

## Documentation

The vimdoc `doc/telescope.txt` is generated from the code using emmylua annotations (`---`
comments, see the existing ones and [docgen.nvim](https://github.com/jamestrew/docgen.nvim)); the
setup options are documented in the descriptions in `lua/telescope/config.lua`. Don't edit
`doc/telescope.txt` by hand: change the annotations and run `make docs`. A "Check docs" workflow in
CI ensures that the documentation matches the code and that all help tags in it exist. Functions
that should not show up in the docs use plain `--` comments.
