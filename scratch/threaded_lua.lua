--[[

Some open questions:

1. Can I pass a function as a string and deserialize on the other side?
2. How expensive is said serialization?


--]]



local uv = vim.loop

ThreadsAvailable = {}

local work = vim.loop.new_work(function(path, prompt, line)
  package.path = path
  local had_to_load = false

  local uv = require('luv')
  if not fuzzy_sorter then
    had_to_load = true
    fuzzy_sorter = require('telescope.sorters').get_fuzzy_file()
  end

  -- return fuzzy_sorter:score(prompt, line), had_to_load, uv.hrtime(), tostring(uv.thread_self())
  return tostring(uv.thread_self())
end, function(thread_string)
  -- print(vim.inspect(vim.split(x, ';')))
  ThreadsAvailable[thread_string] = true
end)

work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")
work:queue(package.path, "hello", "hello world")


