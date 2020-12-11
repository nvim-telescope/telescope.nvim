local p_scroller = require('telescope.pickers.scroller')

local eq = assert.are.same

describe('scroller', function()
  local max_results = 10

  describe('cycle', function()
    local cycle_scroller = p_scroller.create('cycle')

    it('should return values within the max results', function()
      eq(5, cycle_scroller(max_results, max_results, 5))
    end)

    it('should return 0 at 0', function()
      eq(0, cycle_scroller(max_results, max_results, 0))
    end)

    it('should cycle you to the top when you go below 0', function()
      eq(max_results - 1, cycle_scroller(max_results, max_results, -1))
    end)

    it('should cycle you to 0 when you go past the results', function()
      eq(0, cycle_scroller(max_results, max_results, max_results + 1))
    end)

    it('should cycle when current results is less than max_results', function()
      eq(0, cycle_scroller(max_results, 5, 7))
    end)
  end)

  describe('other', function()
    local limit_scroller = p_scroller.create('limit')

    it('should return values within the max results', function()
      eq(5, limit_scroller(max_results, max_results, 5))
    end)

    it('should return 0 at 0', function()
      eq(0, limit_scroller(max_results, max_results, 0))
    end)

    it('should not cycle', function()
      eq(0, limit_scroller(max_results, max_results, -1))
    end)

    it('should cycle you to 0 when you go past the results', function()
      eq(max_results - 1, limit_scroller(max_results, max_results, max_results + 1))
    end)

    it('should stay at current results when current results is less than max_results', function()
      local current = 5
      eq(current - 1, limit_scroller(max_results, current, 7))
    end)
  end)
end)
