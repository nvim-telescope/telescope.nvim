-- local opts = TelescopeLastGrep 

local opts = {
  command = "rg",
  args = { "--color=never", "--no-heading", "--with-filename", "--line-number", "--column", "--smart-case", "function M" }
}
local async = R('plenary.async')

local async_job = R('plenary.async_job')
local LinesPipe = R('plenary.async_job.pipes').LinesPipe

async.void(function()
  local iterations = 0
  local count = 12
  while count == 12 do
    iterations = iterations + 1
    if iterations > 1000 then
      print("no fails!")
      return
    end

    async.util.sleep(1)
    async.util.scheduler()
    async.util.sleep(1)
    vim.api.nvim_buf_set_lines(12, 0, -1, false, {})

    local stdout = LinesPipe()

    local job = async_job.spawn {
      command = opts.command,
      args = opts.args,
      cwd = opts.cwd or opts.cwd,
      -- writer = writer,

      stdout = stdout,
    }

    count = 0
    for _ in stdout:iter(true) do
      count = count + 1
    end

    -- local read = stdout:read()
    -- while read do
    --   print(read)
    --   read = stdout:read()
    -- end
  end

  print("Failed!")
end)()
