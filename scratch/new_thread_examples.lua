local uv = vim.loop

-- local pipe_to_share = uv.new_pipe(false)
-- https://github.com/luvit/luv/blob/master/docs.md#uvwrite2stream-data-send_handle-callback

-- Requirements:
--  I only want to import the sorter ONCE (don't reload a million times)
--  I want to run a callback when we're done.
--  I want to be able to re-use sorters in the background
--  I don't want the thread to busy wait
--  I don't wnat a lot of overhead of sending tons of data back and forth between procs.

local pipe = uv.new_pipe(false)
local socket_name = '/tmp/sock.test_3'

pipe:bind(socket_name)
pipe:read_start(function(...)
  print('we readin from this pipe')
  print(...)
end)

local other_pipe = uv.pipe_open(pipe)

print(uv.pipe_getsockname(pipe))

pipe:listen(128, function()
  local client = uv.new_pipe(false)
  pipe:accept(client)

  client:write("hello!\n")
  client:close()
end)

other_pipe:write("other pipe!\n")

pipe:close()
