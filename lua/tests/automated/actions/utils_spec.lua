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

    -- =================================================================
    -- TDD TESTS FOR vim.validate SYNTAX MIGRATION (line 38)
    -- These should FAIL with old syntax and PASS with new syntax
    -- =================================================================

    -- Test that demonstrates the new vim.validate argument-based syntax
    it("should use new vim.validate argument syntax (not table syntax)", function()
      -- Mock vim.validate to track how it's called
      local original_vim_validate = vim.validate
      local validate_call_args = {}

      vim.validate = function(...)
        validate_call_args = {...}
        return original_vim_validate(...)
      end

      -- Set up minimal mock
      action_state.get_current_picker = function(bufnr)
        return {
          manager = {
            iter = function()
              return function() return nil end
            end,
          },
          get_row = function(index) return index end
        }
      end

      -- Call the function
      local success = pcall(function()
        utils.map_entries(1, function() end)
      end)

      -- Restore original vim.validate
      vim.validate = original_vim_validate
      action_state.get_current_picker = original_get_current_picker

      -- This test expects the NEW argument-based syntax: vim.validate("f", f, "function")
      -- With old syntax: validate_call_args[1] would be a table like { f = { f, "function" } }
      -- With new syntax: validate_call_args would be {"f", function_value, "function"}

      if success then
        assert.is_true(#validate_call_args == 3,
          "Expected 3 arguments to vim.validate (name, value, type), got " .. #validate_call_args)
        assert.are.equal("f", validate_call_args[1],
          "First argument should be parameter name 'f'")
        assert.are.equal("function", validate_call_args[3],
          "Third argument should be type 'function'")
        assert.is_function(validate_call_args[2],
          "Second argument should be the actual function value")
      end
    end)

    -- Additional test to ensure we're not accidentally calling the old table syntax
    it("should not use old table-based vim.validate syntax", function()
      -- Mock vim.validate to detect table-based calls
      local original_vim_validate = vim.validate
      local used_table_syntax = false

      vim.validate = function(arg1, ...)
        if type(arg1) == "table" and arg1.f then
          used_table_syntax = true
        end
        return original_vim_validate(arg1, ...)
      end

      -- Set up minimal mock
      action_state.get_current_picker = function(bufnr)
        return {
          manager = {
            iter = function()
              return function() return nil end
            end,
          },
          get_row = function(index) return index end
        }
      end

      -- Call the function
      pcall(function()
        utils.map_entries(1, function() end)
      end)

      -- Restore original vim.validate
      vim.validate = original_vim_validate
      action_state.get_current_picker = original_get_current_picker

      -- This should FAIL with old syntax, PASS with new syntax
      assert.is_false(used_table_syntax,
        "Should not use old table-based vim.validate syntax like vim.validate({ f = { f, 'function' } })")
    end)

  end) -- Close map_entries function validation describe block
 end) -- Close the main describe block
