local actions = require('telescope.actions')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local path = require('telescope.path')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')
local sorters = require('telescope.sorters')
local utils = require('telescope.utils')

local conf = require('telescope.config').values

local filter = vim.tbl_filter

local internal = {}

-- TODO: What the heck should we do for accepting this.
--  vim.fn.setreg("+", "nnoremap $TODO :lua require('telescope.builtin').<whatever>()<CR>")
-- TODO: Can we just do the names instead?
internal.builtin = function(opts)
  opts.hide_filename = utils.get_default(opts.hide_filename, true)
  opts.ignore_filename = utils.get_default(opts.ignore_filename, true)

  local objs = {}

  for k, v in pairs(require'telescope.builtin') do
    local debug_info = debug.getinfo(v)
    table.insert(objs, {
      filename = string.sub(debug_info.source, 2),
      text = k,
    })
  end

  pickers.new(opts, {
    prompt_title = 'Telescope Builtin',
    finder    = finders.new_table {
      results = objs,
      entry_maker = function(entry)
        return {
          value = entry,
          text = entry.text,
          display = entry.text,
          ordinal = entry.text,
          filename = entry.filename
        }
      end
    },
    previewer = previewers.builtin.new(opts),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(_)
      actions.goto_file_selection_edit:replace(actions.run_builtin)
      return true
    end
  }):find()
end

internal.planets = function(opts)
  local show_pluto = opts.show_pluto or false

  local sourced_file = require('plenary.debug_utils').sourced_filepath()
  local base_directory = vim.fn.fnamemodify(sourced_file, ":h:h:h:h")

  local globbed_files = vim.fn.globpath(base_directory .. '/data/memes/planets/', '*', true, true)
  local acceptable_files = {}
  for _, v in ipairs(globbed_files) do
    if show_pluto or not v:find("pluto") then
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
    attach_mappings = function(prompt_bufnr)
      actions.goto_file_selection_edit:replace(function()
        local selection = actions.get_selected_entry()
        actions.close(prompt_bufnr)

        print("Enjoy astronomy! You viewed:", selection.display)
      end)

      return true
    end,
  }:find()
end

internal.symbols = function(opts)
  local files = vim.api.nvim_get_runtime_file('data/telescope-sources/*.json', true)
  if table.getn(files) == 0 then
    print("No sources found! Check out https://github.com/nvim-telescope/telescope-symbols.nvim " ..
          "for some prebuild symbols or how to create you own symbol source.")
    return
  end

  local sources = {}
  if opts.sources then
    for _, v in ipairs(files) do
      for _, s in ipairs(opts.sources) do
        if v:find(s) then
          table.insert(sources, v)
        end
      end
    end
  else
    sources = files
  end

  local results = {}
  for _, source in ipairs(sources) do
    local data = vim.fn.json_decode(path.read_file(source))
    for _, entry in ipairs(data) do
      table.insert(results, entry)
    end
  end

  pickers.new(opts, {
    prompt_title = 'Symbols',
    finder    = finders.new_table {
      results     = results,
      entry_maker = function(entry)
        return {
          value = entry,
          ordinal = entry[1] .. ' ' .. entry[2],
          display = entry[1] .. ' ' .. entry[2],
        }
      end
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(_)
      actions.goto_file_selection_edit:replace(actions.insert_symbol)
      return true
    end
  }):find()
end

internal.commands = function(opts)
  pickers.new(opts, {
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
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions.goto_file_selection_edit:replace(function()
        local selection = actions.get_selected_entry()
        actions.close(prompt_bufnr)
        local val = selection.value
        local cmd = string.format([[:%s ]], val.name)

        if val.nargs == "0" then
          vim.cmd(cmd)
        else
          vim.cmd [[stopinsert]]
          vim.fn.feedkeys(cmd)
        end
      end)

      return true
    end
  }):find()
end

internal.quickfix = function(opts)
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
    previewer = conf.qflist_previewer(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

internal.loclist = function(opts)
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
    previewer = conf.qflist_previewer(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

internal.oldfiles = function(opts)
  pickers.new(opts, {
    prompt_title = 'Oldfiles',
    finder = finders.new_table(vim.tbl_filter(function(val)
      return 0 ~= vim.fn.filereadable(val)
    end, vim.v.oldfiles)),
    sorter = conf.file_sorter(opts),
    previewer = conf.file_previewer(opts),
  }):find()
end

internal.command_history = function(opts)
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
    sorter = conf.generic_sorter(opts),

    attach_mappings = function(_, map)
      map('i', '<CR>', actions.set_command_line)

      -- TODO: Find a way to insert the text... it seems hard.
      -- map('i', '<C-i>', actions.insert_value, { expr = true })

      return true
    end,
  }):find()
end

internal.vim_options = function(opts)
  -- Load vim options.
  local vim_opts = loadfile(utils.data_directory() .. path.separator .. 'options' ..
                            path.separator .. 'options.lua')().options

  pickers.new(opts, {
    prompt = 'options',
    finder = finders.new_table {
      results = vim_opts,
      entry_maker = make_entry.gen_from_vimoptions(opts),
    },
    -- TODO: previewer for Vim options
    -- previewer = previewers.help.new(opts),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function()
      actions.goto_file_selection_edit:replace(function()
        local selection = actions.get_selected_entry()
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
        -- float_opts.row = vim.api.nvim_get_option("lines") - 2 -- TODO: inc `cmdheight` and `laststatus` in this calc
        -- float_opts.col = 2
        -- float_opts.height = 10
        -- float_opts.width = string.len(selection.last_set_from)+15
        -- local buf = vim.fn.nvim_create_buf(false, true)
        -- vim.fn.nvim_buf_set_lines(buf, 0, 0, false,
        --                           {"default value: abcdef", "last set from: " .. selection.last_set_from})
        -- local status_win = vim.fn.nvim_open_win(buf, false, float_opts)
        -- -- vim.api.nvim_win_set_option(status_win, "winblend", 100)
        -- vim.api.nvim_win_set_option(status_win, "winhl", "Normal:PmenuSel")
        -- -- vim.api.nvim_set_current_win(status_win)
        -- vim.cmd[[redraw!]]
        -- vim.cmd("autocmd CmdLineLeave : ++once echom 'beep'")
        vim.api.nvim_feedkeys(string.format("%s:set %s=%s", esc, selection.name, selection.current_value), "m", true)
      end)

      return true
    end
  }):find()
end

internal.help_tags = function(opts)
  local all_tag_files = {}
  local all_help_files = {}
  for _, v in ipairs(vim.split(vim.fn.globpath(vim.o.runtimepath, 'doc/*', 1), '\n')) do
    local split_path = vim.split(v, path.separator, true)
    local filename = split_path[#split_path]
    if filename == 'tags' then
      table.insert(all_tag_files, v)
    else
      all_help_files[filename] = v
    end
  end

  local delim = string.char(9)
  local tags = {}
  for _, file in ipairs(all_tag_files) do
    local data = vim.split(path.read_file(file), '\n')
    for _, line in ipairs(data) do
      if line ~= '' then
        local matches = {}

        for match in (line..delim):gmatch("(.-)" .. delim) do
          table.insert(matches, match)
        end

        if table.getn(matches) ~= 0 then
          table.insert(tags, {
            name = matches[1],
            filename = all_help_files[matches[2]],
            cmd = matches[3]
          })
        end
      end
    end
  end

  pickers.new(opts, {
    prompt_title = 'Help',
    finder = finders.new_table {
      results = tags,
      entry_maker = function(entry)
        return {
          value = entry.name,
          display = entry.name,
          ordinal = entry.name,
          filename = entry.filename,
          cmd = entry.cmd
        }
      end,
    },
    previewer = previewers.help.new(opts),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions._goto_file_selection:replace(function(_, cmd)
        local selection = actions.get_selected_entry()
        actions.close(prompt_bufnr)
        if cmd == 'edit' or cmd == 'new' then
          vim.cmd('help ' .. selection.value)
        elseif cmd == 'vnew' then
          vim.cmd('vert bo help ' .. selection.value)
        elseif cmd == 'tabedit' then
          vim.cmd('tab help ' .. selection.value)
        end
      end)

      return true
    end
  }):find()
end

internal.man_pages = function(opts)
  local pages = utils.get_os_command_output(opts.man_cmd or "apropos --sections=1 ''")

  local lines = {}
  for s in pages:gmatch("[^\r\n]+") do
    table.insert(lines, s)
  end

  pickers.new(opts, {
    prompt_title = 'Man',
    finder    = finders.new_table {
      results = lines,
      entry_maker = make_entry.gen_from_apropos(opts),
    },
    previewer = previewers.man.new(opts),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions._goto_file_selection:replace(function(_, cmd)
        local selection = actions.get_selected_entry()

        actions.close(prompt_bufnr)
        if cmd == 'edit' or cmd == 'new' then
          vim.cmd('Man ' .. selection.value)
        elseif cmd == 'vnew' then
          vim.cmd('vert bo Man ' .. selection.value)
        elseif cmd == 'tabedit' then
          vim.cmd('tab Man ' .. selection.value)
        end
      end)

      return true
    end
  }):find()
end

internal.reloader = function(opts)
  local package_list = vim.tbl_keys(package.loaded)

  -- filter out packages we don't want and track the longest package name
  opts.column_len = 0
  for index, module_name in pairs(package_list) do
    if type(require(module_name)) ~= 'table' or
       module_name:sub(1,1) == "_" or
       package.searchpath(module_name, package.path) == nil then
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

    attach_mappings = function(prompt_bufnr)
      actions.goto_file_selection_edit:replace(function()
        local selection = actions.get_selected_entry()

        actions.close(prompt_bufnr)
        require('plenary.reload').reload_module(selection.value)
        print(string.format("[%s] - module reloaded", selection.value))
      end)

      return true
    end
  }):find()
end

internal.buffers = function(opts)
  local bufnrs = filter(function(b)
    return
      (opts.show_all_buffers
      or vim.api.nvim_buf_is_loaded(b))
      and 1 == vim.fn.buflisted(b)
  end, vim.api.nvim_list_bufs())
  if not next(bufnrs) then return end

  local buffers = {}
  local default_selection_idx = 1
  for _, bufnr in ipairs(bufnrs) do
    local flag = bufnr == vim.fn.bufnr('') and '%' or (bufnr == vim.fn.bufnr('#') and '#' or ' ')

    if opts.sort_lastused and flag == "#" then
      default_selection_idx = 2
    end

    local element = {
      bufnr = bufnr,
      flag = flag,
      info = vim.fn.getbufinfo(bufnr)[1],
    }

    if opts.sort_lastused and (flag == "#" or flag == "%") then
      local idx = ((buffers[1] ~= nil and buffers[1].flag == "%") and 2 or 1)
      table.insert(buffers, idx, element)
    else
      table.insert(buffers, element)
    end
  end

  if not opts.bufnr_width then
    local max_bufnr = math.max(unpack(bufnrs))
    opts.bufnr_width = #tostring(max_bufnr)
  end

  pickers.new(opts, {
    prompt_title = 'Buffers',
    finder    = finders.new_table {
      results = buffers,
      entry_maker = make_entry.gen_from_buffer(opts)
    },
    previewer = conf.grep_previewer(opts),
    sorter = conf.generic_sorter(opts),
    default_selection_index = default_selection_idx,
  }):find()
end

internal.colorscheme = function(opts)
  local colors = vim.list_extend(opts.colors or {}, vim.fn.getcompletion('', 'color'))

  pickers.new(opts,{
    prompt = 'Change Colorscheme',
    finder = finders.new_table {
      results = colors
    },
    -- TODO: better preview?
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions.goto_file_selection_edit:replace(function()
        local selection = actions.get_selected_entry()

        actions.close(prompt_bufnr)
        vim.cmd("colorscheme " .. selection.value)
      end)

      return true
    end
  }):find()
end

internal.marks = function(opts)
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
    previewer = conf.grep_previewer(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

internal.registers = function(opts)
  local registers_table = {"\"", "_", "#", "=", "_", "/", "*", "+", ":", ".", "%"}

  -- named
  for i = 0, 9 do
    table.insert(registers_table, tostring(i))
  end

  -- alphabetical
  for i = 65, 90 do
    table.insert(registers_table, string.char(i))
  end

  pickers.new(opts,{
    prompt_title = 'Registers',
    finder = finders.new_table {
      results = registers_table,
      entry_maker = make_entry.gen_from_registers(opts),
    },
    -- use levenshtein as n-gram doesn't support <2 char matches
    sorter = sorters.get_levenshtein_sorter(),
    attach_mappings = function(_, map)
      actions.goto_file_selection_edit:replace(actions.paste_register)
      map('i', '<C-e>', actions.edit_register)

      return true
    end,
  }):find()
end

-- TODO: make filtering include the mapping and the action
internal.keymaps = function(opts)
  local modes = {"n", "i", "c"}
  local keymaps_table = {}

  for _, mode in pairs(modes) do
    local global = vim.api.nvim_get_keymap(mode)
    for _, keymap in pairs(global) do
      table.insert(keymaps_table, keymap)
    end
    local buf_local = vim.api.nvim_buf_get_keymap(0, mode)
    for _, keymap in pairs(buf_local) do
      table.insert(keymaps_table, keymap)
    end
  end

  pickers.new(opts, {
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
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions.goto_file_selection_edit:replace(function()
        local selection = actions.get_selected_entry()
        vim.api.nvim_feedkeys(
          vim.api.nvim_replace_termcodes(selection.value.lhs, true, false, true),
        "t", true)
        return actions.close(prompt_bufnr)
      end)
      return true
    end
  }):find()
end

internal.filetypes = function(opts)
  local filetypes = vim.fn.getcompletion('', 'filetype')

  pickers.new(opts, {
    prompt_title = 'Filetypes',
    finder = finders.new_table {
      results = filetypes,
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions.goto_file_selection_edit:replace(function()
        local selection = actions.get_selected_entry()
        actions.close(prompt_bufnr)
        vim.cmd('setfiletype ' .. selection[1])
      end)
      return true
    end
  }):find()
end

internal.highlights = function(opts)
  local highlights = vim.fn.getcompletion('', 'highlight')

  pickers.new(opts, {
    prompt_title = 'Highlights',
    finder = finders.new_table {
      results = highlights,
      entry_maker = make_entry.gen_from_highlights(opts)
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions.goto_file_selection_edit:replace(function()
        local selection = actions.get_selected_entry()
        actions.close(prompt_bufnr)
        vim.cmd('hi ' .. selection.value)
      end)
      return true
    end,
    previewer = previewers.highlights.new(opts),
  }):find()
end

internal.autocommands = function(opts)
  local autocmd_table = {}

  local pattern  = {}
  pattern.BUFFER = "<buffer=%d+>"
  pattern.EVENT  = "[%a]+"
  pattern.GROUP  = "[%a%d_:]+"
  pattern.INDENT = "^%s%s%s%s" -- match indentation of 4 spaces

  local event, group, ft_pat, cmd, source_file, source_lnum
  local current_event, current_group, current_ft

  local cmd_output = vim.fn.execute("verb autocmd *", "silent")
  for line in cmd_output:gmatch("[^\r\n]+") do
    -- capture group and event
    group, event = line:match("^(" .. pattern.GROUP .. ")%s+(" .. pattern.EVENT .. ")")
    -- ..or just an event
    if event == nil then
      event = line:match("^(" .. pattern.EVENT .. ")")
    end

    if event then
      group = group or "<anonymous>"
      if event ~= current_event or group ~= current_group then
        current_event = event
        current_group = group
      end
      goto line_parsed
    end

    -- non event/group lines
    ft_pat = line:match(pattern.INDENT .. "(%S+)")
    if ft_pat then
      if ft_pat:match("^%d+") then
        ft_pat = "<buffer=" .. ft_pat .. ">"
      end
      current_ft = ft_pat

      -- is there a command on the same line?
      cmd = line:match(pattern.INDENT .. "%S+%s+(.+)")

      goto line_parsed
    end

    if current_ft and cmd == nil then
      -- trim leading spaces
      cmd = line:gsub("^%s+", "")
      goto line_parsed
    end

    if current_ft and cmd then
      source_file, source_lnum = line:match("Last set from (.*) line (.*)")
      if source_file then
        local autocmd = {}
        autocmd.event       = current_event
        autocmd.group       = current_group
        autocmd.ft_pattern  = current_ft
        autocmd.command     = cmd
        autocmd.source_file = source_file
        autocmd.source_lnum = source_lnum
        table.insert(autocmd_table, autocmd)

        cmd = nil
      end
    end

    ::line_parsed::
  end

  -- print(vim.inspect(autocmd_table))

  pickers.new(opts,{
    prompt_title = 'autocommands',
    finder = finders.new_table {
      results = autocmd_table,
      entry_maker = make_entry.gen_from_autocommands(opts),
    },
    previewer = previewers.autocommands.new(opts),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions._goto_file_selection:replace(function(_, vim_cmd)
        local selection = actions.get_selected_entry()
        actions.close(prompt_bufnr)
        vim.cmd(vim_cmd .. ' ' .. selection.value)
      end)

      return true
    end
  }):find()
end

local function apply_checks(mod)
  for k, v in pairs(mod) do
    mod[k] = function(opts)
      opts = opts or {}

      v(opts)
    end
  end

  return mod
end

return apply_checks(internal)
