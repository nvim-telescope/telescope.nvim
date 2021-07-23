local context_manager = require "plenary.context_manager"

local has_ts, _ = pcall(require, "nvim-treesitter")
local _, ts_configs = pcall(require, "nvim-treesitter.configs")
local _, ts_parsers = pcall(require, "nvim-treesitter.parsers")

local Job = require "plenary.job"

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
    Job
      :new({
        command = command,
        args = cmd,
        env = opts.env,
        cwd = opts.cwd,
        on_exit = vim.schedule_wrap(function(j)
          if not vim.api.nvim_buf_is_valid(bufnr) then
            return
          end
          if opts.mode == "append" then
            vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, j:result())
          elseif opts.mode == "insert" then
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, j:result())
          end
          if opts.callback then
            opts.callback(bufnr, j:result())
          end
        end),
      })
      :start()
  else
    if opts.callback then
      opts.callback(bufnr)
    end
  end
end

local function has_filetype(ft)
  return ft and ft ~= ""
end

--- Attach default highlighter which will choose between regex and ts
utils.highlighter = function(bufnr, ft)
  if not (utils.ts_highlighter(bufnr, ft)) then
    utils.regex_highlighter(bufnr, ft)
  end
end

--- Attach regex highlighter
utils.regex_highlighter = function(bufnr, ft)
  if has_filetype(ft) then
    vim.api.nvim_buf_set_option(bufnr, "syntax", ft)
    return true
  end
  return false
end

local treesitter_attach = function(bufnr, ft)
  local lang = ts_parsers.ft_to_lang(ft)
  if ts_parsers.has_parser(lang) then
    local config = ts_configs.get_module "highlight"
    if vim.tbl_contains(config.disable, lang) then
      return false
    end
    for k, v in pairs(config.custom_captures) do
      vim.treesitter.highlighter.hl_map[k] = v
    end
    vim.treesitter.highlighter.new(ts_parsers.get_parser(bufnr, lang))
    local is_table = type(config.additional_vim_regex_highlighting) == "table"
    if
      config.additional_vim_regex_highlighting
      and (not is_table or vim.tbl_contains(config.additional_vim_regex_highlighting, lang))
    then
      vim.api.nvim_buf_set_option(bufnr, "syntax", ft)
    end
    return true
  end
  return false
end

-- Attach ts highlighter
utils.ts_highlighter = function(bufnr, ft)
  if not has_ts then
    has_ts, _ = pcall(require, "nvim-treesitter")
    if has_ts then
      _, ts_configs = pcall(require, "nvim-treesitter.configs")
      _, ts_parsers = pcall(require, "nvim-treesitter.parsers")
    end
  end

  if has_ts and has_filetype(ft) then
    return treesitter_attach(bufnr, ft)
  end
  return false
end

return utils
