local EntryManager = require('telescope.entry_manager')

local eq = assert.are.same

describe('process_result', function()
  it('works with one entry', function()
    local manager = EntryManager:new(5, nil)

    manager:add_entry(nil, 1, "hello")

    assert.are.same(1, manager:get_score(1))
  end)

  it('works with two entries', function()
    local manager = EntryManager:new(5, nil)

    manager:add_entry(nil, 1, "hello")
    manager:add_entry(nil, 2, "later")

    assert.are.same("hello", manager:get_entry(1))
    assert.are.same("later", manager:get_entry(2))
  end)

  it('calls functions when inserting', function()
    local called_count = 0
    local manager = EntryManager:new(5, function() called_count = called_count + 1 end)

    assert(called_count == 0)
    manager:add_entry(nil, 1, "hello")
    assert(called_count == 1)
  end)

  it('calls functions when inserting twice', function()
    local called_count = 0
    local manager = EntryManager:new(5, function() called_count = called_count + 1 end)

    assert(called_count == 0)
    manager:add_entry(nil, 1, "hello")
    manager:add_entry(nil, 2, "world")
    assert(called_count == 2)
  end)

  it('correctly sorts lower scores', function()
    local called_count = 0
    local manager = EntryManager:new(5, function() called_count = called_count + 1 end)
    manager:add_entry(nil, 5, "worse result")
    manager:add_entry(nil, 2, "better result")

    assert.are.same("better result", manager:get_entry(1))
    assert.are.same("worse result", manager:get_entry(2))

    assert.are.same(2, called_count)
  end)

  it('respects max results', function()
    local called_count = 0
    local manager = EntryManager:new(1, function() called_count = called_count + 1 end)
    manager:add_entry(nil, 2, "better result")
    manager:add_entry(nil, 5, "worse result")

    assert.are.same("better result", manager:get_entry(1))
    assert.are.same(1, called_count)
    assert.are.same(2, manager.worst_acceptable_score)
  end)

  it('updates worst acceptable score if inserting a value', function()
    local called_count = 0
    local manager = EntryManager:new(1, function() called_count = called_count + 1 end)
    manager:add_entry(nil, 5, "worse result")
    manager:add_entry(nil, 2, "better result")

    -- Once for insert 5
    -- Once for prepend 2
    assert.are.same(2, called_count)

    assert.are.same("better result", manager:get_entry(1))
    assert.are.same(2, manager.worst_acceptable_score)
  end)

  it('should allow simple entries', function()
    local manager = EntryManager:new(5)

    local counts_executed = 0
    manager:add_entry(nil, 1, setmetatable({}, {
      __index = function(t, k)
        local val = nil
        if k == "ordinal" then
          counts_executed = counts_executed + 1

          -- This could be expensive, only call later
          val = "wow"
        end

        rawset(t, k, val)
        return val
      end,
    }))

    assert.are.same("wow", manager:get_ordinal(1))
    assert.are.same("wow", manager:get_ordinal(1))
    assert.are.same("wow", manager:get_ordinal(1))

    assert.are.same(1, counts_executed)
  end)

  it('should not loop a bunch', function()
    local info = {}
    local manager = EntryManager:new(5, nil, info)
    manager:add_entry(nil, 4, "better result")
    manager:add_entry(nil, 3, "better result")
    manager:add_entry(nil, 2, "better result")

    -- assert.are.same({}, info)
  end)

  it('should update worst acceptable score', function()
    local manager = EntryManager:new(2, nil)
    manager:add_entry(nil, 4, "result 4")
    manager:add_entry(nil, 3, "result 3")
    manager:add_entry(nil, 2, "result 2")

    assert.are.same(3, manager.worst_acceptable_score)
  end)
end)
