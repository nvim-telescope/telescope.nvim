local context_manager = require('plenary.context_manager')

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
local bat_options = {"--style=plain", "--color=always"}
local bat_maker = function(filename, lnum, start, finish)
  local command = {"bat"}

  if lnum then
    table.insert(command, { "--highlight-line", lnum})
  end

  if start and finish then
    table.insert(command, { "-r", string.format("%s:%s", start, finish) })
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
  if bufnr and vim.api.nvim_buf_call then
    vim.api.nvim_buf_call(bufnr, callable)
  else
    return context_manager.with(function()
      vim.cmd(string.format("noautocmd call win_gotoid(%s)", status.preview_win))
      coroutine.yield()
      vim.cmd(string.format("noautocmd call win_gotoid(%s)", status.prompt_win))
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
    setup = function() return { last_set_bufnr = nil } end,

    teardown = function(self)
      if self.state and self.state.last_set_bufnr then
        vim.api.nvim_buf_clear_namespace(self.state.last_set_bufnr, previewer_ns, 0, -1)
      end
    end,

    preview_fn = function(self, entry, status)
      -- TODO: Consider using path here? Might not work otherwise.
      local filename = entry.filename

      if filename == nil then
        local value = entry.value
        filename = vim.split(value, ":")[1]
      end

      if filename == nil then
        return
      end

      log.trace("Previewing File: %s", filename)

      local bufnr = vim.fn.bufnr(filename)
      if bufnr == -1 then
        -- TODO: Is this the best way to load the buffer?... I'm not sure tbh
        bufnr = vim.fn.bufadd(bufnr)
        vim.fn.bufload(bufnr)
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

-- WIP
previewers.help = defaulter(function(_)
  return previewers.new {
    preview_fn = function(_, entry, status)
      with_preview_window(status, nil, function()
        local old_tags = vim.o.tags
        vim.o.tags = vim.fn.expand("$VIMRUNTIME") .. '/doc/tags'

        local taglist = vim.fn.taglist('^' .. entry.value .. '$')
        if vim.tbl_isempty(taglist) then
          taglist = vim.fn.taglist(entry.value)
        end

        if vim.tbl_isempty(taglist) then
          return
        end

        local best_entry = taglist[1]
        local new_bufnr = vim.fn.bufnr(best_entry.filename, true)

        vim.api.nvim_buf_set_option(new_bufnr, 'filetype', 'help')
        vim.api.nvim_win_set_buf(status.preview_win, new_bufnr)

        vim.cmd [["gg"]]
        print(best_entry.cmd)
        vim.cmd(string.format([[execute "%s"]], best_entry.cmd))

        vim.o.tags = old_tags
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

previewers.Previewer = Previewer

return previewers
