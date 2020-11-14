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

if 2 > vim.o.report then
  vim.api.nvim_err_writeln(string.format("[telescope] It seems you have `set report=%s`", vim.o.report))
  vim.api.nvim_err_writeln("[telescope] Instead, change 'report' back to its default value. `set report=2`.")
  vim.api.nvim_err_writeln("[telescope] If you do not, you will have a bad experience")
end


local actions = require('telescope.actions')
local finders = require('telescope.finders')
local log = require('telescope.log')
local make_entry = require('telescope.make_entry')
local path = require('telescope.path')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')
local sorters = require('telescope.sorters')
local utils = require('telescope.utils')

local conf = require('telescope.config').values

local filter = vim.tbl_filter
local flatten = vim.tbl_flatten


local builtin = {}

builtin.git_files = function(opts)
  opts = opts or {}

  local show_untracked = utils.get_default(opts.show_untracked, true)

  if opts.cwd then
    opts.cwd = vim.fn.expand(opts.cwd)
  else
    --- Find root of git directory and remove trailing newline characters
    opts.cwd = vim.fn.systemlist("git rev-parse --show-toplevel")[1]

    if 1 ~= vim.fn.isdirectory(opts.cwd) then
      error("Not a working directory for git_files:" .. opts.cwd)
    end
  end

  -- By creating the entry maker after the cwd options,
  -- we ensure the maker uses the cwd options when being created.
  opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)

  pickers.new(opts, {
    prompt_title = 'Git File',
    finder = finders.new_oneshot_job(
      { "git", "ls-files", "--exclude-standard", "--cached", show_untracked and "--others" },
      opts
    ),
    previewer = previewers.cat.new(opts),
    sorter = conf.file_sorter(opts),
  }):find()
end

builtin.commands = function()
  pickers.new({}, {
    prompt_title = 'Commands',
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
          value = line,
          ordinal = line.name,
          display = line.name
        }
      end
    },
    sorter = conf.generic_sorter(),
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
    opts.max_results
  )

  pickers.new(opts, {
    prompt_title = 'Live Grep',
    finder = live_grepper,
    previewer = previewers.vimgrep.new(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

builtin.lsp_references = function(opts)
  opts = opts or {}
  opts.shorten_path = utils.get_default(opts.shorten_path, true)

  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = true }

  local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/references", params, opts.timeout or 10000)
  local locations = {}
  for _, server_results in pairs(results_lsp) do
    if server_results.result then
      vim.list_extend(locations, vim.lsp.util.locations_to_items(server_results.result) or {})
    end
  end

  if vim.tbl_isempty(locations) then
    return
  end

  pickers.new(opts, {
    prompt_title = 'LSP References',
    finder    = finders.new_table {
      results = locations,
      entry_maker = make_entry.gen_from_quickfix(opts),
    },
    previewer = previewers.qflist.new(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

builtin.lsp_document_symbols = function(opts)
  opts = opts or {}

  local params = vim.lsp.util.make_position_params()
  local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/documentSymbol", params, opts.timeout or 10000)

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
    prompt_title = 'LSP Document Symbols',
    finder    = finders.new_table {
      results = locations,
      entry_maker = make_entry.gen_from_quickfix(opts)
    },
    previewer = previewers.vim_buffer.new(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

builtin.lsp_code_actions = function(opts)
  opts = opts or {}

  local params = vim.lsp.util.make_range_params()

  params.context = {
    diagnostics = vim.lsp.util.get_line_diagnostics()
  }

  local results_lsp, err = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, opts.timeout or 10000)

  if err then
    print("ERROR: " .. err)
    return
  end

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from textDocument/codeAction")
    return
  end

  local results = (results_lsp[1] or results_lsp[2]).result;

  if #results == 0 then
    print("No code actions available")
    return
  end

  for i,x in ipairs(results) do
    x.idx = i
  end

  pickers.new(opts, {
    prompt_title = 'LSP Code Actions',
    finder    = finders.new_table {
      results = results,
      entry_maker = function(line)
        return {
          valid = line ~= nil,
          value = line,
          ordinal = line.idx .. line.title,
          display = line.idx .. ': ' .. line.title
        }
      end
    },
    attach_mappings = function(prompt_bufnr, map)
      local execute = function()
        local selection = actions.get_selected_entry(prompt_bufnr)
        actions.close(prompt_bufnr)
        local val = selection.value

        if val.edit or type(val.command) == "table" then
          if val.edit then
            vim.lsp.util.apply_workspace_edit(val.edit)
          end
          if type(val.command) == "table" then
            vim.lsp.buf.execute_command(val.command)
          end
        else
          vim.lsp.buf.execute_command(val)
        end
      end

      map('i', '<CR>', execute)
      map('n', '<CR>', execute)

      return true
    end,
    sorter = conf.generic_sorter(opts),
  }):find()
end

builtin.lsp_workspace_symbols = function(opts)
  opts = opts or {}
  opts.shorten_path = utils.get_default(opts.shorten_path, true)

  local params = {query = opts.query or ''}
  local results_lsp = vim.lsp.buf_request_sync(0, "workspace/symbol", params, opts.timeout or 10000)

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from workspace/symbol")
    return
  end

  local locations = {}
  for _, server_results in pairs(results_lsp) do
    if server_results.result then
      vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result, 0) or {})
    end
  end

  if vim.tbl_isempty(locations) then
    return
  end

  pickers.new(opts, {
    prompt_title = 'LSP Workspace Symbols',
    finder    = finders.new_table {
      results = locations,
      entry_maker = make_entry.gen_from_quickfix(opts)
    },
    previewer = previewers.qflist.new(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

builtin.quickfix = function(opts)
  opts = opts or {}

  local locations = vim.fn.getqflist()

  if vim.tbl_isempty(locations) then
    return
  end

  pickers.new(opts, {
    prompt_title  = 'Quickfix',
    finder    = finders.new_table {
      results     = locations,
      entry_maker = make_entry.gen_from_quickfix(opts),
    },
    previewer = previewers.qflist.new(opts),
    sorter = conf.generic_sorter(opts),
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
    prompt_title = 'Loclist',
    finder    = finders.new_table {
      results     = locations,
      entry_maker = make_entry.gen_from_quickfix(opts),
    },
    previewer = previewers.qflist.new(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

-- Special keys:
--  opts.search -- the string to search.
builtin.grep_string = function(opts)
  opts = opts or {}

  -- TODO: This should probably check your visual selection as well, if you've got one
  local search = opts.search or vim.fn.expand("<cword>")

  opts.entry_maker = opts.entry_maker or make_entry.gen_from_vimgrep(opts)
  opts.word_match = opts.word_match or nil

  pickers.new(opts, {
    prompt_title = 'Find Word',
    finder = finders.new_oneshot_job(
      flatten { conf.vimgrep_arguments, opts.word_match, search},
      opts
    ),
    previewer = previewers.vimgrep.new(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

builtin.oldfiles = function(opts)
  opts = opts or {}

  pickers.new(opts, {
    prompt_title = 'Oldfiles',
    finder = finders.new_table(vim.tbl_filter(function(val)
      return 0 ~= vim.fn.filereadable(val)
    end, vim.v.oldfiles)),
    sorter = conf.file_sorter(opts),
    previewer = previewers.cat.new(opts),
  }):find()
end

builtin.command_history = function(opts)
  local history_string = vim.fn.execute('history cmd')
  local history_list = vim.split(history_string, "\n")

  local results = {}
  for i = #history_list, 3, -1 do
    local item = history_list[i]
    local _, finish = string.find(item, "%d+ +")
    table.insert(results, string.sub(item, finish + 1))
  end

  pickers.new(opts, {
    prompt_title = 'Command History',
    finder = finders.new_table(results),
    sorter = sorters.fuzzy_with_index_bias(),

    attach_mappings = function(_, map)
      map('i', '<CR>', actions.set_command_line)

      -- TODO: Find a way to insert the text... it seems hard.
      -- map('i', '<C-i>', actions.insert_value, { expr = true })

      return true
    end,
  }):find()
end

builtin.vim_options = function(opts)
  opts = opts or {}

  -- Load vim options.
  local vim_opts = loadfile(utils.data_directory() .. path.separator .. 'options' .. path.separator .. 'options.lua')().options

  pickers.new(opts, {
      prompt = 'options',
      finder = finders.new_table {
        results = vim_opts,
        entry_maker = make_entry.gen_from_vimoptions(opts),
      },
      -- TODO: previewer for Vim options
      -- previewer = previewers.help.new(opts),
      sorter = sorters.get_fzy_sorter(),
      attach_mappings = function(prompt_bufnr, map)
        local edit_option = function()
          local selection = actions.get_selected_entry(prompt_bufnr)
          local esc = ""


          if vim.fn.mode() == "i" then
            -- TODO: don't make this local
            esc = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
          end

          -- TODO: Make this actually work.

          -- actions.close(prompt_bufnr)
          -- vim.api.nvim_win_set_var(vim.fn.nvim_get_current_win(), "telescope", 1)
          -- print(prompt_bufnr)
          -- print(vim.fn.bufnr())
          -- vim.cmd([[ autocmd BufEnter <buffer> ++nested ++once startinsert!]])
          -- print(vim.fn.winheight(0))

          -- local prompt_winnr = vim.fn.getbufinfo(prompt_bufnr)[1].windows[1]
          -- print(prompt_winnr)

          -- local float_opts = {}
          -- float_opts.relative = "editor"
          -- float_opts.anchor = "sw"
          -- float_opts.focusable = false
          -- float_opts.style = "minimal"
          -- float_opts.row = vim.api.nvim_get_option("lines") - 2 -- TODO: include `cmdheight` and `laststatus` in this calculation
          -- float_opts.col = 2
          -- float_opts.height = 10
          -- float_opts.width = string.len(selection.last_set_from)+15
          -- local buf = vim.fn.nvim_create_buf(false, true)
          -- vim.fn.nvim_buf_set_lines(buf, 0, 0, false, {"default value: abcdef", "last set from: " .. selection.last_set_from})
          -- local status_win = vim.fn.nvim_open_win(buf, false, float_opts)
          -- -- vim.api.nvim_win_set_option(status_win, "winblend", 100)
          -- vim.api.nvim_win_set_option(status_win, "winhl", "Normal:PmenuSel")
          -- -- vim.api.nvim_set_current_win(status_win)
          -- vim.cmd[[redraw!]]
          -- vim.cmd("autocmd CmdLineLeave : ++once echom 'beep'")
          vim.api.nvim_feedkeys(string.format("%s:set %s=%s", esc, selection.name, selection.current_value), "m", true)
        end

        map('i', '<CR>', edit_option)
        map('n', '<CR>', edit_option)

        return true
      end
    }):find()
end

builtin.help_tags = function(opts)
  opts = opts or {}

  local sourced_file = require('plenary.debug_utils').sourced_filepath()
  local base_directory = vim.fn.fnamemodify(sourced_file, ":h:h:h")
  local file = base_directory .. "/data/help/tags"

  local tags = {}
  local f = assert(io.open(file, "rb"))
    for line in f:lines() do
      table.insert(tags, line)
    end
  f:close()

  pickers.new(opts, {
    prompt_title = 'Help',
    finder = finders.new_table {
      results = tags,
      entry_maker = make_entry.gen_from_tagfile(opts),
    },
    -- TODO: previewer for Vim help
    previewer = previewers.help.new(opts),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      local open = function(cmd)
        local selection = actions.get_selected_entry(prompt_bufnr)

        actions.close(prompt_bufnr)
        vim.cmd(cmd .. selection.value)
      end
      local nhelp = function()
        return open("help ")
      end
      local vhelp = function()
        return open("vert bo help ")
      end
      local hhelp = function()
        return open("help ")
        -- Not sure how explictly make horizontal
      end
      local thelp = function()
        return open("tab help ")
      end
      -- Perhaps it would be a good idea to have vsplit,tab,hsplit open
      -- a builtin action that accepts a command to be ran before creating
      -- the split or tab
      map('i', '<CR>',  nhelp)
      map('n', '<CR>',  nhelp)
      map('i', '<C-v>', vhelp)
      map('n', '<C-v>', vhelp)
      map('i', '<C-x>', hhelp)
      map('n', '<C-x>', hhelp)
      map('i', '<C-t>', thelp)
      map('n', '<C-t>', thelp)

      return true
    end
  }):find()
end

builtin.reloader = function(opts)
  opts = opts or {}
  local package_list = vim.tbl_keys(package.loaded)

  -- filter out packages we don't want and track the longest package name
  opts.column_len = 0
  for index, module_name in pairs(package_list) do
    if type(require(module_name)) ~= 'table' or module_name:sub(1,1) == "_" or package.searchpath(module_name, package.path) == nil then
      table.remove(package_list, index)
    elseif #module_name > opts.column_len then
      opts.column_len = #module_name
    end
  end

  pickers.new(opts, {
    prompt_title = 'Packages',
    finder = finders.new_table {
      results = package_list,
      entry_maker = make_entry.gen_from_packages(opts),
    },
    -- previewer = previewers.vim_buffer.new(opts),
    sorter = conf.generic_sorter(opts),

    attach_mappings = function(prompt_bufnr, map)
      local reload_package = function()
        local selection = actions.get_selected_entry(prompt_bufnr)

        actions.close(prompt_bufnr)
        require('plenary.reload').reload_module(selection.value)
        print(string.format("[%s] - module reloaded", selection.value))
      end

      map('i', '<CR>', reload_package)
      map('n', '<CR>', reload_package)

      return true
    end
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
    prompt_title = 'Telescope Builtin',
    finder    = finders.new_table {
      results     = objs,
      entry_maker = make_entry.gen_from_quickfix(opts),
    },
    previewer = previewers.qflist.new(opts),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(_, map)
      map('i', '<CR>', actions.run_builtin)
      return true
    end
  }):find()
end


-- TODO: Maybe just change this to `find`.
--          Support `find` and maybe let people do other stuff with it as well.
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
    elseif 1 == vim.fn.executable("find") then
      find_command = { 'find', '.', '-type', 'f' }
    end
  end

  if not find_command then
    print("You need to install either find, fd, or rg. You can also submit a PR to add support for another file finder :)")
    return
  end

  if opts.cwd then
    opts.cwd = vim.fn.expand(opts.cwd)
  end

  opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)

  pickers.new(opts, {
    prompt_title = 'Find Files',
    finder = finders.new_oneshot_job(
      find_command,
      opts
    ),
    previewer = previewers.cat.new(opts),
    sorter = conf.file_sorter(opts),
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
    prompt_title = 'Buffers',
    finder    = finders.new_table {
      results = buffers,
      entry_maker = make_entry.gen_from_buffer(opts)
    },
    -- previewer = previewers.vim_buffer.new(opts),
    previewer = previewers.vimgrep.new(opts),
    sorter = conf.generic_sorter(opts),
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
    prompt_title = 'Treesitter Symbols',
    finder    = finders.new_table {
      results = results,
      entry_maker = make_entry.gen_from_treesitter(opts)
    },
    previewer = previewers.vim_buffer.new(opts),
    sorter = conf.generic_sorter(opts),
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
    prompt_title = 'Planets',
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
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      map('i', '<CR>', function()
        local selection = actions.get_selected_entry(prompt_bufnr)
        actions.close(prompt_bufnr)

        print("Enjoy astronomy! You viewed:", selection.display)
      end)

      return true
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
    prompt_title = 'Current Buffer Fuzzy',
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

builtin.man_pages = function(opts)
  opts = opts or {}

  local cmd = opts.man_cmd or "apropos --sections=1 ''"

  local pages = utils.get_os_command_output(cmd)

  local lines = {}
  for s in pages:gmatch("[^\r\n]+") do
    table.insert(lines, s)
  end

  pickers.new(opts, {
    prompt_tile = 'Man',
    finder    = finders.new_table {
      results = lines,
      entry_maker = make_entry.gen_from_apropos(opts),
    },
    previewer = previewers.man.new(opts),
    sorter = sorters.get_generic_fuzzy_sorter(),
    attach_mappings = function(prompt_bufnr, map)
      local view_manpage = function()
        local selection = actions.get_selected_entry(prompt_bufnr)

        actions.close(prompt_bufnr)
        print(vim.inspect(selection.value))
        vim.cmd("Man " .. selection.value)
      end

      map('i', '<CR>', view_manpage)
      map('n', '<CR>', view_manpage)

      return true
    end
  }):find()
end

builtin.colorscheme = function(opts)
  opts = opts or {}

  local colors = vim.list_extend(opts.colors or {}, vim.fn.getcompletion('', 'color'))

  pickers.new(opts,{
    prompt = 'Change Colorscheme',
    finder = finders.new_table {
      results = colors
    },
    -- TODO: better preview?
    sorter = sorters.get_generic_fuzzy_sorter(),
    attach_mappings = function(prompt_bufnr, map)
      local change_colorscheme = function()
        local selection = actions.get_selected_entry(prompt_bufnr)

        actions.close(prompt_bufnr)
        print(vim.inspect(selection.value))
        vim.cmd("colorscheme " .. selection.value)
      end

      map('i', '<CR>', change_colorscheme)
      map('n', '<CR>', change_colorscheme)

      return true
    end
  }):find()
end

builtin.marks = function(opts)
  opts = opts or {}

  local marks = vim.api.nvim_exec("marks", true)
  local marks_table = vim.fn.split(marks, "\n")

  -- Pop off the header.
  table.remove(marks_table, 1)

  pickers.new(opts,{
    prompt = 'Marks',
    finder = finders.new_table {
      results = marks_table,
      entry_maker = make_entry.gen_from_marks(opts),
    },
    previewer = previewers.vimgrep.new(opts),
    sorter = sorters.get_generic_fuzzy_sorter(),
  }):find()
end

-- find normal mode mappings
builtin.keymaps = function(opts)
  opts = opts or {}
  local modes = {"n", "i", "c"}
  local keymaps_table = {}
  for _, mode in pairs(modes) do
    local keymaps_iter = vim.api.nvim_get_keymap(mode)
    for _, keymap in pairs(keymaps_iter) do
      table.insert(keymaps_table, keymap)
    end
  end

  pickers.new({}, {
    prompt_title = 'Key Maps',
    finder = finders.new_table {
      results = keymaps_table,
      entry_maker = function(line)
        return {
          valid = line ~= "",
          value = line,
          ordinal = line.lhs .. line.rhs,
          display = line.mode .. ' ' .. utils.display_termcodes(line.lhs) .. ' ' .. line.rhs
        }
      end
    },
    sorter = conf.generic_sorter()
  }):find()
end

return builtin
