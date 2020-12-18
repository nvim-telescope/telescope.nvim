local context_manager = require('plenary.context_manager')

local conf = require('telescope.config').values
local debounce = require('telescope.debounce')
local from_entry = require('telescope.from_entry')
local utils = require('telescope.utils')
local path = require('telescope.path')

local pfiletype = require('plenary.filetype')

local has_ts, _ = pcall(require, 'nvim-treesitter')
local _, ts_highlight = pcall(require, 'nvim-treesitter.highlight')
local _, ts_parsers = pcall(require, 'nvim-treesitter.parsers')

local flatten = vim.tbl_flatten
local buf_delete = utils.buf_delete
local job_is_running = utils.job_is_running

local defaulter = utils.make_default_callable

local previewers = {}

local Previewer = {}
Previewer.__index = Previewer

-- TODO: Should play with these some more, ty @clason
local bat_options = {"--style=plain", "--color=always", "--paging=always"}
local has_less = (vim.fn.executable('less') == 1) and conf.use_less
local termopen_env = vim.tbl_extend("force", { ['GIT_PAGER'] = (has_less and 'less' or '') }, conf.set_env)

-- TODO(conni2461): Workaround for neovim/neovim#11751. Add only quotes when using else branch.
local valuate_shell = function()
  local shell = vim.o.shell
  if string.find(shell, 'powershell.exe') or string.find(shell, 'cmd.exe') then
    return ''
  else
    return "'"
  end
end

local add_quotes = valuate_shell()

local file_maker_async = function(filepath, bufnr, bufname, callback)
  local ft = pfiletype.detect(filepath)

  if bufname ~= filepath then
    path.read_file_async(filepath, vim.schedule_wrap(function(data)
      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(data, "\n"))

      if callback then callback() end
    end))
  else
    if callback then callback() end
  end

  if ft ~= '' then
    if has_ts and ts_parsers.has_parser(ft) then
      ts_highlight.attach(bufnr, ft)
    else
      vim.cmd(':ownsyntax ' .. ft)
    end
  end
end

local file_maker_sync = function(filepath, bufnr, bufname)
  local ft = pfiletype.detect(filepath)
  if bufname ~= filepath then
    local data = path.read_file(filepath)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(data, "\n"))
  end

  if ft ~= '' then
    if has_ts and ts_parsers.has_parser(ft) then
      ts_highlight.attach(bufnr, ft)
    else
      vim.cmd(':ownsyntax ' .. ft)
    end
  end
end

local get_file_stat = function(filename)
  return vim.loop.fs_stat(vim.fn.expand(filename)) or {}
end

local bat_maker = function(filename, lnum, start, finish)
  if get_file_stat(filename).type == 'directory' then
    return { 'ls', '-la', vim.fn.expand(filename) }
  end

  local command = {"bat"}
  local theme = os.getenv("BAT_THEME")

  if lnum then
    table.insert(command, { "--highlight-line", lnum})
  end

  if has_less then
    if start then
      table.insert(command, {"--pager", string.format("%sless -RS +%s%s", add_quotes, start, add_quotes)})
    else
      table.insert(command, {"--pager", string.format("%sless -RS%s", add_quotes, add_quotes)})
    end
  else
    if start and finish then
      table.insert(command, { "-r", string.format("%s:%s", start, finish) })
    end
  end

  if theme ~= nil then
    table.insert(command, { "--theme", string.format("%s", vim.fn.shellescape(theme)) })
  end

  return flatten {
    command, bat_options, "--", add_quotes .. vim.fn.expand(filename) .. add_quotes
  }
end

-- TODO: Add other options for cat to do this better
local cat_maker = function(filename, _, start, _)
  if get_file_stat(filename).type == 'directory' then
    return { 'ls', '-la', add_quotes .. vim.fn.expand(filename) .. add_quotes }
  end

  if 1 == vim.fn.executable('file') then
    local output = utils.get_os_command_output('file --mime-type -b ' .. filename)
    local mime_type = vim.split(output, '/')[1]
    if mime_type ~= "text" then
      return { "echo", "Binary file found. These files cannot be displayed!" }
    end
  end

  if has_less then
    if start then
      return { 'less', '-RS', string.format('+%s', start), add_quotes .. vim.fn.expand(filename) .. add_quotes }
    else
      return { 'less', '-RS', add_quotes .. vim.fn.expand(filename) .. add_quotes }
    end
  else
    return {
      "cat", "--", add_quotes .. vim.fn.expand(filename) .. add_quotes
    }
  end
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

previewers.new_buffer_previewer = function(opts)
  opts = opts or {}

  assert(opts.define_preview, "define_preview is a required function")
  assert(not opts.preview_fn, "preview_fn not allowed")

  local opt_setup = opts.setup
  local opt_teardown = opts.teardown

  local old_bufs = {}
  local bufname_table = {}

  local function get_bufnr(self)
    if not self.state then return nil end
    return self.state.bufnr
  end

  local function set_bufnr(self, value)
    if get_bufnr(self) then table.insert(old_bufs, get_bufnr(self)) end
    if self.state then self.state.bufnr = value end
  end

  local function get_bufnr_by_bufname(self, value)
    if not self.state then return nil end
    return bufname_table[value]
  end

  local function set_bufname(self, value)
    if get_bufnr(self) then bufname_table[value] = get_bufnr(self) end
    if self.state then self.state.bufname = value end
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

    set_bufnr(self, nil)
    set_bufname(self, nil)

    for _, bufnr in ipairs(old_bufs) do
      buf_delete(bufnr)
    end
  end

  function opts.preview_fn(self, entry, status)
    if get_bufnr(self) == nil then
      set_bufnr(self, vim.api.nvim_win_get_buf(status.preview_win))
    end

    if opts.get_buffer_by_name and get_bufnr_by_bufname(self, opts.get_buffer_by_name(self, entry)) then
      self.state.bufname = opts.get_buffer_by_name(self, entry)
      self.state.bufnr = get_bufnr_by_bufname(self, self.state.bufname)
      vim.api.nvim_win_set_buf(status.preview_win, self.state.bufnr)
    else
      local bufnr = vim.api.nvim_create_buf(false, true)
      set_bufnr(self, bufnr)

      vim.api.nvim_win_set_buf(status.preview_win, bufnr)

      -- TODO(conni2461): We only have to set options once. Right?
      vim.api.nvim_win_set_option(status.preview_win, 'winhl', 'Normal:Normal')
      vim.api.nvim_win_set_option(status.preview_win, 'signcolumn', 'no')
      vim.api.nvim_win_set_option(status.preview_win, 'foldlevel', 100)
      vim.api.nvim_win_set_option(status.preview_win, 'scrolloff', 999)
      vim.api.nvim_win_set_option(status.preview_win, 'wrap', false)

      self.state.winid = status.preview_win
      self.state.bufname = nil
    end

    opts.define_preview(self, entry, status)

    if opts.get_buffer_by_name then
      set_bufname(self, opts.get_buffer_by_name(self, entry))
    end
  end

  if not opts.scroll_fn then
    function opts.scroll_fn(self, direction)
      local input = direction > 0 and "d" or "u"
      local count = math.abs(direction)

      self:send_input({ count = count, input = input })
    end
  end

  if not opts.send_input then
    function opts.send_input(self, input)
      if not self.state then
        return
      end

      local max_line = vim.fn.getbufinfo(self.state.bufnr)[1].linecount
      local line = vim.api.nvim_win_get_cursor(self.state.winid)[1]
      if input.input == 'u' then
        line = (line - input.count) > 0 and (line - input.count) or 1
      else
        line = (line + input.count) <= max_line and (line + input.count) or max_line
      end
      vim.api.nvim_win_set_cursor(self.state.winid, { line, 1 })
    end
  end

  return Previewer:new(opts)
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
      env = termopen_env
    }

    -- TODO(conni2461): Workaround for neovim/neovim#11751.
    local get_cmd = function(st)
      local shell = vim.o.shell
      if string.find(shell, 'powershell.exe') or string.find(shell, 'cmd.exe') then
        return opts.get_command(entry, st)
      else
        local env = {}
        for k, v in pairs(termopen_env) do
          table.insert(env, k .. '=' .. v)
        end
        return table.concat(env, ' ') .. ' ' .. table.concat(opts.get_command(entry, st), ' ')
      end
    end

    with_preview_window(status, bufnr, function()
      set_term_id(self, vim.fn.termopen(get_cmd(status), term_opts))
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

previewers.git_commit_diff = defaulter(function(_)
  return previewers.new_termopen_previewer {
    get_command = function(entry)
      local sha = entry.value
      return { 'git', '-p', 'diff', sha .. '^!' }
    end
  }
end, {})

previewers.git_branch_log = defaulter(function(_)
  return previewers.new_termopen_previewer {
    get_command = function(entry)
      return { 'git', '-p', 'log', '--graph',
               "--pretty=format:" .. add_quotes .. "%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset"
               .. add_quotes,
               '--abbrev-commit', '--date=relative', entry.value }
    end
  }
end, {})

previewers.git_file_diff = defaulter(function(_)
  return previewers.new_termopen_previewer {
    get_command = function(entry)
      return { 'git', '-p', 'diff', entry.value }
    end
  }
end, {})

previewers.cat = defaulter(function(opts)
  local maker = get_maker(opts)

  return previewers.new_termopen_previewer {
    get_command = function(entry)
      local p = from_entry.path(entry, true)
      if p == nil or p == '' then return end

      return maker(p)
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

previewers.vim_buffer_cat = defaulter(function(_)
  return previewers.new_buffer_previewer {
    get_buffer_by_name = function(_, entry)
      return from_entry.path(entry, true)
    end,

    define_preview = function(self, entry, status)
      with_preview_window(status, nil, function()
        local p = from_entry.path(entry, true)
        if p == nil or p == '' then return end
        file_maker_async(p, self.state.bufnr, self.state.bufname)
      end)
    end
  }
end, {})

previewers.vim_buffer_vimgrep = defaulter(function(_)
  return previewers.new_buffer_previewer {
    setup = function()
      return {
        last_set_bufnr = nil
      }
    end,

    teardown = function(self)
      if self.state and self.state.last_set_bufnr and vim.api.nvim_buf_is_valid(self.state.last_set_bufnr) then
        vim.api.nvim_buf_clear_namespace(self.state.last_set_bufnr, previewer_ns, 0, -1)
      end
    end,

    get_buffer_by_name = function(_, entry)
      return from_entry.path(entry, true)
    end,

    define_preview = function(self, entry, status)
      with_preview_window(status, nil, function()
        local lnum = entry.lnum or 0
        local p = from_entry.path(entry, true)
        if p == nil or p == '' then return end

        file_maker_sync(p, self.state.bufnr, self.state.bufname)

        if lnum ~= 0 then
          if self.state.last_set_bufnr then
            pcall(vim.api.nvim_buf_clear_namespace, self.state.last_set_bufnr, previewer_ns, 0, -1)
          end
          pcall(vim.api.nvim_buf_add_highlight, self.state.bufnr, previewer_ns, "TelescopePreviewLine", lnum - 1, 0, -1)
          pcall(vim.api.nvim_win_set_cursor, status.preview_win, {lnum, 0})
        end

        self.state.last_set_bufnr = self.state.bufnr
      end)
    end
  }
end, {})

previewers.vim_buffer_qflist = previewers.vim_buffer_vimgrep

previewers.ctags = defaulter(function(_)
  return previewers.new_buffer_previewer {
    teardown = function(self)
      if self.state and self.state.hl_id then
        pcall(vim.fn.matchdelete, self.state.hl_id, self.state.hl_win)
        self.state.hl_id = nil
      end
    end,

    get_buffer_by_name = function(_, entry)
      return entry.filename
    end,

    define_preview = function(self, entry, status)
      with_preview_window(status, nil, function()
        local scode = string.gsub(entry.scode, '[$]$', '')
        scode = string.gsub(scode, [[\\]], [[\]])
        scode = string.gsub(scode, [[\/]], [[/]])
        scode = string.gsub(scode, '[*]', [[\*]])

        file_maker_sync(entry.filename, self.state.bufnr, self.state.bufname)

        pcall(vim.fn.matchdelete, self.state.hl_id, self.state.winid)
        vim.cmd "norm! gg"
        vim.fn.search(scode)

        self.state.hl_id = vim.fn.matchadd('TelescopePreviewMatch', scode)
      end)
    end
  }
end, {})

previewers.builtin = defaulter(function(_)
  return previewers.new_buffer_previewer {
    setup = function()
      return {}
    end,

    teardown = function(self)
      if self.state and self.state.hl_id then
        pcall(vim.fn.matchdelete, self.state.hl_id, self.state.hl_win)
        self.state.hl_id = nil
      end
    end,

    get_buffer_by_name = function(_, entry)
      return entry.filename
    end,

    define_preview = function(self, entry, status)
      with_preview_window(status, nil, function()
        local module_name = vim.fn.fnamemodify(entry.filename, ':t:r')
        local text
        if entry.text:sub(1, #module_name) ~= module_name then
          text = module_name .. '.' .. entry.text
        else
          text = entry.text:gsub('_', '.', 1)
        end

        file_maker_sync(entry.filename, self.state.bufnr, self.state.bufname)

        pcall(vim.fn.matchdelete, self.state.hl_id, self.state.winid)
        vim.cmd "norm! gg"
        vim.fn.search(text)

        self.state.hl_id = vim.fn.matchadd('TelescopePreviewMatch', text)
      end)
    end
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
  return previewers.new_buffer_previewer {
    setup = function()
      return {}
    end,

    teardown = function(self)
      if self.state and self.state.hl_id then
        pcall(vim.fn.matchdelete, self.state.hl_id, self.state.hl_win)
        self.state.hl_id = nil
      end
    end,

    get_buffer_by_name = function(_, entry)
      return entry.filename
    end,

    define_preview = function(self, entry, status)
      with_preview_window(status, nil, function()
        local query = entry.cmd
        query = query:sub(2)
        query = [[\V]] .. query

        file_maker_sync(entry.filename, self.state.bufnr, self.state.bufname)
        vim.cmd(':ownsyntax help')

        pcall(vim.fn.matchdelete, self.state.hl_id, self.state.winid)
        vim.cmd "norm! gg"
        vim.fn.search(query, "W")

        self.state.hl_id = vim.fn.matchadd('TelescopePreviewMatch', query)
      end)
    end
  }
end, {})

previewers.man = defaulter(function(_)
  return previewers.new_buffer_previewer {
    define_preview = debounce.throttle_leading(function(self, entry, status)
      with_preview_window(status, nil, function()
        local cmd = entry.value
        local man_value = vim.fn['man#goto_tag'](cmd, '', '')
        if #man_value == 0 then
          print("No value for:", cmd)
          return
        end

        local filename = man_value[1].filename
        if vim.api.nvim_buf_get_name(0) == filename then
          return
        end

        vim.api.nvim_command('view ' .. filename)

        vim.api.nvim_buf_set_option(self.state.bufnr, 'buftype', 'nofile')
        vim.api.nvim_buf_set_option(self.state.bufnr, 'bufhidden', 'hide')
        vim.api.nvim_buf_set_option(self.state.bufnr, 'swapfile', false)
        vim.api.nvim_buf_set_option(self.state.bufnr, 'buflisted', false)
      end)
    end, 5)
  }
end)

previewers.autocommands = defaulter(function(_)
  return previewers.new_buffer_previewer {
    teardown = function(self)
      if self.state and self.state.last_set_bufnr and vim.api.nvim_buf_is_valid(self.state.last_set_bufnr) then
        pcall(vim.api.nvim_buf_clear_namespace, self.state.last_set_bufnr, previewer_ns, 0, -1)
      end
    end,

    get_buffer_by_name = function(_, entry)
      return entry.group
    end,

    define_preview = function(self, entry, status)
      local results = vim.tbl_filter(function (x)
        return x.group == entry.group
      end, status.picker.finder.results)

      if self.state.last_set_bufnr then
        pcall(vim.api.nvim_buf_clear_namespace, self.state.last_set_bufnr, previewer_ns, 0, -1)
      end

      local selected_row = 0
      if self.state.bufname ~= entry.group then
        local display = {}
        table.insert(display, string.format(" augroup: %s - [ %d entries ]", entry.group, #results))
        -- TODO: calculate banner width/string in setup()
        -- TODO: get column characters to be the same HL group as border
        table.insert(display, string.rep("─", vim.fn.getwininfo(status.preview_win)[1].width))

        for idx, item in ipairs(results) do
          if item == entry then
            selected_row = idx
          end
          table.insert(display,
            string.format("  %-14s▏%-08s %s", item.event, item.ft_pattern, item.command)
          )
        end

        vim.api.nvim_buf_set_option(self.state.bufnr, "filetype", "vim")
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, display)
        vim.api.nvim_buf_add_highlight(self.state.bufnr, 0, "TelescopeBorder", 1, 0, -1)
      else
        for idx, item in ipairs(results) do
          if item == entry then
            selected_row = idx
            break
          end
        end
      end

      vim.api.nvim_buf_add_highlight(self.state.bufnr, previewer_ns, "TelescopePreviewLine", selected_row + 1, 0, -1)
      vim.api.nvim_win_set_cursor(status.preview_win, {selected_row + 1, 0})

      self.state.last_set_bufnr = self.state.bufnr
    end,
  }
end, {})

previewers.highlights = defaulter(function(_)
  return previewers.new_buffer_previewer {
    teardown = function(self)
      if self.state and self.state.last_set_bufnr and vim.api.nvim_buf_is_valid(self.state.last_set_bufnr) then
        vim.api.nvim_buf_clear_namespace(self.state.last_set_bufnr, previewer_ns, 0, -1)
      end
    end,

    get_buffer_by_name = function(_, entry)
      return "highlights"
    end,

    define_preview = function(self, entry, status)
      with_preview_window(status, nil, function()
        if not self.state.bufname then
          local output = vim.split(vim.fn.execute('highlight'), '\n')
          local hl_groups = {}
          for _, v in ipairs(output) do
            if v ~= '' then
              if v:sub(1, 1) == ' ' then
                local part_of_old = v:match('%s+(.*)')
                hl_groups[table.getn(hl_groups)] = hl_groups[table.getn(hl_groups)] .. part_of_old
              else
                table.insert(hl_groups, v)
              end
            end
          end

          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, hl_groups)
          for k, v in ipairs(hl_groups) do
            local startPos = string.find(v, 'xxx', 1, true) - 1
            local endPos = startPos + 3
            local hlgroup = string.match(v, '([^ ]*)%s+.*')
            pcall(vim.api.nvim_buf_add_highlight, self.state.bufnr, 0, hlgroup, k - 1, startPos, endPos)
          end
        end

        pcall(vim.api.nvim_buf_clear_namespace, self.state.bufnr, previewer_ns, 0, -1)
        vim.cmd "norm! gg"
        vim.fn.search(entry.value .. ' ')
        local lnum = vim.fn.line('.')
        -- That one is actually a match but its better to use it like that then matchadd
        vim.api.nvim_buf_add_highlight(self.state.bufnr,
          previewer_ns,
          "TelescopePreviewMatch",
          lnum - 1,
          0,
          #entry.value)
      end)
    end,
  }
end, {})

previewers.display_content = defaulter(function(_)
  return previewers.new_buffer_previewer {
    define_preview = function(self, entry, status)
      with_preview_window(status, nil, function()
        assert(type(entry.preview_command) == 'function',
               'entry must provide a preview_command function which will put the content into the buffer')
        entry.preview_command(entry, self.state.bufnr)
      end)
    end
  }
end, {})

previewers.Previewer = Previewer

return previewers
