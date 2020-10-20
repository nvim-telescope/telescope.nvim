local context_manager = require('plenary.context_manager')

local config = require('telescope.config')
local debounce = require('telescope.debounce')
local from_entry = require('telescope.from_entry')
local log = require('telescope.log')
local utils = require('telescope.utils')

local flatten = vim.tbl_flatten
local buf_delete = utils.buf_delete
local job_is_running = utils.job_is_running

local defaulter = utils.make_default_callable

local previewers = {}

local Previewer = {}
Previewer.__index = Previewer

-- TODO: Should play with these some more, ty @clason
local bat_options = {"--style=plain", "--color=always", "--paging=always"}
local has_less = (vim.fn.executable('less') == 1) and config.values.use_less

local bat_maker = function(filename, lnum, start, finish)
  local command = {"bat"}

  if lnum then
    table.insert(command, { "--highlight-line", lnum})
  end

  if has_less then
    if start then
      table.insert(command, {"--pager", string.format("less -RS +%s", start)})
    else
      table.insert(command, {"--pager", "less -RS"})
    end
  else
    if start and finish then
      table.insert(command, { "-r", string.format("%s:%s", start, finish) })
    end
  end

  return flatten {
    command, bat_options, "--", filename
  }
end

-- TODO: Add other options for cat to do this better
local cat_maker = function(filename, lnum, start, finish)
  return {
    "cat", "--", filename
  }
end

local get_maker = function(opts)
  local maker = opts.maker
  if not maker and 1 == vim.fn.executable("bat") then
    maker = bat_maker
  elseif not maker and 1 == vim.fn.executable("cat") then
    maker = cat_maker
  end

  if not maker then
    error("Needs maker")
  end

  return maker
end

local previewer_ns = vim.api.nvim_create_namespace('telescope.previewers')

local with_preview_window = function(status, bufnr, callable)
  if bufnr and vim.api.nvim_buf_call and false then
    vim.api.nvim_buf_call(bufnr, callable)
  else
    return context_manager.with(function()
      vim.cmd(string.format("noautocmd call nvim_set_current_win(%s)", status.preview_win))
      coroutine.yield()
      vim.cmd(string.format("noautocmd call nvim_set_current_win(%s)", status.prompt_win))
    end, callable)
  end
end

--  --terminal-width=%s

-- TODO: We shoudl make sure that all our terminals close all the way.
--          Otherwise it could be bad if they're just sitting around, waiting to be closed.
--          I don't think that's the problem, but it could be?

function Previewer:new(opts)
  opts = opts or {}

  return setmetatable({
    state = nil,
    _setup_func = opts.setup,
    _teardown_func = opts.teardown,
    _send_input = opts.send_input,
    _scroll_fn = opts.scroll_fn,
    preview_fn = opts.preview_fn,
  }, Previewer)
end

function Previewer:preview(entry, status)
  if not entry then
    return
  end

  if not self.state then
    if self._setup_func then
      self.state = self:_setup_func()
    else
      self.state = {}
    end
  end

  return self:preview_fn(entry, status)
end

function Previewer:teardown()
  if self._teardown_func then
    self:_teardown_func()
  end
end

function Previewer:send_input(input)
  if self._send_input then
    self:_send_input(input)
  else
    vim.api.nvim_err_writeln("send_input is not defined for this previewer")
  end
end

function Previewer:scroll_fn(direction)
  if self._scroll_fn then
    self:_scroll_fn(direction)
  else
    vim.api.nvim_err_writeln("scroll_fn is not defined for this previewer")
  end
end

previewers.new = function(...)
  return Previewer:new(...)
end

previewers.new_termopen_previewer = function(opts)
  opts = opts or {}

  assert(opts.get_command, "get_command is a required function")
  assert(not opts.preview_fn, "preview_fn not allowed")

  local opt_setup = opts.setup
  local opt_teardown = opts.teardown

  local old_bufs = {}

  local function get_term_id(self)
    if not self.state then return nil end
    return self.state.termopen_id
  end

  local function get_bufnr(self)
    if not self.state then return nil end
    return self.state.termopen_bufnr
  end

  local function set_term_id(self, value)
    if job_is_running(get_term_id(self)) then vim.fn.jobstop(get_term_id(self)) end
    if self.state then self.state.termopen_id = value end
  end

  local function set_bufnr(self, value)
    if get_bufnr(self) then table.insert(old_bufs, get_bufnr(self)) end
    if self.state then self.state.termopen_bufnr = value end
  end

  function opts.setup(self)
    local state = {}
    if opt_setup then vim.tbl_deep_extend("force", state, opt_setup(self)) end
    return state
  end

  function opts.teardown(self)
    if opt_teardown then
      opt_teardown(self)
    end

    local term_id = get_term_id(self)
    if term_id and utils.job_is_running(term_id) then
      vim.fn.jobclose(term_id)
    end

    set_term_id(self, nil)
    set_bufnr(self, nil)

    for _, bufnr in ipairs(old_bufs) do
      buf_delete(bufnr)
    end
  end

  function opts.preview_fn(self, entry, status)
    if get_bufnr(self) == nil then
      set_bufnr(self, vim.api.nvim_win_get_buf(status.preview_win))
    end

    set_bufnr(self, vim.api.nvim_create_buf(false, true))

    local bufnr = get_bufnr(self)
    vim.api.nvim_win_set_buf(status.preview_win, bufnr)

    local term_opts = {
      cwd = opts.cwd or vim.fn.getcwd(),
    }

    with_preview_window(status, bufnr, function()
      set_term_id(
        self,
        vim.fn.termopen(opts.get_command(entry, status), term_opts)
      )
    end)

    vim.api.nvim_buf_set_name(bufnr, tostring(bufnr))
  end

  if not opts.send_input then
    function opts.send_input(self, input)
      local termcode = vim.api.nvim_replace_termcodes(input, true, false, true)

      local term_id = get_term_id(self)
      if term_id then
        vim.fn.chansend(term_id, termcode)
      end
    end
  end

  if not opts.scroll_fn then
    function opts.scroll_fn(self, direction)
      if not self.state then
        return
      end

      local input = direction > 0 and "d" or "u"
      local count = math.abs(direction)

      self:send_input(count..input)
    end
  end

  return Previewer:new(opts)
end

previewers.vim_buffer = defaulter(function(_)
  return previewers.new {
    setup = function()
      return {
        last_set_bufnr = nil
      }
    end,

    teardown = function(self)
      if self.state and self.state.last_set_bufnr then
        vim.api.nvim_buf_clear_namespace(self.state.last_set_bufnr, previewer_ns, 0, -1)
      end
    end,

    preview_fn = function(self, entry, status)
      -- TODO: Consider using path here? Might not work otherwise.
      local filename = entry.filename

      if filename == nil then
        filename = entry.path
      end

      if filename == nil then
        local value = entry.value
        filename = vim.split(value, ":")[1]
      end

      if filename == nil then
        return
      end

      log.info("Previewing File:", filename)

      local bufnr = vim.fn.bufnr(filename)
      if bufnr == -1 then
        -- TODO: Is this the best way to load the buffer?... I'm not sure tbh
        bufnr = vim.fn.bufadd(filename)
        vim.fn.bufload(bufnr)

        vim.cmd([[doautocmd filetypedetect BufRead ]] .. filename)
      end

      self.state.last_set_bufnr = bufnr

      -- TODO: We should probably call something like this because we're not always getting highlight and all that stuff.
      -- api.nvim_command('doautocmd filetypedetect BufRead ' .. vim.fn.fnameescape(filename))
      vim.api.nvim_win_set_buf(status.preview_win, bufnr)
      vim.api.nvim_win_set_option(status.preview_win, 'wrap', false)
      vim.api.nvim_win_set_option(status.preview_win, 'winhl', 'Normal:Normal')
      -- vim.api.nvim_win_set_option(preview_win, 'winblend', 20)
      vim.api.nvim_win_set_option(status.preview_win, 'signcolumn', 'no')
      vim.api.nvim_win_set_option(status.preview_win, 'foldlevel', 100)

      if entry.lnum then
        vim.api.nvim_buf_add_highlight(bufnr, previewer_ns, "Visual", entry.lnum - 1, 0, -1)
        vim.api.nvim_win_set_option(status.preview_win, 'scrolloff', 10)
        vim.api.nvim_win_set_cursor(status.preview_win, {entry.lnum, 0})
        -- print("LNUM:", entry.lnum)
      end

      log.info("Previewed bufnr", bufnr)
    end,
  }
end, {})


previewers.cat = defaulter(function(opts)
  local maker = get_maker(opts)

  return previewers.new_termopen_previewer {
    get_command = function(entry)
      local path = from_entry.path(entry, true)
      if path == nil then
        return
      end

      return maker(path)
    end
  }
end, {})

previewers.vimgrep = defaulter(function(opts)
  local maker = get_maker(opts)

  return previewers.new_termopen_previewer {
    get_command = function(entry, status)
      local win_id = status.preview_win
      local height = vim.api.nvim_win_get_height(win_id)

      local filename = entry.filename
      local lnum = entry.lnum or 0

      local context = math.floor(height / 2)
      local start = math.max(0, lnum - context)
      local finish = lnum + context

      return maker(filename, lnum, start, finish)
    end,
  }
end, {})

previewers.qflist = defaulter(function(opts)
  opts = opts or {}

  local maker = get_maker(opts)

  return previewers.new_termopen_previewer {
    get_command = function(entry, status)
      local win_id = status.preview_win
      local height = vim.api.nvim_win_get_height(win_id)

      local filename = entry.filename
      local lnum = entry.lnum

      local start, finish
      if entry.start and entry.finish then
        start = entry.start
        finish = entry.finish
      else
        local context = math.floor(height / 2)
        start = math.max(0, lnum - context)
        finish = lnum + context
      end

      return maker(filename, lnum, start, finish)
    end
  }
end, {})

previewers.help = defaulter(function(_)
  return previewers.new {
    setup = function()
      return {}
    end,

    teardown = function(self)
      if self.state and self.state.hl_id then
        pcall(vim.fn.matchdelete, self.state.hl_id, self.state.hl_win)
        self.state.hl_id = nil
      end
    end,

    preview_fn = function(self, entry, status)
      with_preview_window(status, nil, function()
        local special_chars = ":~^.?/%[%]%*"

        local escaped = vim.fn.escape(entry.value, special_chars)
        local tagfile = vim.fn.expand("$VIMRUNTIME") .. '/doc/tags'
        local old_tags = vim.o.tags

        vim.o.tags = tagfile
        local taglist = vim.fn.taglist('^' .. escaped .. '$', tagfile)
        vim.o.tags = old_tags

        if vim.tbl_isempty(taglist) then
          taglist = vim.fn.taglist(escaped, tagfile)
        end

        if vim.tbl_isempty(taglist) then
          return
        end

        local best_entry = taglist[1]
        local new_bufnr = vim.fn.bufnr(best_entry.filename, true)

        vim.api.nvim_buf_set_option(new_bufnr, 'filetype', 'help')
        vim.api.nvim_win_set_buf(status.preview_win, new_bufnr)

        local search_query = best_entry.cmd

        -- remove leading '/'
        search_query = search_query:sub(2)

        -- Set the query to "very nomagic".
        -- This should make it work quite nicely given tags.
        search_query = [[\V]] .. search_query

        log.trace([[lua vim.fn.search("]], search_query, [[")]])

        vim.cmd "norm! gg"
        vim.fn.search(search_query, "W")
        vim.cmd "norm  zt"

        self.state.hl_win = status.preview_win
        self.state.hl_id = vim.fn.matchadd('Search', search_query)
      end)
    end
  }
end, {})

-- WIP
-- TODO: This needs a big rewrite.
previewers.vim_buffer_or_bat = defaulter(function(_)
  return previewers.new {
    preview_fn = function(_, entry, status)
        local value = entry.value
      if value == nil then
        return
      end

      local file_name = vim.split(value, ":")[1]

      log.trace("Previewing File: '%s'", file_name)

      -- vim.fn.termopen(
      --   string.format("bat --color=always --style=grid '%s'"),
      -- vim.fn.fnamemodify(file_name, ":p")
      local bufnr = vim.fn.bufadd(file_name)

      if vim.api.nvim_buf_is_loaded(bufnr) then
        vim.fn.bufload(bufnr)

        -- TODO: We should probably call something like this because we're not always getting highlight and all that stuff.
        -- api.nvim_command('doautocmd filetypedetect BufRead ' .. vim.fn.fnameescape(filename))
        vim.api.nvim_win_set_buf(status.preview_win, bufnr)
        vim.api.nvim_win_set_option(status.preview_win, 'wrap', false)
        vim.api.nvim_win_set_option(status.preview_win, 'winhl', 'Normal:Normal')
        -- vim.api.nvim_win_set_option(preview_win, 'winblend', 20)
        vim.api.nvim_win_set_option(status.preview_win, 'signcolumn', 'no')
        vim.api.nvim_win_set_option(status.preview_win, 'foldlevel', 100)
      else
        vim.api.nvim_buf_set_lines(status.preview_bufnr, 0, -1, false, vim.fn.systemlist(string.format('bat "%s"', file_name)))
      end
    end,
  }
end, {})


previewers.nvim_file = defaulter(function(_)
  return previewers.new {
    preview_fn = function(_, entry, status)
      local filename = entry.filename

      if filename == nil then
        filename = entry.path
      end

      -- if filename == nil then
      --   local value = entry.value
      --   filename = vim.split(value, ":")[1]
      -- end

      if filename == nil then
        log.info("Could not find file from entry", entry)
        return
      end

      local win_id = status.preview_win
      local bufnr = vim.fn.bufnr(filename)
      if bufnr == -1 then
        bufnr = vim.api.nvim_create_buf(false, true)
        -- vim.api.nvim_buf_set_name(bufnr, filename)
        vim.api.nvim_win_set_buf(win_id, bufnr)

        vim.api.nvim_win_set_option(status.preview_win, 'wrap', false)
        if false then
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.fn.readfile(filename))
          vim.api.nvim_buf_set_option(bufnr, 'filetype', 'lua')
        else
          vim.api.nvim_buf_call(bufnr, function()
            vim.cmd(":noauto view " .. filename)
            vim.api.nvim_command("doautocmd filetypedetect BufRead " .. vim.fn.fnameescape(filename))
          end)
        end

        vim.api.nvim_command("doautocmd filetypedetect BufRead " .. vim.fn.fnameescape(filename))
        -- print("FT:", vim.api.nvim_buf_get_option(bufnr, 'filetype'))
      else
        vim.api.nvim_win_set_buf(win_id, bufnr)
        vim.api.nvim_win_set_option(status.preview_win, 'wrap', false)
        vim.api.nvim_win_set_option(status.preview_win, 'winhl', 'Normal:Normal')
      end

      -- vim.api.nvim_buf_set_option(bufnr, 'filetype', 'lua')
      -- vim.cmd([[doautocmd filetypedetect BufRead ]] .. vim.fn.fnameescape(filename))
    end,
  }
end)

previewers.man = defaulter(function(_)
  return previewers.new {
    preview_fn = debounce.throttle_leading(function(_, entry, status)
      local cmd = entry.value

      local st = {}
      st.prompt_win = status.prompt_win
      st.preview_win = status.preview_win

      with_preview_window(st, nil, function()
        if not vim.api.nvim_win_is_valid(st.preview_win) then
          return
        end

        local man_value = vim.fn['man#goto_tag'](cmd, '', '')
        if #man_value == 0 then
          print("No value for:", cmd)
          return
        end

        local filename = man_value[1].filename
        if vim.api.nvim_buf_get_name(0) == filename then
          return
        end

        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_win_set_buf(st.preview_win, bufnr)
        vim.api.nvim_command('view ' .. filename)

        vim.api.nvim_buf_set_option(bufnr, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(bufnr, 'bufhidden', 'hide')
        vim.api.nvim_buf_set_option(bufnr, 'swapfile', false)
        vim.api.nvim_buf_set_option(bufnr, 'buflisted', false)
      end)
    end, 5)
  }
end)

previewers.Previewer = Previewer

return previewers
