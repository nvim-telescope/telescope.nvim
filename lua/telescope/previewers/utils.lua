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
utils.job_maker = function(cmd, env, value, bufnr, bufname, callback)
  if bufname ~= value then
    local command = table.remove(cmd, 1)
    Job:new({
      command = command,
      args = cmd,
      env = env,
      on_exit = vim.schedule_wrap(function(j)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, j:result())
        if callback then callback(bufnr, j:result()) end
      end)
    }):start()
  else
    if callback then callback(bufnr) end
  end
end

--- Attach default highlighter which will choose between regex and ts
utils.highlighter = function(bufnr, ft)
  if ft and ft ~= '' then
    if has_ts and ts_parsers.has_parser(ft) then
      ts_highlight.attach(bufnr, ft)
    else
      vim.cmd(':ownsyntax ' .. ft)
    end
  end
end

--- Attach regex highlighter
utils.regex_highlighter = function(_, ft)
  if ft and ft ~= '' then
    vim.cmd(':ownsyntax ' .. ft)
  end
end

-- Attach ts highlighter
utils.ts_highlighter = function(bufnr, ft)
  if ft and ft ~= '' then
    if has_ts and ts_parsers.has_parser(ft) then
      ts_highlight.attach(bufnr, ft)
    end
  end
end

return utils
