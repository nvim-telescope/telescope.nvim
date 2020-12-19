local debounce = require('telescope.debounce')
local from_entry = require('telescope.from_entry')
local path = require('telescope.path')
local utils = require('telescope.utils')
local putils = require('telescope.previewers.utils')
local Previewer = require('telescope.previewers.previewer')

local pfiletype = require('plenary.filetype')

local has_ts, _ = pcall(require, 'nvim-treesitter')
local _, ts_highlight = pcall(require, 'nvim-treesitter.highlight')
local _, ts_parsers = pcall(require, 'nvim-treesitter.parsers')

local buf_delete = utils.buf_delete

local defaulter = utils.make_default_callable

local previewers = {}

local previewer_ns = vim.api.nvim_create_namespace('telescope.previewers')

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

previewers.cat = defaulter(function(_)
  return previewers.new_buffer_previewer {
    get_buffer_by_name = function(_, entry)
      return from_entry.path(entry, true)
    end,

    define_preview = function(self, entry, status)
      putils.with_preview_window(status, nil, function()
        local p = from_entry.path(entry, true)
        if p == nil or p == '' then return end
        file_maker_async(p, self.state.bufnr, self.state.bufname)
      end)
    end
  }
end, {})

previewers.vimgrep = defaulter(function(_)
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
      putils.with_preview_window(status, nil, function()
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

previewers.qflist = previewers.vimgrep

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
      putils.with_preview_window(status, nil, function()
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
      putils.with_preview_window(status, nil, function()
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
      putils.with_preview_window(status, nil, function()
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
      putils.with_preview_window(status, nil, function()
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
      putils.with_preview_window(status, nil, function()
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
      putils.with_preview_window(status, nil, function()
        assert(type(entry.preview_command) == 'function',
               'entry must provide a preview_command function which will put the content into the buffer')
        entry.preview_command(entry, self.state.bufnr)
      end)
    end
  }
end, {})

return previewers
