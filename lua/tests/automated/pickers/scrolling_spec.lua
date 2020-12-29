require('plenary.reload').reload_module('telescope')

local tester = require('telescope.pickers._test')

describe('scrolling strategies', function()
  it('should handle cycling for full list', function()
    tester.run_file [[find_files__scrolling_descending_cycle]]
  end)
end)
