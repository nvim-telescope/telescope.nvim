local context_manager = require('plenary.context_manager')

local log = require('telescope.log')
local utils = require('telescope.utils')

local defaulter = utils.make_default_callable

local previewers = {}

local Previewer = {}
Previewer.__index = Previewer

-- TODO: Should play with these some more, ty @clason
local bat_options = " --style=plain --color=always "

local previewer_ns = vim.api.nvim_create_namespace('telescope.previewers')

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
      self.state = self._setup_func()
    else
      self.state = {}
    end
  end

  self:teardown()
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

local with_preview_window = function(status, callable)
  return context_manager.with(function()
    vim.cmd(string.format("noautocmd call win_gotoid(%s)", status.preview_win))
    coroutine.yield()
    vim.cmd(string.format("noautocmd call win_gotoid(%s)", status.prompt_win))
  end, callable)
end

previewers.termopen = defaulter(function(opts)
  local command_string = assert(opts.command, 'opts.command is required')

  return previewers.new {
    preview_fn = function(_, entry, status)
      local bufnr = vim.api.nvim_create_buf(false, true)

      vim.api.nvim_win_set_buf(status.preview_win, bufnr)

      with_preview_window(status, function()
        vim.fn.termopen(string.format(command_string, entry.value))
      end)
    end
  }
end, {})

previewers.vim_buffer = defaulter(function(_)
  return previewers.new {
    setup = function() return { last_set_bufnr = nil } end,

    teardown = function(self)
      if self.state.last_set_bufnr then
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

previewers.cat = defaulter(function(opts)
  return previewers.new {
    setup = function()
      local command_string = "cat -- '%s'"
      if 1 == vim.fn.executable("bat") then
        command_string = "bat " .. bat_options .. " -- '%s'"
      end

      return {
        command_string = command_string,
        termopen_id = nil,
      }
    end,

    send_input = function(self, input)
      termcode = vim.api.nvim_replace_termcodes(input, true, false, true)
      if self.state.termopen_id then
        pcall(vim.fn.chansend, self.state.termopen_id, termcode)
      end
    end,

    scroll_fn = function(self, direction)
      if not self.state then
        return
      end
      if direction > 0 then input = "d" else input = "u" end
      local count = math.abs(direction)
      self:send_input(count..input)
    end,

    teardown = function(self)
      if not self.state then
        return
      end

      if self.state.termopen_id then
        pcall(vim.fn.chanclose, self.state.termopen_id)
      end
    end,

    preview_fn = function(self, entry, status)
      local bufnr = vim.api.nvim_create_buf(false, true)

      vim.api.nvim_win_set_buf(status.preview_win, bufnr)

      local path = entry.path
      if path == nil then path = entry.filename end
      if path == nil then path = entry.value end
      if path == nil then print("Invalid entry", vim.inspect(entry)); return end

      local term_opts = vim.empty_dict()
      term_opts.cwd = opts.cwd

      with_preview_window(status, function()
        self.state.termopen_id = vim.fn.termopen(string.format(self.state.command_string, path), term_opts)
      end)

      vim.api.nvim_buf_set_name(bufnr, tostring(bufnr))
    end
  }
end, {})

previewers.vimgrep = defaulter(function(_)
  return previewers.new {
    setup = function()
      local command_string = "cat -- '%s'"
      if vim.fn.executable("bat") then
        command_string = "bat --highlight-line '%s' -r '%s':'%s'" .. bat_options .. " -- '%s'"
      end

      return {
        command_string = command_string
      }
    end,

    preview_fn = function(self, entry, status)
      local bufnr = vim.api.nvim_create_buf(false, true)
      local win_id = status.preview_win
      local height = vim.api.nvim_win_get_height(win_id)

      local line = entry.value
      if type(line) == "table" then
        line = entry.ordinal
      end

      local _, _, filename, lnum, col, text = string.find(line, [[([^:]+):(%d+):(%d+):(.*)]])

      filename = filename or entry.filename
      lnum = lnum or entry.lnum or 0

      local context = math.floor(height / 2)
      local start = math.max(0, lnum - context)
      local finish = lnum + context

      vim.api.nvim_win_set_buf(status.preview_win, bufnr)

      local termopen_command = string.format(self.state.command_string, lnum, start, finish, filename)

      with_preview_window(status, function()
        vim.fn.termopen(termopen_command)
      end)

    end
  }
end, {})

previewers.qflist = defaulter(function(_)
  return previewers.new {
    setup = function()
      local command_string = "cat '%s'"
      if vim.fn.executable("bat") then
        command_string = "bat '%s' --highlight-line '%s' -r '%s':'%s'" .. bat_options
      end

      return {
        command_string = command_string
      }
    end,

    preview_fn = function(self, entry, status)
      local bufnr = vim.api.nvim_create_buf(false, true)
      local win_id = status.preview_win
      local height = vim.api.nvim_win_get_height(win_id)

      local filename = entry.value.filename
      local lnum = entry.value.lnum

      local start, finish
      if entry.start and entry.finish then
        start = entry.start
        finish = entry.finish
      else
        local context = math.floor(height / 2)
        start = math.max(0, lnum - context)
        finish = lnum + context
      end

      vim.api.nvim_win_set_buf(status.preview_win, bufnr)

      local termopen_command = string.format(self.state.command_string, filename, lnum, start, finish)

      with_preview_window(status, function()
        vim.fn.termopen(termopen_command)
      end)
    end
  }
end, {})

previewers.help = defaulter(function(_)
  return previewers.new {
    preview_fn = function(_, entry, status)
      with_preview_window(status, function()
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

previewers.planet_previewer = previewers.new {
  preview_fn = function(self, entry, status)
    local bufnr = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_win_set_buf(status.preview_win, bufnr)

    local termopen_command = "bat " .. entry.value

    -- HACK! Requires `termopen` to accept buffer argument.
    vim.cmd(string.format("noautocmd call win_gotoid(%s)", status.preview_win))
    vim.fn.termopen(termopen_command)
    vim.cmd(string.format("noautocmd call win_gotoid(%s)", status.prompt_win))
  end
}

previewers.Previewer = Previewer

return previewers
