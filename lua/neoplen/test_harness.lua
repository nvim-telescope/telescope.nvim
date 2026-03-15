local Path = require "neoplen.path"
local Job = require "neoplen.job"

local log = require "neoplen.log"

local plenary_dir = vim.fn.fnamemodify(debug.getinfo(1).source:match "@?(.*[/\\])", ":p:h:h:h")

local harness = {}

local print_output = vim.schedule_wrap(function(_, ...)
  for _, v in ipairs { ... } do
    io.stdout:write(tostring(v))
    io.stdout:write "\n"
  end

  vim.cmd [[mode]]
end)

local function test_paths(paths, opts)
  local minimal = not opts or not opts.init or opts.minimal or opts.minimal_init

  opts = vim.tbl_deep_extend("force", {
    nvim_cmd = vim.v.progpath,
    winopts = { winblend = 3 },
    sequential = false,
    keep_going = true,
    timeout = 50000,
  }, opts or {})

  vim.env.PLENARY_TEST_TIMEOUT = opts.timeout

  local res = {}

  local outputter = print_output

  local path_len = #paths
  local failure = false

  local jobs = vim.tbl_map(function(p)
    local args = {
      "--headless",
      "-c",
      "set rtp+=.," .. vim.fn.escape(plenary_dir, " "),
    }

    if minimal then
      table.insert(args, "--noplugin")
      if opts.minimal_init then
        table.insert(args, "-u")
        table.insert(args, opts.minimal_init)
      end
    elseif opts.init ~= nil then
      table.insert(args, "-u")
      table.insert(args, opts.init)
    end

    table.insert(args, "-c")
    table.insert(args, string.format('lua require("neoplen.busted").run("%s")', p:absolute():gsub("\\", "\\\\")))

    local job = Job:new {
      command = opts.nvim_cmd,
      args = args,

      -- Can be turned on to debug
      on_stdout = function(_, data)
        if path_len == 1 then
          outputter(res.bufnr, data)
        end
      end,

      on_stderr = function(_, data)
        if path_len == 1 then
          outputter(res.bufnr, data)
        end
      end,

      on_exit = vim.schedule_wrap(function(j_self, _, _)
        if path_len ~= 1 then
          outputter(res.bufnr, unpack(j_self:stderr_result()))
          outputter(res.bufnr, unpack(j_self:result()))
        end

        vim.cmd "mode"
      end),
    }
    job.nvim_busted_path = p.filename
    return job
  end, paths)

  log.debug "Running..."
  for i, j in ipairs(jobs) do
    outputter(res.bufnr, "Scheduling: " .. j.nvim_busted_path)
    j:start()
    if opts.sequential then
      log.debug("... Sequential wait for job number", i)
      if not Job.join(j, opts.timeout) then
        log.debug("... Timed out job number", i)
        failure = true
        pcall(function()
          j.handle:kill(15) -- SIGTERM
        end)
      else
        log.debug("... Completed job number", i, j.code, j.signal)
        failure = failure or j.code ~= 0 or j.signal ~= 0
      end
      if failure and not opts.keep_going then
        break
      end
    end
  end

  if not opts.sequential then
    table.insert(jobs, opts.timeout)
    log.debug "... Parallel wait"
    Job.join(unpack(jobs))
    log.debug "... Completed jobs"
    table.remove(jobs, #jobs)
    failure = vim.iter(jobs):any(function(v)
      return v.code ~= 0
    end)
  end
  vim.wait(100)

  if failure then
    return vim.cmd "1cq"
  end

  return vim.cmd "0cq"
end

function harness.test_directory(directory, opts)
  print "Starting..."
  directory = directory:gsub("\\", "/")
  local paths = harness._find_files_to_run(directory)

  -- Paths work strangely on Windows, so lets have abs paths
  if vim.fn.has "win32" == 1 or vim.fn.has "win64" == 1 then
    paths = vim.tbl_map(function(p)
      return Path:new(directory, p.filename)
    end, paths)
  end

  test_paths(paths, opts)
end

function harness.test_file(filepath)
  test_paths { Path:new(filepath) }
end

function harness._find_files_to_run(directory)
  local finder
  if vim.fn.has "win32" == 1 or vim.fn.has "win64" == 1 then
    -- On windows use powershell Get-ChildItem instead
    local cmd = vim.fn.executable "pwsh.exe" == 1 and "pwsh" or "powershell"
    finder = Job:new {
      command = cmd,
      args = { "-NoProfile", "-Command", [[Get-ChildItem -Recurse -n -Filter "*_spec.lua"]] },
      cwd = directory,
    }
  else
    -- everywhere else use find
    finder = Job:new {
      command = "find",
      args = { directory, "-type", "f", "-name", "*_spec.lua" },
    }
  end

  return vim.tbl_map(Path.new, finder:sync(vim.env.PLENARY_TEST_TIMEOUT))
end

function harness._run_path(test_type, directory)
  local paths = harness._find_files_to_run(directory)

  local bufnr = 0
  local win_id = 0

  for _, p in pairs(paths) do
    print " "
    print("Loading Tests For: ", p:absolute(), "\n")

    local ok, _ = pcall(function()
      dofile(p:absolute())
    end)

    if not ok then
      print "Failed to load file"
    end
  end

  harness:run(test_type, bufnr, win_id)
  vim.cmd "qa!"

  return paths
end

return harness
