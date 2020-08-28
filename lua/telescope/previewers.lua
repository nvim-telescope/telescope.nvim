local log = require('telescope.log')

local previewers = {}

local Previewer = {}
Previewer.__index = Previewer

function Previewer:new(opts)
  opts = opts or {}

  return setmetatable({
    state = nil,
    _setup_func = opts.setup,
    preview_fn = opts.preview_fn,
  }, Previewer)
end

function Previewer:preview(entry, status)
  if not entry then
    return
  end

  if not self.state and self._setup_func then
    self.state = self._setup_func()
  end

  return self:preview_fn(entry, status)
end

previewers.new = function(...)
  return Previewer:new(...)
end

previewers.vim_buffer = previewers.new {
  preview_fn = function(_, entry, status)
    local value = entry.value
    if value == nil then
      return
    end
    local file_name = vim.split(value, ":")[1]

    log.trace("Previewing File: %s", file_name)

    -- vim.fn.termopen(
    --   string.format("bat --color=always --style=grid %s"),
    -- vim.fn.fnamemodify(file_name, ":p")
    local bufnr = vim.fn.bufadd(file_name)
    vim.fn.bufload(bufnr)

    -- TODO: We should probably call something like this because we're not always getting highlight and all that stuff.
    -- api.nvim_command('doautocmd filetypedetect BufRead ' .. vim.fn.fnameescape(filename))
    vim.api.nvim_win_set_buf(status.preview_win, bufnr)
    vim.api.nvim_win_set_option(status.preview_win, 'wrap', false)
    vim.api.nvim_win_set_option(status.preview_win, 'winhl', 'Normal:Normal')
    -- vim.api.nvim_win_set_option(preview_win, 'winblend', 20)
    vim.api.nvim_win_set_option(status.preview_win, 'signcolumn', 'no')
    vim.api.nvim_win_set_option(status.preview_win, 'foldlevel', 100)
  end,
}


previewers.vim_buffer_or_bat = previewers.new {
  preview_fn = function(_, entry, status)
      local value = entry.value
    if value == nil then
      return
    end

    local file_name = vim.split(value, ":")[1]

    log.info("Previewing File: %s", file_name)

    -- vim.fn.termopen(
    --   string.format("bat --color=always --style=grid %s"),
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
      vim.api.nvim_buf_set_lines(status.preview_bufnr, 0, -1, false, vim.fn.systemlist(string.format('bat %s', file_name)))
    end
  end,
}

previewers.cat = previewers.new {
  setup = function()
    local command_string = "cat %s"
    if vim.fn.executable("bat") then
      command_string = "bat %s --style=grid --paging=always"
    end

    return {
      command_string = command_string
    }
  end,

  preview_fn = function(self, entry, status)
    local bufnr = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_win_set_buf(status.preview_win, bufnr)

    -- HACK! Requires `termopen` to accept buffer argument.
    vim.cmd(string.format("noautocmd call win_gotoid(%s)", status.preview_win))
    vim.fn.termopen(string.format(self.state.command_string, entry.value))
    vim.cmd(string.format("noautocmd call win_gotoid(%s)", status.prompt_win))

    vim.api.nvim_buf_set_name(bufnr, tostring(bufnr))
  end
}

previewers.vimgrep = previewers.new {
  setup = function()
    local command_string = "cat %s"
    if vim.fn.executable("bat") then
      command_string = "bat %s --style=grid --paging=always --highlight-line %s -r %s:%s"
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

    local context = math.floor(height / 2)
    local start = math.max(0, lnum - context)
    local finish = lnum + context

    vim.api.nvim_win_set_buf(status.preview_win, bufnr)

    -- HACK! Requires `termopen` to accept buffer argument.
    vim.cmd(string.format("noautocmd call win_gotoid(%s)", status.preview_win))
    vim.fn.termopen(string.format(self.state.command_string, filename, lnum, start, finish))
    vim.cmd(string.format("noautocmd call win_gotoid(%s)", status.prompt_win))

  end
}

previewers.qflist = previewers.new {
  setup = function()
    local command_string = "cat %s"
    if vim.fn.executable("bat") then
      command_string = "bat %s --style=grid --paging=always --highlight-line %s -r %s:%s"
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

    local context = math.floor(height / 2)
    local start = math.max(0, lnum - context)
    local finish = lnum + context

    vim.api.nvim_win_set_buf(status.preview_win, bufnr)

    -- HACK! Requires `termopen` to accept buffer argument.
    vim.cmd(string.format("noautocmd call win_gotoid(%s)", status.preview_win))
    vim.fn.termopen(string.format(self.state.command_string, filename, lnum, start, finish))
    vim.cmd(string.format("noautocmd call win_gotoid(%s)", status.prompt_win))
  end
}

previewers.Previewer = Previewer

return previewers
