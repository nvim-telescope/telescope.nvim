RELOAD "telescope"

local conf = require("telescope.config").values
local finders = require "telescope.finders"
local pickers = require "telescope.pickers"
local to_iter = require("plenary.iterators").iter

local a = require "plenary.async"

local read_file = function(path)
  return function()
    local err_open, fd = a.uv.fs_open(path, "r", 438)
    assert(not err_open, err_open)

    local err_stat, stat = a.uv.fs_fstat(fd)
    assert(not err_stat, err_stat)

    local err_read, data = a.uv.fs_read(fd, stat.size, 0)
    assert(not err_read, err_read)

    local err_close = a.uv.fs_close(fd)
    assert(not err_close, err_close)

    return to_iter(vim.split(data, "\n"))
  end
end

local picker = function(opts)
  opts = opts or {}

  pickers.new(opts, {
    prompt_title = "test",
    finder = finders.new_incremental {
      fn = read_file "README.md",
    },
    previewer = conf.qflist_previewer(opts),
    sorter = conf.generic_sorter(opts),
  }):find()
end

picker()
