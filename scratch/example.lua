
local finder = Finder:new {
  'rg %s -l',
  pipeable = true,
  ...
}

local filter = Filter:new {
  "fzf --filter '%s'"
}

local lua_filter = Filter:new {
  function(input, line)
    if string.match(line, input) then
      return true
    end

    return false
  end
}


local picker_read = Picker:new {
  filter = filter,

  previewer = function(window, buffer, line)
    local file = io.open(line, "r")

    local filename = vim.split(line, ':')[1]
    if vim.fn.bufexists(filename) then
      vim.api.nvim_win_set_buf(window, vim.fn.bufnr(filename))
      return
    end

    local lines = {}
    for _ = 1, 100 do
      table.insert(lines, file:read("l"))

      -- TODO: Check if we're out of lines
    end

    -- optionally set the filetype or whatever...
    vim.api.nvim_buf_set_lines(buffer, 0, -1, false, lines)
  end,

  mappings = {
    ["<CR>"] = function(line)
      vim.cmd(string.format('e ', vim.split(line, ':')))
    end,
  },
}

local picker = Picker:new {
  filter = filter,

  -- idk
  previewer = function(window, line)
    vim.api.nvim_win_set_current_window(window)

    -- if is_file_loaded(line) then
    --   lien_number = vim.api.nvim_...

    vim.fn.termopen(string.format(
      'bat --color=always --style=grid %s',
      vim.split(line, ':')[1]
    ))
  end
}
