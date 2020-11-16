require('plenary.test_harness'):setup_busted()

local transform_mod = require('telescope.actions.mt').transform_mod

local eq = function(a, b)
  assert.are.same(a, b)
end

describe('actions', function()
  it('should allow creating custom actions', function()
    local a = transform_mod {
      x = function() return 5 end,
    }


    eq(5, a.x())
  end)

  it('allows adding actions', function()
    local a = transform_mod {
      x = function() return "x" end,
      y = function() return "y" end,
    }

    local x_plus_y = a.x + a.y

    eq({"x", "y"}, {x_plus_y()})
  end)

  it('ignores nils from added actions', function()
    local a = transform_mod {
      x = function() return "x" end,
      y = function() return "y" end,
      nil_maker = function() return nil end,
    }

    local x_plus_y = a.x + a.nil_maker + a.y

    eq({"x", "y"}, {x_plus_y()})
  end)

  it('allows overriding an action', function()
    local a = transform_mod {
      x = function() return "x" end,
      y = function() return "y" end,
    }

    -- actions.file_goto_selection_edit:replace(...)
    a.x:replace(function() return "foo" end)
    eq("foo", a.x())

    a._clear()
    eq("x", a.x())
  end)

  it('enhance.pre', function()
    local a = transform_mod {
      x = function() return "x" end,
      y = function() return "y" end,
    }

    local called_pre = false

    a.y:enhance {
      pre = function()
        called_pre = true
      end,
    }
    eq("y", a.y())
    eq(true, called_pre)
  end)

  it('enhance.post', function()
    local a = transform_mod {
      x = function() return "x" end,
      y = function() return "y" end,
    }

    local called_post = false

    a.y:enhance {
      post = function()
        called_post = true
      end,
    }
    eq("y", a.y())
    eq(true, called_post)
  end)

  it('can call both', function()
    local a = transform_mod {
      x = function() return "x" end,
      y = function() return "y" end,
    }

    local called_count = 0
    local count_inc = function()
      called_count = called_count + 1
    end

    a.y:enhance {
      pre = count_inc,
      post = count_inc,
    }

    eq("y", a.y())
    eq(2, called_count)
  end)

  it('can call both even when combined', function()
    local a = transform_mod {
      x = function() return "x" end,
      y = function() return "y" end,
    }

    local called_count = 0
    local count_inc = function()
      called_count = called_count + 1
    end

    a.y:enhance {
      pre = count_inc,
      post = count_inc,
    }

    a.x:enhance {
      post = count_inc
    }

    local x_plus_y = a.x + a.y
    x_plus_y()

    eq(3, called_count)
  end)

  it('clears enhance', function()
    local a = transform_mod {
      x = function() return "x" end,
      y = function() return "y" end,
    }

    local called_post = false

    a.y:enhance {
      post = function()
        called_post = true
      end,
    }

    a._clear()

    eq("y", a.y())
    eq(false, called_post)
  end)

  it('handles passing arguments', function()
    local a = transform_mod {
      x = function(bufnr) return string.format("bufnr: %s") end,
    }

    a.x:replace(function(bufnr) return string.format("modified: %s", bufnr) end)
    eq("modified: 5", a.x(5))
  end)
end)
