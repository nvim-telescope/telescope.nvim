local has_telescope, telescope = pcall(require, 'telescope')

if not has_telescope then
  error('This plugins requires nvim-telescope/telescope.nvim')
end

local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local action_set = require('telescope.actions.set')
local make_entry = require('telescope.make_entry')
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local sorters = require("telescope.sorters")
local conf = require("telescope.config").values

require('telescope').setup {}
local prev_working_prompt = ''
local get_str_matcher = function()
  return sorters.new {
    highlighter = function(_, prompt, display)
      local highlights = {}
      display = display:lower()
      local prompt_lua_style =  string.gsub(prompt,'\\', '%%') -- converts % to \ (lua to vim style regex)
      local hl_start, hl_end

      hl_start, hl_end = display:find(prompt_lua_style, 1, false)
      if hl_start then
        table.insert(highlights, {start = hl_start, finish = hl_end})
      end
      return highlights
    end,
    scoring_function = function(_, prompt, _, entry)
      local display = entry.ordinal:lower()
      local prompt_lua_style =  string.gsub(prompt,'\\', '%%') -- convert eg. \s to %s -lua readable format
      local run_ok, retval = pcall(string.find, display, prompt_lua_style, 1, false) --true -disables regex
      -- if display:find(prompt_lua_style, 1, false) then --true -disables regex
      if run_ok and retval then
        return entry.index
      else
        return -1
      end
    end
  }
end
-- copy pasted from tele/lua/builtin/files.lua
local current_buffer_regex_find = function(opts)
  -- All actions are on the current buffer
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.fn.expand(vim.api.nvim_buf_get_name(bufnr))
  local filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local lines_with_numbers = {}

  for lnum, line in ipairs(lines) do
    table.insert(lines_with_numbers, {
      lnum = lnum,
      bufnr = bufnr,
      filename = filename,
      text = line,
    })
  end

  local ok, parser = pcall(vim.treesitter.get_parser, bufnr, filetype)
  if ok then
    local query = vim.treesitter.get_query(filetype, "highlights")

    local root = parser:parse()[1]:root()

    local highlighter = vim.treesitter.highlighter.new(parser)
    local highlighter_query = highlighter:get_query(filetype)

    local line_highlights = setmetatable({}, {
      __index = function(t, k)
        local obj = {}
        rawset(t, k, obj)
        return obj
      end,
    })
    for id, node in query:iter_captures(root, bufnr, 0, -1) do
      local hl = highlighter_query.hl_cache[id]
      if hl then
        local row1, col1, row2, col2 = node:range()

        if row1 == row2 then
          local row = row1 + 1

          for index = col1, col2 do
            line_highlights[row][index] = hl
          end
        else
          local row = row1 + 1
          for index = col1, #lines[row] do
              line_highlights[row][index] = hl
          end

          while row < row2 + 1 do
            row = row + 1

            for index = 0, #lines[row] do
              line_highlights[row][index] = hl
            end
          end
        end
      end
    end

    opts.line_highlights = line_highlights
  end

  pickers.new(opts, {
    prompt_title = 'Search Current Buffer',
    finder = finders.new_table {
      results = lines_with_numbers,
      entry_maker = opts.entry_maker or make_entry.gen_from_buffer_lines(opts),
    },
    sorter = get_str_matcher(opts),
    previewer = conf.grep_previewer(opts),
    attach_mappings = function()
      action_set.select:enhance {
        post = function()
          local selection = action_state.get_selected_entry()
          vim.api.nvim_win_set_cursor(0, { selection.lnum, 0 })
        end,
      }

      return true
    end
  }):find()
end


return telescope.register_extension {exports = {buffer_search = current_buffer_regex_find}}
