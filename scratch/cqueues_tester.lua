-- Actually works & runs
local cqueues = require "cqueues"
local uv = require "luv"

local cq = cqueues.new()

do
  local timer = uv.new_timer()
  local function reset_timer()
    local timeout = cq:timeout()
    if timeout then
      -- libuv takes milliseconds as an integer,
      -- while cqueues gives timeouts as a floating point number
      -- use `math.ceil` as we'd rather wake up late than early
      timer:set_repeat(math.ceil(timeout * 1000))
      timer:again()
    else
      -- stop timer for now; it may be restarted later.
      timer:stop()
    end
  end
  local function onready()
    -- Step the cqueues loop once (sleeping for max 0 seconds)
    assert(cq:step(0))
    reset_timer()
  end
  -- Need to call `start` on libuv timer now
  -- to provide callback and so that `again` works
  timer:start(0, 0, onready)
  -- Ask libuv to watch the cqueue pollfd
  uv.new_poll(cq:pollfd()):start(cq:events(), onready)
end

-- Adds a new function to the scheduler `cq`
-- The functions is an infinite loop that sleeps for 1 second and prints
cq:wrap(function()
  while true do
    cqueues.sleep(1)
    print("HELLO FROM CQUEUES")
  end
end)

-- Start a luv timer that fires every 1 second
uv.new_timer():start(1000, 1000, function()
  print("HELLO FROM LUV")
end)

-- Run luv mainloop
uv.run()
