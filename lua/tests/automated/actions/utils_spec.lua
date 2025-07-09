-- File: /lua/tests/automated/actions/utils_spec.lua

describe("telescope.actions.utils", function()

  -- Verify module loads correctly
  it("should load the utils module without errors", function()
    assert.is_not_nil(utils)
    assert.is_table(utils)
  end)

  -- Test the map_entries function parameter validation
  describe("map_entries function validation", function()

    it("should exist as a function", function()
      assert.is_function(utils.map_entries)
    end)

    -- Test valid parameter types
    it("should accept valid parameter types without vim.validate errors", function()
      local action_state = require("telescope.actions.state")
      local original_get_current_picker = action_state.get_current_picker

      -- Set up mock picker with minimal structure
      action_state.get_current_picker = function(bufnr)
        return {
          manager = {
            get_entries = function()
              return {
                { value = "first" },
                { value = "second" },
              }
            end,
            iter = function()
              local entries = {
                { value = "first" },
                { value = "second" },
              }
              local i = 0
              return function()
                i = i + 1
                if i <= #entries then
                  return entries[i], i
                end
                return nil
              end
            end,
          },
          get_row = function(index)
            return index
          end
        }
      end

      local valid_bufnr = 1
      local valid_function = function(entry, index, row)
        -- No-op test function
      end

      local success, error_msg = pcall(function()
        utils.map_entries(valid_bufnr, valid_function)
      end)

      -- Restore the original function
      action_state.get_current_picker = original_get_current_picker

      -- Test should pass without vim.validate errors
      assert.is_true(success, "map_entries should accept valid parameters: " .. (error_msg or ""))
    end)

    -- Test vim.validate rejects non-function for second parameter
    it("should reject non-function for second parameter", function()
      local valid_bufnr = 1

      assert.has_error(function()
        utils.map_entries(valid_bufnr, "not a function")
      end, "f: expected function, got string")
    end)

    -- Test vim.validate rejects table for second parameter
    it("should reject table for second parameter", function()
      local valid_bufnr = 1
      assert.has_error(function()
        utils.map_entries(valid_bufnr, {})
      end, "f: expected function, got table")
    end)

    -- Test vim.validate rejects number for second parameter
    it("should reject number for second parameter", function()
      local valid_bufnr = 1

      assert.has_error(function()
        utils.map_entries(valid_bufnr, 123)
      end, "f: expected function, got number")
    end)

    -- Test handling of different buffer number types
    it("should handle different buffer number types", function()
      local action_state = require("telescope.actions.state")
      local original_get_current_picker = action_state.get_current_picker

      -- Set up mock that works for all buffer numbers
      action_state.get_current_picker = function(bufnr)
        return {
          manager = {
            iter = function()
              -- Return an empty iterator
              return function()
                return nil
              end
            end,
          },
          get_row = function(index)
            return index
          end
        }
      end

      local valid_function = function(entry, index, row) end

      -- Test with different number types that could be valid buffer numbers
      local test_cases = {0, 1, 999}  -- Common buffer number patterns

      for _, bufnr in ipairs(test_cases) do
        local success, error_msg = pcall(function()
          utils.map_entries(bufnr, valid_function)
        end)

        -- Should not fail due to vim.validate function parameter errors
        if not success then
          assert.is_false(string.match(error_msg or "", "expected function") ~= nil,
            "Buffer number " .. bufnr .. " should not cause function validation error")
        end
      end

      -- Restore original function
      action_state.get_current_picker = original_get_current_picker
    end)

  -- You can add a similar describe block for the function on line 75
  describe("function with vim.validate on line 75", function()
    -- Similar structure as above, but for the second function
  end)

  -- Restore original function after test
  action_state.get_current_picker = original_get_current_picker


end) -- Close the main describe block

-- NEXT STEPS TO GET THIS WORKING:
-- 1. Look at your utils.lua file and find the function names that contain the vim.validate calls
-- 2. Replace "your_function_name" with the actual function names
-- 3. Run this test to see what happens
-- 4. Based on the errors you get, you'll learn what parameters the functions expect
-- 5. Gradually build up your test cases based on what you learn

-- DEBUGGING TIP:
-- If you're not sure what functions are available, you can add this temporary test:
-- it("should show available functions", function()
--   for k, v in pairs(utils) do
--     print(k, type(v))
--   end
-- end)
