--[[
A collection of builtin pipelines for telesceope.

Meant for both example and for easy startup.

Any of these functions can just be called directly by doing:

:lua require('telescope.builtin').__name__()

This will use the default configuration options.
  Other configuration options still in flux at the moment
--]]

if 1 ~= vim.fn.has('nvim-0.5') then
  vim.api.nvim_err_writeln("This plugins requires neovim 0.5")
  vim.api.nvim_err_writeln("Please update your neovim.")
  return
end


-- TODO: Give some bonus weight to files we've picked before
-- TODO: Give some bonus weight to oldfiles

local actions = require('telescope.actions')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local previewers = require('telescope.previewers')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')
local utils = require('telescope.utils')

local conf = require('telescope.config').values

local filter = vim.tbl_filter
local flatten = vim.tbl_flatten


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

builtin.commands = function()
  pickers.new({}, {
    prompt = 'Commands',
    finder = finders.new_table {
      results = (function()
        local command_iter = vim.api.nvim_get_commands({})
        local commands = {}

        for _, cmd in pairs(command_iter) do
          table.insert(commands, cmd)
        end

        return commands
      end)(),
      entry_maker = function(line)
        return {
          valid = line ~= "",
          entry_type = make_entry.types.GENERIC,
          value = line,
          ordinal = line.name,
          display = line.name
        }
      end
    },
    sorter = sorters.get_generic_fuzzy_sorter(),
    attach_mappings = function(prompt_bufnr, map)
      local run_command = function()
        local selection = actions.get_selected_entry(prompt_bufnr)
        actions.close(prompt_bufnr)
        local val = selection.value
        local cmd = string.format([[:%s ]], val.name)

        if val.nargs == "0" then
            vim.cmd(cmd)
        else
            vim.cmd [[stopinsert]]
            vim.fn.feedkeys(cmd)
        end

      end

      map('i', '<CR>', run_command)
      map('n', '<CR>', run_command)

      return true
    end
  }):find()
end

builtin.live_grep = function(opts)
  opts = opts or {}

  local live_grepper = finders.new_job(function(prompt)
      -- TODO: Probably could add some options for smart case and whatever else rg offers.

      if not prompt or prompt == "" then
        return nil
      end

      return flatten { conf.vimgrep_arguments, prompt }
    end,
    opts.entry_maker or make_entry.gen_from_vimgrep(opts),
    opts.max_results or 1000
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
    sorter    = sorters.get_generic_fuzzy_sorter(),
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
    sorter    = sorters.get_generic_fuzzy_sorter(),
  }):find()
end

builtin.lsp_workspace_symbols = function(opts)
  opts = opts or {}
  opts.shorten_path = utils.get_default(opts.shorten_path, true)

  local params = {query = opts.query or ''}
  local results_lsp = vim.lsp.buf_request_sync(0, "workspace/symbol", params, 1000)

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from workspace/symbol")
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
    sorter    = sorters.get_generic_fuzzy_sorter(),
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
    sorter    = sorters.get_generic_fuzzy_sorter(),
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
    sorter    = sorters.get_generic_fuzzy_sorter(),
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
      flatten { conf.vimgrep_arguments, search},
      opts
    ),
    previewer = previewers.vimgrep.new(opts),
    sorter = sorters.get_generic_fuzzy_sorter(),
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
    sorter = sorters.get_generic_fuzzy_sorter(),

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
    sorter    = sorters.get_generic_fuzzy_sorter(),
  }):find()
end


-- TODO: Maybe just change this to `find`.
--          Support `find` and maybe let peopel do other stuff with it as well.
builtin.find_files = function(opts)
  opts = opts or {}

  local find_command = opts.find_command

  if not find_command then
    if 1 == vim.fn.executable("fd") then
      find_command = { 'fd', '--type', 'f' }
    elseif 1 == vim.fn.executable("fdfind") then
      find_command = { 'fdfind', '--type', 'f' }
    elseif 1 == vim.fn.executable("rg") then
      find_command = { 'rg', '--files' }
    end
  end

  if not find_command then
    print("You need to install either fd or rg. You can also submit a PR to add support for another file finder :)")
    return
  end

  if opts.cwd then
    opts.cwd = vim.fn.expand(opts.cwd)
  end

  opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)

  pickers.new(opts, {
    prompt = 'Find Files',
    finder = finders.new_oneshot_job(
      find_command,
      opts
    ),
    previewer = previewers.cat.new(opts),
    sorter = sorters.get_fuzzy_file(),
  }):find()
end

-- Leave this alias around for people.
builtin.fd = builtin.find_files

-- TODO: I'd like to use the `vim_buffer` previewer, but it doesn't seem to work due to some styling problems.
--       I think it has something to do with nvim_open_win and style='minimal',
-- Status, currently operational.
builtin.buffers = function(opts)
  opts = opts or {}

  local buffers = filter(function(b)
    return
      (opts.show_all_buffers
      or vim.api.nvim_buf_is_loaded(b))
      and 1 == vim.fn.buflisted(b)

  end, vim.api.nvim_list_bufs())

  if not opts.bufnr_width then
    local max_bufnr = math.max(unpack(buffers))
    opts.bufnr_width = #tostring(max_bufnr)
  end

  pickers.new(opts, {
    prompt    = 'Buffers',
    finder    = finders.new_table {
      results = buffers,
      entry_maker = make_entry.gen_from_buffer(opts)
    },
    -- previewer = previewers.vim_buffer.new(opts),
    previewer = previewers.vimgrep.new(opts),
    sorter    = sorters.get_generic_fuzzy_sorter(),
  }):find()
end

local function prepare_match(entry, kind)
  local entries = {}

  if entry.node then
      entry["kind"] = kind
      table.insert(entries, entry)
  else
    for name, item in pairs(entry) do
        vim.list_extend(entries, prepare_match(item, name))
    end
  end

  return entries
end

builtin.treesitter = function(opts)
  opts = opts or {}

  opts.show_line = utils.get_default(opts.show_line, true)

  local has_nvim_treesitter, _ = pcall(require, 'nvim-treesitter')
  if not has_nvim_treesitter then
    print('You need to install nvim-treesitter')
    return
  end

  local parsers = require('nvim-treesitter.parsers')
  if not parsers.has_parser() then
    print('No parser for the current buffer')
    return
  end

  local ts_locals = require('nvim-treesitter.locals')
  local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()

  local results = {}
  for _, definitions in ipairs(ts_locals.get_definitions(bufnr)) do
    local entries = prepare_match(definitions)
    for _, entry in ipairs(entries) do
      table.insert(results, entry)
    end
  end

  if vim.tbl_isempty(results) then
    return
  end

  pickers.new(opts, {
    prompt    = 'Treesitter Symbols',
    finder    = finders.new_table {
      results = results,
      entry_maker = make_entry.gen_from_treesitter(opts)
    },
    previewer = previewers.vim_buffer.new(opts),
    sorter    = sorters.get_generic_fuzzy_sorter(),
  }):find()
end

builtin.planets = function(opts)
  opts = opts or {}
  local show_pluto = opts.show_pluto or false

  local sourced_file = require('plenary.debug_utils').sourced_filepath()
  local base_directory = vim.fn.fnamemodify(sourced_file, ":h:h:h")

  local globbed_files = vim.fn.globpath(base_directory .. '/data/memes/planets/', '*', true, true)
  local acceptable_files = {}
  for _, v in ipairs(globbed_files) do
    if not show_pluto and v:find("pluto") then
    else
      table.insert(acceptable_files,vim.fn.fnamemodify(v, ':t'))
    end
  end

  pickers.new {
    prompt = 'Planets',
    finder = finders.new_table {
      results = acceptable_files,
      entry_maker = function(line)
        return {
          ordinal = line,
          display = line,
          filename = base_directory .. '/data/memes/planets/' .. line,
        }
      end
    },
    previewer = previewers.cat.new(opts),
    sorter = sorters.get_generic_fuzzy_sorter(),
    attach_mappings = function(prompt_bufnr, map)
      map('i', '<CR>', function()
        local selection = actions.get_selected_entry(prompt_bufnr)
        actions.close(prompt_bufnr)

        print("Enjoy astronomy! You viewed:", selection.display)
      end)
    end,
  }:find()
end

builtin.current_buffer_fuzzy_find = function(opts)
  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local lines_with_numbers = {}
  for k, v in ipairs(lines) do
    table.insert(lines_with_numbers, {k, v})
  end

  pickers.new(opts, {
    prompt = 'Current Buffer Fuzzy',
    finder = finders.new_table {
      results = lines_with_numbers,
      entry_maker = function(enumerated_line)
        return {
          display = enumerated_line[2],
          ordinal = enumerated_line[2],

          lnum = enumerated_line[1],
        }
      end
    },
    sorter = sorters.get_generic_fuzzy_sorter(),
    attach_mappings = function(prompt_bufnr, map)
      local goto_line = function()
        local selection = actions.get_selected_entry(prompt_bufnr)
        actions.close(prompt_bufnr)

        vim.api.nvim_win_set_cursor(0, {selection.lnum, 0})
        vim.cmd [[stopinsert]]
      end

      map('n', '<CR>', goto_line)
      map('i', '<CR>', goto_line)

      return true
    end
  }):find()
end

return builtin
