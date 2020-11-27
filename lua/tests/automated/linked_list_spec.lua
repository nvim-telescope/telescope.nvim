require('plenary.test_harness'):setup_busted()

local LinkedList = require('telescope.algos.linked_list')

describe('LinkedList', function()
  it('can create a list', function()
    local l = LinkedList:new()

    assert.are.same(0, l.size)
  end)

  it('can add a single entry to the list', function()
    local l = LinkedList:new()
    l:append('hello')

    assert.are.same(1, l.size)
  end)

  it('can iterate over one item', function()
    local l = LinkedList:new()
    l:append('hello')

    for val in l:iter() do
      assert.are.same('hello', val)
    end
  end)

  it('iterates in order', function()
    local l = LinkedList:new()
    l:append('hello')
    l:append('world')

    local x = {}
    for val in l:iter() do
      table.insert(x, val)
    end

    assert.are.same({'hello', 'world'}, x)
  end)
end)
