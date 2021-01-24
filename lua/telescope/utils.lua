local pathlib = require('telescope.path')
local Job     = require('plenary.job')

local utils = {}

utils.get_separator = function()
  return pathlib.separator
end

utils.if_nil = function(x, was_nil, was_not_nil)
  if x == nil then
    return was_nil
  else
    return was_not_nil
  end
end

utils.get_default = function(x, default)
  return utils.if_nil(x, default, x)
end

utils.get_lazy_default = function(x, defaulter, ...)
  if x == nil then
    return defaulter(...)
  else
    return x
  end
end

local function reversedipairsiter(t, i)
  i = i - 1
  if i ~= 0 then
    return i, t[i]
  end
end

utils.reversed_ipairs = function(t)
  return reversedipairsiter, t, #t + 1
end

utils.default_table_mt = {
  __index = function(t, k)
    local obj = {}
    rawset(t, k, obj)
    return obj
  end
}

utils.repeated_table = function(n, val)
  local empty_lines = {}
  for _ = 1, n do
    table.insert(empty_lines, val)
  end
  return empty_lines
end

utils.quickfix_items_to_entries = function(locations)
  local results = {}

  for _, entry in ipairs(locations) do
    local vimgrep_str = entry.vimgrep_str or string.format(
      "%s:%s:%s: %s",
      vim.fn.fnamemodify(entry.display_filename or entry.filename, ":."),
      entry.lnum,
      entry.col,
      entry.text
    )

    table.insert(results, {
      valid = true,
      value = entry,
      ordinal = vimgrep_str,
      display = vimgrep_str,

      start = entry.start,
      finish = entry.finish,
    })
  end

  return results
end

-- TODO: Figure out how to do this... could include in plenary :)
-- NOTE: Don't use this yet. It will segfault sometimes.
--
-- opts.shorten_path and function(value)
--     local result = {
--       valid = true,
--       display = utils.path_shorten(value),
--       ordinal = value,
--       value = value
--     }

--     return result
--   end or nil)
utils.path_shorten = pathlib.shorten

utils.path_tail = (function()
  local os_sep = utils.get_separator()
  local match_string = '[^' .. os_sep .. ']*$'

  return function(path)
    return string.match(path, match_string)
  end
end)()

-- local x = utils.make_default_callable(function(opts)
--   return function()
--     print(opts.example, opts.another)
--   end
-- end, { example = 7, another = 5 })

-- x()
-- x.new { example = 3 }()
function utils.make_default_callable(f, default_opts)
  default_opts = default_opts or {}

  return setmetatable({
    new = function(opts)
      opts = vim.tbl_extend("keep", opts, default_opts)
      return f(opts)
    end,
  }, {
    __call = function()
      local ok, err = pcall(f(default_opts))
      if not ok then
        error(debug.traceback(err))
      end
    end
  })
end

function utils.job_is_running(job_id)
  if job_id == nil then return false end
  return vim.fn.jobwait({job_id}, 0)[1] == -1
end

function utils.buf_delete(bufnr)
  if bufnr == nil then return end

  -- Suppress the buffer deleted message for those with &report<2
  local start_report = vim.o.report
  if start_report < 2 then vim.o.report = 2 end

  if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
    vim.api.nvim_buf_delete(bufnr, { force = true })
  end

  if start_report < 2 then vim.o.report = start_report end
end

function utils.max_split(s, pattern, maxsplit)
  pattern = pattern or ' '
  maxsplit = maxsplit or -1

  local t = {}

  local curpos = 0
  while maxsplit ~= 0 and curpos < #s do
    local found, final = string.find(s, pattern, curpos, false)
    if found ~= nil then
      local val = string.sub(s, curpos, found - 1)

      if #val > 0 then
        maxsplit = maxsplit - 1
        table.insert(t, val)
      end

      curpos = final + 1
    else
      table.insert(t, string.sub(s, curpos))
      break
      -- curpos = curpos + 1
    end

    if maxsplit == 0 then
      table.insert(t, string.sub(s, curpos))
    end
  end

  return t
end


function utils.data_directory()
  local sourced_file = require('plenary.debug_utils').sourced_filepath()
  local base_directory = vim.fn.fnamemodify(sourced_file, ":h:h:h")

  return base_directory .. pathlib.separator .. 'data' .. pathlib.separator
end

function utils.display_termcodes(str)
  return str:gsub(string.char(9), "<TAB>"):gsub("", "<C-F>"):gsub(" ", "<Space>")
end

function utils.get_os_command_output(cmd)
  if type(cmd) ~= "table" then
    print('Telescope: [get_os_command_output]: cmd has to be a table')
    return {}
  end
  local command = table.remove(cmd, 1)
  return Job:new({ command = command, args = cmd }):sync()
end

local uv = vim.loop
local co = coroutine

local Executor = {}
Executor.__index = Executor

function Executor.new(opts)
  opts = opts or {}

  local self = setmetatable({}, Executor)

  self.tasks = opts.tasks or {}
  self.mode = opts.mode or "next"
  self.index = opts.start_idx or 1
  self.idle = uv.new_idle()

  return self
end

function Executor:run()
  self.idle:start(vim.schedule_wrap(function()
    if #self.tasks == 0 then
      self.idle:stop()
      return
    end

    if self.mode == "finish" then
      self:step_finish()
    else
      self:step()
    end
  end))
end

function Executor:close()
  self.idle:stop()
  self.tasks = {}
end

function Executor:step_finish()
  if #self.tasks == 0 then return end
  local curr_task = self.tasks[self.index]
  if curr_task == nil then
    self.index = 1
    curr_task = self.tasks[self.index]
  end

  local _, _ = co.resume(curr_task)
  if co.status(curr_task) == "dead" then
    table.remove(self.tasks, self.index)

    self.index = self.index + 1
  end
end

function Executor:step()
  if #self.tasks == 0 then return end
  local curr_task = self.tasks[self.index]
  if curr_task == nil then
    self.index = 1
    curr_task = self.tasks[self.index]
  end

  local _, _ = co.resume(curr_task[1], unpack(curr_task[2]))
  if co.status(curr_task[1]) == "dead" then
    table.remove(self.tasks, self.index)
  end

  self.index = self.index + 1
end

function Executor:get_current_task()
  return self.tasks[self.index]
end

function Executor:remove_task(idx)
  table.remove(self.tasks, idx)
end

function Executor:add(task, ...)
  table.insert(self.tasks, {task, {...}})
end

utils.Executor = Executor

List = {}

function List.new()
  return {first = 0, last = -1}
end

function List.pushleft(list, value)
  local first = list.first - 1
  list.first = first
  list[first] = value
end

function List.pushright (list, value)
  local last = list.last + 1
  list.last = last
  list[last] = value
end

function List.popleft (list)
  local first = list.first
  if first > list.last then return nil end
  local value = list[first]
  list[first] = nil        -- to allow garbage collection
  list.first = first + 1
  return value
end

function List.is_empty(list)
  return list.first > list.last
end

function List.popright (list)
  local last = list.last
  if list.first > last then return nil end
  local value = list[last]
  list[last] = nil         -- to allow garbage collection
  list.last = last - 1
  return value
end

function List.len(list)
  return list.last - list.first
end

utils.List = List

function successive_async(f)
  local list = List.new()

  local function wrapped(...)
    if list == nil then return end
    -- if List.is_empty(list) or list == nil then return end

    List.pushleft(list, {...})
    local curr = List.popright(list)
    f(unpack(curr))
  end

  local function finish()
    list = nil 
  end

  return wrapped
end

return utils
