local ts_utils = require "telescope.utils"
local strings = require "plenary.strings"
local conf = require("telescope.config").values

local Job = require "plenary.job"
local Path = require "plenary.path"

local utils = {}

local detect_from_shebang = function(p)
  local s = p:readbyterange(0, 256)
  if s then
    local lines = vim.split(s, "\n")
    return vim.filetype.match { contents = lines }
  end
end

local parse_modeline = function(tail)
  if tail:find "vim:" then
    return tail:match ".*:ft=([^: ]*):.*$" or ""
  end
end

local detect_from_modeline = function(p)
  local s = p:readbyterange(-256, 256)
  if s then
    local lines = vim.split(s, "\n")
    local idx = lines[#lines] ~= "" and #lines or #lines - 1
    if idx >= 1 then
      return parse_modeline(lines[idx])
    end
  end
end

utils.filetype_detect = function(filepath)
  if type(filepath) ~= string then
    filepath = tostring(filepath)
  end

  local match = vim.filetype.match { filename = filepath }
  if match and match ~= "" then
    return match
  end

  local p = Path:new(filepath)
  if p and p:is_file() then
    match = detect_from_shebang(p)
    if match and match ~= "" then
      return match
    end

    match = detect_from_modeline(p)
    if match and match ~= "" then
      return match
    end
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
    local writer = (function()
      if opts.writer ~= nil then
        local wcommand = table.remove(opts.writer, 1)
        return Job:new {
          command = wcommand,
          args = opts.writer,
          env = opts.env,
          cwd = opts.cwd,
        }
      end
    end)()

    Job:new({
      command = command,
      args = cmd,
      env = opts.env,
      cwd = opts.cwd,
      writer = writer,
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
    }):start()
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
utils.highlighter = function(bufnr, ft, opts)
  opts = vim.F.if_nil(opts, {})
  opts.preview = vim.F.if_nil(opts.preview, {})
  opts.preview.treesitter = (function()
    if type(opts.preview) == "table" and opts.preview.treesitter then
      return opts.preview.treesitter
    end
    if type(conf.preview) == "table" and conf.preview.treesitter then
      return conf.preview.treesitter
    end
    if type(conf.preview) == "boolean" then
      return conf.preview
    end
    -- We should never get here
    return false
  end)()

  if type(opts.preview.treesitter) == "boolean" then
    local temp = { enable = opts.preview.treesitter }
    opts.preview.treesitter = temp
  end

  local ts_highlighting = (function()
    if type(opts.preview.treesitter.enable) == "table" then
      if vim.tbl_contains(opts.preview.treesitter.enable, ft) then
        return true
      end
      return false
    end

    if vim.tbl_contains(vim.F.if_nil(opts.preview.treesitter.disable, {}), ft) then
      return false
    end

    return opts.preview.treesitter.enable == nil or opts.preview.treesitter.enable == true
  end)()

  local ts_success
  if ts_highlighting then
    ts_success = utils.ts_highlighter(bufnr, ft)
  end
  if not ts_highlighting or ts_success == false then
    utils.regex_highlighter(bufnr, ft)
  end
end

--- Attach regex highlighter
utils.regex_highlighter = function(bufnr, ft)
  if has_filetype(ft) then
    return pcall(vim.api.nvim_buf_set_option, bufnr, "syntax", ft)
  end
  return false
end

-- Attach ts highlighter
utils.ts_highlighter = function(bufnr, ft)
  if has_filetype(ft) then
    local lang = vim.treesitter.language.get_lang(ft) or ft
    if lang and ts_utils.has_ts_parser(lang) then
      return vim.treesitter.start(bufnr, lang)
    end
  end
  return false
end

utils.set_preview_message = function(bufnr, winid, message, fillchar)
  fillchar = vim.F.if_nil(fillchar, "╱")
  local height = vim.api.nvim_win_get_height(winid)
  local width = vim.api.nvim_win_get_width(winid)
  vim.api.nvim_buf_set_lines(
    bufnr,
    0,
    -1,
    false,
    ts_utils.repeated_table(height, table.concat(ts_utils.repeated_table(width, fillchar), ""))
  )
  local anon_ns = vim.api.nvim_create_namespace ""
  local padding = table.concat(ts_utils.repeated_table(#message + 4, " "), "")
  local lines = {
    padding,
    "  " .. message .. "  ",
    padding,
  }
  vim.api.nvim_buf_set_extmark(
    bufnr,
    anon_ns,
    0,
    0,
    { end_line = height, hl_group = "TelescopePreviewMessageFillchar" }
  )
  local col = math.floor((width - strings.strdisplaywidth(lines[2])) / 2)
  for i, line in ipairs(lines) do
    vim.api.nvim_buf_set_extmark(
      bufnr,
      anon_ns,
      math.floor(height / 2) - 1 + i,
      0,
      { virt_text = { { line, "TelescopePreviewMessage" } }, virt_text_pos = "overlay", virt_text_win_col = col }
    )
  end
end

return utils
