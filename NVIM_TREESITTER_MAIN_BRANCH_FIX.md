# Fix for nvim-treesitter main branch compatibility

## Issue

The `treesitter` picker in telescope.nvim was not compatible with nvim-treesitter's `main` branch, only working with the `master` branch.

Related issue: https://github.com/nvim-telescope/telescope.nvim/issues/3547

## Root Cause

nvim-treesitter's `main` branch underwent a major rewrite that removed several modules and functions:

1. **Removed `parsers.get_buf_lang()`** - Used to get language from buffer
2. **Removed `parsers.has_parser()`** - Used to check if parser exists
3. **Removed `nvim-treesitter.locals` module** - Used to extract symbol definitions
4. **Removed `nvim-treesitter.configs` module** - Used for plugin configuration

The `main` branch now relies primarily on Neovim's built-in treesitter APIs (available since Neovim 0.9.0).

## Investigation Process

### 1. Initial Error
```
attempt to call field 'get_buf_lang' (a nil value)
```

Location: `lua/telescope/builtin/__files.lua:426`

### 2. API Comparison

#### Master branch (old API)
- `parsers.get_buf_lang(bufnr)` - Get language from buffer
- `parsers.has_parser(lang)` - Check parser existence
- `ts_locals.get_definitions(bufnr)` - Extract definitions
- `require("nvim-treesitter.configs").setup({...})` - Configure plugin

#### Main branch (new API)
- Uses Neovim built-in `vim.treesitter.language.get_lang(filetype)`
- Uses Neovim built-in `vim.treesitter.language.add(lang)` for parser checking
- Uses Neovim built-in `vim.treesitter.query.get(lang, "locals")` for queries
- Uses `require("nvim-treesitter").setup({...})` for configuration

### 3. Compatibility Check

Verified that `vim.treesitter.language.get_lang()` exists in Neovim 0.9.0:
- Source: https://github.com/neovim/neovim/blob/v0.9.0/runtime/lua/vim/treesitter/language.lua
- telescope.nvim already uses this API in other locations (e.g., `current_buffer_fuzzy_find`)

## Solution

### Changes in `lua/telescope/builtin/__files.lua`

#### Change 1: Language Detection (line 425-428)

**Before:**
```lua
local parsers = require "nvim-treesitter.parsers"
if not parsers.has_parser(parsers.get_buf_lang(opts.bufnr)) then
```

**After:**
```lua
-- Get buffer's filetype and convert to language
local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")
local lang = vim.treesitter.language.get_lang(filetype) or filetype

-- Check if parser exists
if not utils.has_ts_parser(lang) then
```

#### Change 2: Symbol Extraction (line 439-477)

**Before:**
```lua
local ts_locals = require "nvim-treesitter.locals"
local results = {}
for _, definition in ipairs(ts_locals.get_definitions(opts.bufnr)) do
  local entries = prepare_match(ts_locals.get_local_nodes(definition))
  for _, entry in ipairs(entries) do
    entry.kind = vim.F.if_nil(entry.kind, "")
    table.insert(results, entry)
  end
end
```

**After:**
```lua
-- Get tree and query for symbols
local parser = vim.treesitter.get_parser(bufnr, lang)
local tree = parser:parse()[1]
local root = tree:root()

-- Try to get locals query, fallback to basic symbol extraction if not available
local query = vim.treesitter.query.get(lang, "locals")
local results = {}

if query then
  -- Use locals query to find definitions
  for id, node, metadata in query:iter_captures(root, bufnr) do
    local capture_name = query.captures[id]
    -- Match both "definition.X" and "local.definition.X" patterns
    if capture_name:match("definition%.function")
       or capture_name:match("definition%.method")
       or capture_name:match("definition%.var")
       or capture_name:match("definition%.type")
       or capture_name:match("definition%.class")
       or capture_name:match("definition%.field")
       or capture_name:match("definition%.parameter")
       or capture_name:match("definition%.constant") then
      -- Extract the kind (function, method, etc.)
      local kind = capture_name:match("definition%.(%w+)") or ""
      table.insert(results, { node = node, kind = kind })
    end
  end
else
  -- Fallback: use basic node types as symbols
  local function traverse(n)
    local node_type = n:type()
    -- Common node types that represent definitions
    if node_type:match("function") or node_type:match("method")
       or node_type:match("class") or node_type:match("interface")
       or node_type:match("declaration") then
      table.insert(results, { node = n, kind = node_type })
    end
    for child in n:iter_children() do
      traverse(child)
    end
  end
  traverse(root)
end
```

### Key Points

1. **Uses `vim.treesitter.language.get_lang()`** instead of `parsers.get_buf_lang()`
   - Available since Neovim 0.9.0
   - Already used elsewhere in telescope.nvim

2. **Uses `utils.has_ts_parser()`** instead of `parsers.has_parser()`
   - Wrapper around `vim.treesitter.language.add()`
   - Handles both Neovim 0.11+ and 0.9-0.10

3. **Uses Neovim's query API** instead of `nvim-treesitter.locals`
   - `vim.treesitter.query.get(lang, "locals")`
   - `query:iter_captures()` for iteration
   - Handles capture names like `local.definition.function`

4. **Includes fallback mechanism**
   - If locals query not available, traverse AST directly
   - Ensures basic functionality even without queries

## Compatibility

✅ **nvim-treesitter main branch** (Neovim 0.11+)
✅ **nvim-treesitter master branch** (Neovim 0.9.0+)
✅ **Neovim 0.9.0+** (uses only built-in APIs)
✅ **Backward compatible** with existing telescope.nvim usage

## Testing

### Minimal Configuration

A minimal test configuration is available at:
`~/.config/nvim-dev/telescope-treesitter/`

Usage:
```bash
env NVIM_APPNAME=nvim-dev/telescope-treesitter nvim
```

Then run `:Telescope treesitter` to see function/class/variable definitions.

### Expected Output

For a Lua file with functions, the picker should display:
- Function names with their line numbers
- Variable definitions
- Method definitions
- Parameters (optional, can be filtered)

## Notes

- The `locals` query files still exist in both branches (in `runtime/queries/` or `queries/`)
- Main branch is Neovim 0.11+ only, but our fix maintains 0.9.0+ compatibility
- The fix minimizes dependency on nvim-treesitter-specific APIs
- Capture name patterns changed from `definition.X` to `local.definition.X` in some queries

## References

- Issue: https://github.com/nvim-telescope/telescope.nvim/issues/3547
- nvim-treesitter main branch: https://github.com/nvim-treesitter/nvim-treesitter/tree/main
- nvim-treesitter master branch: https://github.com/nvim-treesitter/nvim-treesitter/tree/master
- Neovim treesitter docs: `:h treesitter`
