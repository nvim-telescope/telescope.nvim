local p_selector = require('telescope.pickers.selector')

local eq = assert.are.same

describe('selector', function()
  describe('row', function()
    local p = p_selector.create('row')

    local default = 3
    local reset = 7
    it('should always pick selected, if passed', function()
      local selected = 5
      eq(selected, p {
        selected = selected,
        default = default,
        reset = reset,
      })
    end)

    it('should pick default if not selected', function()
      local selected = nil
      eq(default, p {
        selected = selected,
        default = default,
        reset = reset,
      })
    end)
  end)

  describe('reset', function()
    local p = p_selector.create('reset')

    local default = 3
    local reset = 7
    it('should never pick selected, even if passed', function()
      local selected = 5
      eq(reset, p {
        selected = selected,
        default = nil,
        reset = reset,
      })
    end)

    it('should never pick selected, even if passed', function()
      local selected = 5
      eq(default, p {
        selected = selected,
        default = default,
        reset = nil,
      })
    end)

    it('should pick default if passed selected', function()
      local selected = nil
      eq(default, p {
        selected = selected,
        default = default,
        reset = reset,
      })
    end)
  end)
end)
