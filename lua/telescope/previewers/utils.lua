local context_manager = require('plenary.context_manager')

local has_ts, _ = pcall(require, 'nvim-treesitter')
local _, ts_highlight = pcall(require, 'nvim-treesitter.highlight')
local _, ts_parsers = pcall(require, 'nvim-treesitter.parsers')

local Job = require('plenary.job')

local utils = {}

utils.with_preview_window = function(status, bufnr, callable)
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

-- API helper functions for buffer previewer
--- Job maker for buffer previewer
utils.job_maker = function(cmd, bufnr, opts)
  opts = opts or {}
  opts.mode = opts.mode or "insert"
  -- bufname and value are optional
  -- if passed, they will be use as the cache key
  -- if any of them are missing, cache will be skipped
  if opts.bufname ~= opts.value or not opts.bufname or not opts.value then
    local command = table.remove(cmd, 1)
    Job:new({
      command = command,
      args = cmd,
      env = opts.env,
      on_exit = vim.schedule_wrap(function(j)
        if not vim.api.nvim_buf_is_valid(bufnr) then return end
        if opts.mode == "append" then
          local count = vim.api.nvim_buf_line_count(bufnr)
          vim.api.nvim_buf_set_lines(bufnr, count, -1, false, j:result())
        elseif opts.mode == "insert" then
          vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, j:result())
        end
        if opts.callback then opts.callback(bufnr, j:result()) end
      end)
    }):start()
  else
    if opts.callback then opts.callback(bufnr) end
  end
end

local function has_filetype(ft)
    return ft and ft ~= ''
end

--- Attach default highlighter which will choose between regex and ts
utils.highlighter = function(bufnr, ft)
  if not(utils.ts_highlighter(bufnr, ft)) then
    utils.regex_highlighter(bufnr, ft)
  end
end

--- Attach regex highlighter
utils.regex_highlighter = function(_, ft)
  if has_filetype(ft) then
    vim.cmd(':ownsyntax ' .. ft)
    return true
  end
  return false
end

-- Attach ts highlighter
utils.ts_highlighter = function(bufnr, ft)
  if has_ts and has_filetype(ft) then
    local lang = ts_parsers.ft_to_lang(ft);
    if ts_parsers.has_parser(lang) then
      ts_highlight.attach(bufnr, lang)
      return true
    end
  end
  return false
end

return utils
