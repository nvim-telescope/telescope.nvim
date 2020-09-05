--[[
A collection of builtin pipelines for telesceope.

Meant for both example and for easy startup.

Any of these functions can just be called directly by doing:

:lua require('telescope.builtin').__name__()

This will use the default configuration options.
  Other configuration options still in flux at the moment
--]]

-- TODO: Give some bonus weight to files we've picked before
-- TODO: Give some bonus weight to oldfiles

local actions = require('telescope.actions')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local previewers = require('telescope.previewers')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')
local utils = require('telescope.utils')

local filter = vim.tbl_filter
local flatten = vim.tbl_flatten

-- TODO: Support silver search here.
-- TODO: Support normal grep here (in case neither are installed).
local vimgrep_arguments = {'rg', '--color=never', '--no-heading', '--with-filename', '--line-number', '--column'}

local builtin = {}

builtin.git_files = function(opts)
  opts = opts or {}

  opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)
  if opts.cwd then
    opts.cwd = vim.fn.expand(opts.cwd)
  end

  pickers.new(opts, {
    prompt    = 'Git File',
    finder    = finders.new_oneshot_job(
      { "git", "ls-files", "-o", "--exclude-standard", "-c" },
      opts
    ),
    previewer = previewers.cat.new(opts),
    sorter    = sorters.get_fuzzy_file(),
  }):find()
end

builtin.live_grep = function(opts)
  opts = opts or {}

  local live_grepper = finders.new_job(function(prompt)
      -- TODO: Probably could add some options for smart case and whatever else rg offers.

      if not prompt or prompt == "" then
        return nil
      end

      return flatten { vimgrep_arguments, prompt }
    end,
    opts.entry_maker or make_entry.gen_from_vimgrep(opts),
    opts.max_results
  )

  pickers.new(opts, {
    prompt    = 'Live Grep',
    finder    = live_grepper,
    previewer = previewers.vimgrep.new(opts),
  }):find()
end

builtin.lsp_references = function(opts)
  opts = opts or {}
  opts.shorten_path = utils.get_default(opts.shorten_path, true)

  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = true }

  local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/references", params)
  local locations = {}
  for _, server_results in pairs(results_lsp) do
    vim.list_extend(locations, vim.lsp.util.locations_to_items(server_results.result) or {})
  end

  if vim.tbl_isempty(locations) then
    return
  end

  pickers.new(opts, {
    prompt    = 'LSP References',
    finder    = finders.new_table {
      results = locations,
      entry_maker = make_entry.gen_from_quickfix(opts),
    },
    previewer = previewers.qflist.new(opts),
    sorter    = sorters.get_norcalli_sorter(),
  }):find()
end

builtin.lsp_document_symbols = function(opts)
  opts = opts or {}

  local params = vim.lsp.util.make_position_params()
  local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/documentSymbol", params)

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from textDocument/documentSymbol")
    return
  end

  local locations = {}
  for _, server_results in pairs(results_lsp) do
    vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result, 0) or {})
  end

  if vim.tbl_isempty(locations) then
    return
  end

  pickers.new(opts, {
    prompt    = 'LSP Document Symbols',
    finder    = finders.new_table {
      results = locations,
      entry_maker = make_entry.gen_from_quickfix(opts)
    },
    previewer = previewers.vim_buffer.new(opts),
    sorter    = sorters.get_norcalli_sorter(),
  }):find()
end

builtin.lsp_workspace_symbols = function(opts)
  opts = opts or {}
  opts.shorten_path = utils.get_default(opts.shorten_path, true)

  local params = {query = opts.query or ''}
  local results_lsp = vim.lsp.buf_request_sync(0, "workspace/symbol", params, 1000)

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from textDocument/documentSymbol")
    return
  end

  local locations = {}
  for _, server_results in pairs(results_lsp) do
    vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result, 0) or {})
  end

  if vim.tbl_isempty(locations) then
    return
  end

  pickers.new(opts, {
    prompt    = 'LSP Workspace Symbols',
    finder    = finders.new_table {
      results = locations,
      entry_maker = make_entry.gen_from_quickfix(opts)
    },
    previewer = previewers.qflist.new(opts),
    sorter    = sorters.get_norcalli_sorter(),
  }):find()
end

builtin.quickfix = function(opts)
  local locations = vim.fn.getqflist()

  if vim.tbl_isempty(locations) then
    return
  end

  pickers.new(opts, {
    prompt    = 'Quickfix',
    finder    = finders.new_table {
      results     = locations,
      entry_maker = make_entry.gen_from_quickfix(opts),
    },
    previewer = previewers.qflist.new(opts),
    sorter    = sorters.get_norcalli_sorter(),
  }):find()
end

builtin.loclist = function(opts)
  local locations = vim.fn.getloclist(0)
  local filename = vim.api.nvim_buf_get_name(0)

  for _, value in pairs(locations) do
    value.filename = filename
  end

  if vim.tbl_isempty(locations) then
    return
  end

  pickers.new(opts, {
    prompt    = 'Loclist',
    finder    = finders.new_table {
      results     = locations,
      entry_maker = make_entry.gen_from_quickfix(opts),
    },
    previewer = previewers.qflist.new(opts),
    sorter    = sorters.get_norcalli_sorter(),
  }):find()
end

-- Special keys:
--  opts.search -- the string to search.
builtin.grep_string = function(opts)
  opts = opts or {}

  -- TODO: This should probably check your visual selection as well, if you've got one
  local search = opts.search or vim.fn.expand("<cword>")

  opts.entry_maker = opts.entry_maker or make_entry.gen_from_vimgrep(opts)

  pickers.new(opts, {
    prompt = 'Find Word',
    finder = finders.new_oneshot_job(
      flatten { vimgrep_arguments, search},
      opts
    ),
    previewer = previewers.vimgrep.new(opts),
    sorter = sorters.get_norcalli_sorter(),
  }):find()
end

builtin.oldfiles = function(opts)
  opts = opts or {}

  pickers.new(opts, {
    prompt = 'Oldfiles',
    finder = finders.new_table(vim.tbl_filter(function(val)
      return 0 ~= vim.fn.filereadable(val)
    end, vim.v.oldfiles)),
    sorter = sorters.get_fuzzy_file(),
    previewer = previewers.cat.new(opts),
  }):find()
end

builtin.command_history = function(opts)
  local history_string = vim.fn.execute('history cmd')
  local history_list = vim.split(history_string, "\n")

  local results = {}
  for i = 3, #history_list do
    local item = history_list[i]
    local _, finish = string.find(item, "%d+ +")
    table.insert(results, string.sub(item, finish + 1))
  end

  pickers.new(opts, {
    prompt = 'Command History',
    finder = finders.new_table(results),
    sorter = sorters.get_norcalli_sorter(),

    attach_mappings = function(_, map)
      map('i', '<CR>', actions.set_command_line)

      -- TODO: Find a way to insert the text... it seems hard.
      -- map('i', '<C-i>', actions.insert_value, { expr = true })

      -- Please add the default mappings for me for the rest of the keys.
      return true
    end,

    -- TODO: Adapt `help` to this.
    -- previewer = previewers.cat,
  }):find()
end

-- TODO: What the heck should we do for accepting this.
--  vim.fn.setreg("+", "nnoremap $TODO :lua require('telescope.builtin').<whatever>()<CR>")
-- TODO: Can we just do the names instead?
builtin.builtin = function(opts)
  opts = opts or {}
  opts.hide_filename = utils.get_default(opts.hide_filename, true)
  opts.ignore_filename = utils.get_default(opts.ignore_filename, true)

  local objs = {}

  for k, v in pairs(builtin) do
    local debug_info = debug.getinfo(v)

    table.insert(objs, {
      filename = string.sub(debug_info.source, 2),
      lnum = debug_info.linedefined,
      col = 0,
      text = k,

      start = debug_info.linedefined,
      finish = debug_info.lastlinedefined,
    })
  end

  pickers.new(opts, {
    prompt    = 'Telescope Builtin',
    finder    = finders.new_table {
      results     = objs,
      entry_maker = make_entry.gen_from_quickfix(opts),
    },
    previewer = previewers.qflist.new(opts),
    sorter    = sorters.get_norcalli_sorter(),
  }):find()
end


builtin.fd = function(opts)
  opts = opts or {}

  local fd_string = nil
  if 1 == vim.fn.executable("fd") then
    fd_string = "fd"
  elseif 1 == vim.fn.executable("fdfind") then
    fd_string = "fdfind"
  end

  if not fd_string then
    print("You need to install fd")
    return
  end

  -- TODO: CWD not 100% supported at this moment.
  --        Previewers don't work. We'll have to try out something for that later
  local cwd = opts.cwd
  if cwd then
    cwd = vim.fn.expand(cwd)
  end

  opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)

  pickers.new(opts, {
    prompt = 'Find Files',
    finder = finders.new_oneshot_job(
      {fd_string},
      opts
    ),
    previewer = previewers.cat.new(opts),
    sorter = sorters.get_fuzzy_file(),
  }):find()
end

-- TODO: This is partially broken, but I think it might be an nvim bug.
builtin.buffers = function(opts)
  opts = opts or {}

  local buffers =  filter(function(b)
    return
      vim.api.nvim_buf_is_loaded(b)
      and 1 == vim.fn.buflisted(b)

  end, vim.api.nvim_list_bufs())

  pickers.new(opts, {
    prompt    = 'Buffers',
    finder    = finders.new_table {
      results = buffers,
      entry_maker = make_entry.gen_from_buffer(opts)
    },
    previewer = previewers.vim_buffer.new(opts),
    sorter    = sorters.get_norcalli_sorter(),
  }):find()
end

return builtin
