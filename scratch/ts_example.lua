local uv = vim.loop

local has_ts, _ = pcall(require, 'nvim-treesitter')
if not has_ts then
  error("ASKDLFJAKLSJFLASKDFJ")
end

local ts_highlight = require('nvim-treesitter.highlight')
local ts_parsers = require('nvim-treesitter.parsers')

local function readFile(path, callback)
  uv.fs_open(path, "r", 438, function(err, fd)
    assert(not err, err)
    uv.fs_fstat(fd, function(err, stat)
      assert(not err, err)
      uv.fs_read(fd, stat.size, 0, function(err, data)
        assert(not err, err)
        uv.fs_close(fd, function(err)
          assert(not err, err)
          return callback(data)
        end)
      end)
    end)
  end)
end

local determine_filetype = function(filepath)
  -- Obviously TODO
  return "lua"
end

local filepath = "lua/telescope/init.lua"

local load_ts_buffer = function(bufnr, filepath)
  local filetype = determine_filetype(filepath)
  if not ts_parsers.has_parser(filetype) then
    error("TODO CONNI")
  end

  readFile(filepath, vim.schedule_wrap(function(data)
    if not vim.api.nvim_buf_is_valid(bufnr) then
      return
    end

    -- pcall(ts_highlight.detach, bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(data, "\n"))
    ts_highlight.attach(bufnr, filetype)
  end))
end

load_ts_buffer(3, filepath)
