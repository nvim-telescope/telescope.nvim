local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local make_entry = require "telescope.make_entry"
local utils = require "telescope.utils"

local conf = require("telescope.config").values

local cscope = {}

local cscope_find = function(opts, type_num)
  local dir = opts.cwd
  local word = vim.F.if_nil(opts.search, vim.fn.expand "<cword>")
  -- local search = opts.use_regex and word or escape_chars(word)
  local search = word

  local output =
     utils.get_os_command_output({ "cscope", "-d", "-L", "-" .. tostring(type_num), search }, dir)

  if #output == 0 then
    utils.notify("builtin.cscope", {
      msg = "No results found. Need to build cscope database?",
      level = "ERROR",
    })
    return
  end

  local results = {}

  local parse_line = function (line)
    local fields = vim.split(line, " ")
    local index = #results + 1
    table.insert(results, index, fields[1]..":"..fields[3])
  end

  local i = 0
  for _, line in ipairs(output) do
    i = i + 1
    parse_line(line)
  end

  local type = {
    "find this C symbol ",
    "find this definition ",
    "find functions called by this function ",
    "find functions calling this function ",
  }

  -- By creating the entry maker after the cwd options,
  -- we ensure the maker uses the cwd options when being created.
  opts.entry_maker = vim.F.if_nil(opts.entry_maker, make_entry.gen_from_file(opts))

  pickers
    .new(opts, {
      prompt_title = "Cscope: " .. type[type_num + 1] .. "(" .. word .. ")",
      finder = finders.new_table {
        results = results,
        entry_maker = function(entry)
          local f = vim.split(entry, ":")

          return {
            value = entry,
            ordinal = entry,
            display = entry,
            path = dir..'/'..f[1],
            lnum = tonumber(f[2]),
          }
        end,
      },
      previewer = conf.grep_previewer(opts),
      sorter = conf.generic_sorter(opts)
    })
    :find()
end

cscope.references = function (opts)
  cscope_find(opts, 0)
end

cscope.definitions = function (opts)
  cscope_find(opts, 1)
end

cscope.called_by_this_function = function (opts)
  cscope_find(opts, 2)
end

cscope.calling_this_function = function (opts)
  cscope_find(opts, 3)
end

local set_opts_cwd = function(opts)
  if opts.cwd then
    opts.cwd = vim.fn.expand(opts.cwd)
  else
    opts.cwd = vim.loop.cwd()
  end
end

local function apply_checks(mod)
  for k, v in pairs(mod) do
    mod[k] = function(opts)
      opts = vim.F.if_nil(opts, {})

      set_opts_cwd(opts)
      v(opts)
    end
  end

  return mod
end

return apply_checks(cscope)
