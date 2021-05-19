-- local tester = require('telescope.pickers._test')

local resolve = require('telescope.config.resolve')
local calculators = require('telescope.pickers.layout_strategies')

local validate_layout_config = calculators._validate_layout_config

local eq = assert.are.same

describe('layout_strategies', function()
  it('should have validator', function()
    assert(validate_layout_config, "Has validator")
  end)

  local test_height = function(should, output, input, opts)
    opts = opts or {}

    local max_columns, max_lines = opts.max_columns or 100, opts.max_lines or 100
    it(should, function()
      local config = validate_layout_config("horizontal", { height = true }, { height = input })

      eq(output, resolve.resolve_height(config.height)({}, max_columns, max_lines))
    end)
  end

  test_height('should handle numbers', 10, 10)

  test_height('should handle percentage: 100', 10, 0.1, { max_lines = 100 })
  test_height('should handle percentage: 110', 11, 0.1, { max_lines = 110 })

  test_height('should call functions: simple', 5, function() return 5 end)
  test_height('should call functions: percentage', 15, function(_, _, lines) return 0.1 * lines end, { max_lines = 150 })
end)
