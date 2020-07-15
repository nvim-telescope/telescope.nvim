local a = vim.api

local finders = {}

local Finder = {}
Finder.__index = Finder

--- Create a new finder command
---
--@param fn_command function The function to call
function Finder:new(opts)
  opts = opts or {}

  -- TODO: Add config for:
  --        - cwd

  -- TODO:
  -- - `types`
  --    job
  --    pipe
  --        vim.loop.new_pipe (stdin / stdout). stdout => filter pipe
  --        rg huge_search | fzf --filter prompt_is > buffer. buffer could do stuff do w/ preview callback
  --    string
  --    list
  --    ...
  return setmetatable({
    fn_command = opts.fn_command,
    responsive = opts.responsive,
    job_id = -1,
  }, Finder)
end

function Finder:get_results(win, bufnr, prompt)
  if self.job_id > 0 then
    -- Make sure we kill old jobs.
    vim.fn.jobstop(self.job_id)
  end

  self.job_id = vim.fn.jobstart(self.fn_command(prompt), {
    -- TODO: Decide if we want this or don't want this.
    stdout_buffered = true,

    on_stdout = function(_, data, _)
      a.nvim_buf_set_lines(bufnr, -1, -1, false, data)
    end,

    on_exit = function()
      -- TODO: Add possibility to easily highlight prompt within buffer
      -- without having to do weird stuff and with it actually working...
      if false then
        vim.fn.matchadd("Type", "\\<" .. prompt .. "\\>", 1, -1, {window = win})
      end
    end,
  })

  --[[
  local function get_rg_results(bufnr, search_string)
    local start_time = vim.fn.reltime()

    vim.fn.jobstart(string.format('rg %s', search_string), {
      cwd = '/home/tj/build/neovim',

      on_stdout = function(job_id, data, event)
        vim.api.nvim_buf_set_lines(bufnr, -1, -1, false, data)
      end,

      on_exit = function()
        print("Finished in: ", vim.fn.reltimestr(vim.fn.reltime(start_time)))
      end,

      stdout_buffer = true,
    })
  end
  --]]
end

--- Return a new Finder
--
--@return Finder
finders.new = function(...)
  return Finder:new(...)
end

return finders
