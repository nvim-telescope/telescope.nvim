local uv = vim.loop

local pipe = uv.new_pipe(false)

pipe:bind('/tmp/sock.test_2')
pipe:read_start(function(...)
  print('we readin from this pipe')
  print(...)
end)
pipe:write("hello??")
