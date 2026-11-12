local api = vim.api

local utils = require "telescope.utils"
local conf = require("telescope.config").values

local M = {}

M.filetype_detect = function(filepath)
  return vim.filetype.match { filename = filepath }
end

-- API helper functions for buffer previewer
--- Job maker for buffer previewer
M.job_maker = function(cmd, bufnr, opts)
  opts = opts or {}
  opts.mode = opts.mode or "insert"
  -- bufname and value are optional
  -- if passed, they will be use as the cache key
  -- if any of them are missing, cache will be skipped
  if opts.bufname ~= opts.value or not opts.bufname or not opts.value then
    -- `env` is added to the environment (`vim.system` default)
    vim.system(
      cmd,
      { cwd = opts.cwd, env = opts.env },
      vim.schedule_wrap(function(result)
        if not api.nvim_buf_is_valid(bufnr) then
          return
        end
        local stdout = result.stdout
        -- remove overstrike (`X\bX` bold, `_\bX` underline), e.g. from `man`
        if stdout:find("\b", 1, true) then
          stdout = stdout:gsub("[^\128-\191][\128-\191]*\b", "")
        end
        local lines = utils.output_lines(stdout)
        if opts.mode == "append" then
          api.nvim_buf_set_lines(bufnr, -1, -1, false, lines)
        elseif opts.mode == "insert" then
          api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        end
        if opts.callback then
          opts.callback(bufnr, lines)
        end
      end)
    )
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
M.highlighter = function(bufnr, ft, opts)
  local preview = opts and opts.preview
  local treesitter = type(preview) == "table" and preview.treesitter
    or type(conf.preview) == "table" and conf.preview.treesitter
    or type(conf.preview) == "boolean" and conf.preview
    or false
  if type(treesitter) == "boolean" then
    treesitter = { enable = treesitter }
  end

  local ts_highlighting
  if type(treesitter.enable) == "table" then
    ts_highlighting = vim.tbl_contains(treesitter.enable, ft)
  else
    ts_highlighting = not vim.tbl_contains(treesitter.disable or {}, ft)
      and (treesitter.enable == nil or treesitter.enable == true)
  end

  if not ts_highlighting or M.ts_highlighter(bufnr, ft) == false then
    M.regex_highlighter(bufnr, ft)
  end
end

--- Attach regex highlighter
M.regex_highlighter = function(bufnr, ft)
  if has_filetype(ft) then
    return pcall(api.nvim_set_option_value, "syntax", ft, { buf = bufnr })
  end
  return false
end

-- Attach ts highlighter
M.ts_highlighter = function(bufnr, ft)
  if has_filetype(ft) then
    local lang = vim.treesitter.language.get_lang(ft)
    if lang and vim.treesitter.language.add(lang) then
      return vim.treesitter.start(bufnr, lang)
    end
  end
  return false
end

M.set_preview_message = function(bufnr, winid, message, fillchar)
  fillchar = vim.nonnil(fillchar, "╱")
  local height = api.nvim_win_get_height(winid)
  local width = api.nvim_win_get_width(winid)
  api.nvim_buf_set_lines(bufnr, 0, -1, false, utils.repeated_table(height, string.rep(fillchar, width)))
  local ns = api.nvim_create_namespace "telescope_preview_message"
  api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  local padding = string.rep(" ", #message + 4)
  local formatted_message = "  " .. message .. "  "
  -- Populate lines table based on height
  local lines = {}
  if height == 1 then
    lines[1] = formatted_message
  else
    for i = 1, math.min(height, 3), 1 do
      if i % 2 == 0 then
        lines[i] = formatted_message
      else
        lines[i] = padding
      end
    end
  end
  api.nvim_buf_set_extmark(bufnr, ns, 0, 0, { end_line = height, hl_group = "TelescopePreviewMessageFillchar" })
  local col = math.floor((width - vim.fn.strdisplaywidth(formatted_message)) / 2)
  for i, line in ipairs(lines) do
    local line_pos = math.floor(height / 2) - 2 + i
    api.nvim_buf_set_extmark(
      bufnr,
      ns,
      math.max(line_pos, 0),
      0,
      { virt_text = { { line, "TelescopePreviewMessage" } }, virt_text_pos = "overlay", virt_text_win_col = col }
    )
  end
end

--- Check if mime type is binary.
--- NOT an exhaustive check, may get false negatives. Ideally should check
--- filetype with `vim.filetype.match` or `filetype_detect` first for filetype
--- info.
---@param mime_type string
---@return boolean
M.binary_mime_type = function(mime_type)
  local type_, subtype = unpack(vim.split(mime_type, "/"))
  if vim.tbl_contains({ "text", "inode" }, type_) then
    return false
  end
  if vim.tbl_contains({ "json", "javascript" }, subtype) then
    return false
  end
  return true
end

local CHECK_TIME_INTERVAL = 200

--- Split a string into lines, checking every `CHECK_TIME_INTERVAL` characters
--- whether to timeout.
---
--- Roughly 4-5x faster than using `vim.gsplit` and checking timeout between each line.
--- The latter approach is also more prone to exceeding timeout if a file has huge lines.
---@param s string file content to split into lines
---@param opts {start_time: number, preview: { timeout: number }, file_encoding: string?}
---@return string[]?
function M.timed_split_lines(s, opts)
  local lines = {}
  local line_start = 1
  local timeout = opts.preview.timeout or math.huge

  for i = 1, #s do
    local ch = s:byte(i)
    if ch == 10 then
      local line
      if s:byte(i - 1) ~= 13 then
        line = s:sub(line_start, i - 1)
      else
        line = s:sub(line_start, i - 2)
      end
      line_start = i + 1
      table.insert(lines, opts.file_encoding and vim.iconv(line, opts.file_encoding, "utf8") or line)
    end

    if i % CHECK_TIME_INTERVAL == 0 then
      local diff_time = (vim.uv.hrtime() - opts.start_time) / 1e6
      if diff_time > timeout then
        return
      end
    end
  end

  -- Only append the tail when it is non-empty.
  -- neovim treats \n and \r\n as "line terminators" instead of "line separator"
  local tail = s:sub(line_start)
  if tail ~= "" then
    table.insert(lines, opts.file_encoding and vim.iconv(tail, opts.file_encoding, "utf8") or tail)
  end

  return lines
end

return M
