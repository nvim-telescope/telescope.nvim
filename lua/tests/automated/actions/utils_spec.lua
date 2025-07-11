-- File: /lua/tests/automated/actions/utils_spec.lua

describe("telescope.actions.utils", function()
  local utils
  local action_state

  -- Set up the module before each test
  before_each(function()
    -- Load the utils module
    utils = require "telescope.actions.utils"
    action_state = require "telescope.actions.state"
  end)

  -- Reset module cache after each test to prevent test interference
  after_each(function()
    -- Reset any global state if needed
    package.loaded["telescope.actions.utils"] = nil
    package.loaded["telescope.actions.state"] = nil
  end)

  -- Helper function to create a mock picker with specified entries
  -- This simulates the picker's manager interface for testing map_entries
  local function create_mock_picker_with_entries(entries)
    return {
      manager = {
        get_entries = function()
          return entries
        end,
        -- Iterator function returns entries one by one (without index as second return value)
        -- This matches the actual telescope picker manager behavior
        iter = function()
          local i = 0
          return function()
            i = i + 1
            if i <= #entries then
              return entries[i] -- Return only the entry, not the index
            end
            return nil
          end
        end,
      },
      -- Convert 1-based index to 0-based row number (telescope display convention)
      get_row = function(self, index)
        return index - 1 -- 0-indexed rows
      end,
    }
  end

  -- Helper function to create a mock picker with specified selections
  -- This simulates the picker's multi-selection interface for testing map_selections
  local function create_mock_picker_with_selections(selections)
    return {
      get_multi_selection = function()
        return selections
      end,
    }
  end

  -- Smoke test to verify the module loads correctly
  it("should load the utils module without errors", function()
    assert.is_not_nil(utils)
    assert.is_table(utils)
  end)

  -- ============================================================================
  -- Test suite for map_entries function parameter validation
  -- ============================================================================
  describe("map_entries function validation", function()
    it("should exist as a function", function()
      assert.is_function(utils.map_entries)
    end)

    -- Test that valid parameter types are accepted by vim.validate
    it("should accept valid parameter types without vim.validate errors", function()
      local original_get_current_picker = action_state.get_current_picker

      -- Mock picker with minimal required structure for map_entries
      action_state.get_current_picker = function(bufnr)
        return {
          manager = {
            get_entries = function()
              return {
                { value = "first" },
                { value = "second" },
              }
            end,
            -- Iterator returns entry and index (telescope manager convention)
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
          end,
        }
      end

      local valid_bufnr = 1
      local valid_function = function(entry, index, row)
        -- Test callback function - intentionally empty
      end

      local success, error_msg = pcall(function()
        utils.map_entries(valid_bufnr, valid_function)
      end)

      -- Restore original function to avoid side effects
      action_state.get_current_picker = original_get_current_picker

      -- Verify that vim.validate accepts the valid parameters
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

    -- Test that different valid buffer number types are handled properly
    it("should handle different buffer number types", function()
      local original_get_current_picker = action_state.get_current_picker

      -- Mock that accepts any buffer number and returns minimal picker
      action_state.get_current_picker = function(bufnr)
        return {
          manager = {
            iter = function()
              -- Return an empty iterator for testing
              return function()
                return nil
              end
            end,
          },
          get_row = function(index)
            return index
          end,
        }
      end

      local valid_function = function(entry, index, row) end

      -- Test with different number types that could be valid buffer numbers
      local test_cases = { 0, 1, 999 } -- Common buffer number patterns

      for _, bufnr in ipairs(test_cases) do
        local success, error_msg = pcall(function()
          utils.map_entries(bufnr, valid_function)
        end)

        -- Verify that failures are not due to vim.validate function parameter errors
        if not success then
          assert.is_false(
            string.match(error_msg or "", "expected function") ~= nil,
            "Buffer number " .. bufnr .. " should not cause function validation error"
          )
        end
      end

      -- Restore original function
      action_state.get_current_picker = original_get_current_picker
    end)

    -- Test edge case: empty entries list
    it("should handle empty entries gracefully", function()
      local original_get_current_picker = action_state.get_current_picker

      action_state.get_current_picker = function(bufnr)
        return create_mock_picker_with_entries {} -- Empty entries
      end

      local call_count = 0
      local success, error_msg = pcall(function()
        utils.map_entries(1, function(entry, index, row)
          call_count = call_count + 1
        end)
      end)

      action_state.get_current_picker = original_get_current_picker

      assert.is_true(success, "Should handle empty entries without error: " .. (error_msg or ""))
      assert.are.equal(0, call_count, "Should not call function for emptry entries")
    end)

    -- Performance test: ensure large datasets are handled efficiently
    it("should handle large numbers of entries efficiently", function()
      local original_get_current_picker = action_state.get_current_picker

      -- Create 1000 mock entries
      local large_entries = {}
      for i = 1, 1000 do
        table.insert(large_entries, { value = "entry_" .. i })
      end

      action_state.get_current_picker = function(bufnr)
        local picker = create_mock_picker_with_entries(large_entries)
        return picker
      end

      local processed_entries = {}
      local start_time = os.clock()
      local success, error_msg = pcall(function()
        utils.map_entries(1, function(entry, index, row)
          table.insert(processed_entries, {
            value = entry.value,
            index = index,
            row = row,
          })
          -- Verify parameter contracts are maintained at scale
          assert.is_table(entry, "Entry should be a table")
          assert.is_number(index, "Index should be a number")
          assert.is_number(row, "Row should be a number")
          assert.are.equal(index - 1, row, "Row should be index - 1")
        end)
      end)
      local end_time = os.clock()

      local duration = end_time - start_time
      action_state.get_current_picker = original_get_current_picker

      -- Verify correctness and performance
      assert.is_true(success, "Should handle large entries without error: " .. (error_msg or ""))
      assert.are.equal(1000, #processed_entries, "Should process exactly 1000 entries")
      assert.are.equal("entry_1", processed_entries[1].value, "First entry should be correct")
      assert.are.equal("entry_1000", processed_entries[1000].value, "Last entry should be correct")
      assert.are.equal(1, processed_entries[1].index, "First index should be 1")
      assert.are.equal(0, processed_entries[1].row, "First row should be 0")
      assert.is_true(duration < 1.0, "Should complete within reasonable time (< 1 second), took: " .. duration)
    end)

    it("should work end-to-end with minimal mocking", function()
      local original_get_current_picker = action_state.get_current_picker

      -- Minimal mock that just provides the essential interface
      local test_entries = {
        { value = "file1.txt", ordinal = "file1.txt" },
        { value = "file2.txt", ordinal = "file2.txt" },
        { value = "file3.txt", ordinal = "file3.txt" },
      }

      action_state.get_current_picker = function(bufnr)
        return create_mock_picker_with_entries(test_entries)
      end

      -- Small delay to allow initialization
      vim.wait(1) -- Wait 1ms

      local results = {}
      local success, error_msg = pcall(function()
        utils.map_entries(1, function(entry, index, row)
          results[row] = {
            value = entry.value,
            index = index,
            row = row,
          }
        end)
      end)

      action_state.get_current_picker = original_get_current_picker

      assert.is_true(success, "Integration test should succeed: " .. (error_msg or ""))

      -- Count actual entries
      local count = 0
      for _ in pairs(results) do
        count = count + 1
      end

      assert.are.equal(3, count, "Should have processed 3 entries")

      -- Verify telescope's row indexing convention (0-based display rows)
      assert.are.equal("file1.txt", results[0].value, "First entry should be at row 0")
      assert.are.equal("file2.txt", results[1].value, "Second entry should be at row 1")
      assert.are.equal("file3.txt", results[2].value, "Third entry should be at row 2")

      -- Verify index/row relationship maintains telescope conventions
      for i = 0, 2 do
        assert.are.equal(i + 1, results[i].index, "Index should be row + 1")
        assert.are.equal(i, results[i].row, "Row should be 0-indexed")
      end
    end)

    -- =================================================================
    -- TDD TESTS FOR vim.validate SYNTAX MIGRATION (map_entries function)
    -- These should FAIL with old syntax and PASS with new syntax
    -- =================================================================

    -- Test that verifies the new vim.validate argument-based syntax is used
    it("should use new vim.validate argument syntax (not table syntax)", function()
      -- Mock vim.validate to track how it's called
      local original_vim_validate = vim.validate
      local validate_call_args = {}

      vim.validate = function(...)
        validate_call_args = { ... }
        return original_vim_validate(...)
      end

      local original_get_current_picker = action_state.get_current_picker

      -- Set up minimal mock
      action_state.get_current_picker = function(bufnr)
        return {
          manager = {
            iter = function()
              return function()
                return nil
              end
            end,
          },
          get_row = function(index)
            return index
          end,
        }
      end

      -- Call the function
      local success = pcall(function()
        utils.map_entries(1, function() end)
      end)

      -- Restore original functions
      vim.validate = original_vim_validate
      action_state.get_current_picker = original_get_current_picker

      -- Verify the NEW argument-based syntax: vim.validate("f", f, "function")
      -- Old syntax would pass a table: vim.validate({ f = { f, "function" } })
      -- New syntax passes separate arguments: vim.validate("f", function_value, "function")
      if success then
        assert.is_true(
          #validate_call_args == 3,
          "Expected 3 arguments to vim.validate (name, value, type), got " .. #validate_call_args
        )
        assert.are.equal("f", validate_call_args[1], "First argument should be parameter name 'f'")
        assert.are.equal("function", validate_call_args[3], "Third argument should be type 'function'")
        assert.is_function(validate_call_args[2], "Second argument should be the actual function value")
      end
    end)

    -- Test that confirms we're not using the deprecated table-based syntax
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

      local original_get_current_picker = action_state.get_current_picker

      -- Set up minimal mock
      action_state.get_current_picker = function(bufnr)
        return {
          manager = {
            iter = function()
              return function()
                return nil
              end
            end,
          },
          get_row = function(index)
            return index
          end,
        }
      end

      -- Call the function
      pcall(function()
        utils.map_entries(1, function() end)
      end)

      -- Restore original functions
      vim.validate = original_vim_validate
      action_state.get_current_picker = original_get_current_picker

      -- This should FAIL with old syntax, PASS with new syntax
      assert.is_false(
        used_table_syntax,
        "Should not use old table-based vim.validate syntax like vim.validate({ f = { f, 'function' } })"
      )
    end)
  end) -- End map_entries function validation tests

  -- ============================================================================
  -- Test suite for map_entries function parameter validation
  -- ============================================================================
  describe("map_selections function validation", function()
    it("should exist as a function", function()
      assert.is_function(utils.map_selections)
    end)

    -- Test that valid parameter types are accepted by vim.validate
    it("should accept valid parameter types without vim.validate errors", function()
      local action_state = require "telescope.actions.state"
      local original_get_current_picker = action_state.get_current_picker

      -- Mock picker with multi-selection capability
      action_state.get_current_picker = function(bufnr)
        return {
          get_multi_selection = function()
            return {
              { value = "selected_first" },
              { value = "selected_second" },
            }
          end,
        }
      end

      local valid_bufnr = 1
      local valid_function = function(selection)
        -- Test callback function - intentionally empty
      end

      local success, error_msg = pcall(function()
        utils.map_selections(valid_bufnr, valid_function)
      end)

      -- Restore original function to avoid side effects
      action_state.get_current_picker = original_get_current_picker

      -- Verify that vim.validate accepts the valid parameters
      assert.is_true(success, "map_selections should accept valid parameters: " .. (error_msg or ""))
    end)

    -- Test vim.validate rejects non-function for second parameter
    it("should reject non-function for second parameter", function()
      local valid_bufnr = 1

      assert.has_error(function()
        utils.map_selections(valid_bufnr, "not a function")
      end, "f: expected function, got string")
    end)

    it("should reject table for second parameter", function()
      local valid_bufnr = 1
      assert.has_error(function()
        utils.map_selections(valid_bufnr, {})
      end, "f: expected function, got table")
    end)

    it("should reject number for second parameter", function()
      local valid_bufnr = 1

      assert.has_error(function()
        utils.map_selections(valid_bufnr, 123)
      end, "f: expected function, got number")
    end)

    it("should reject nil for second parameter", function()
      local valid_bufnr = 1

      assert.has_error(function()
        utils.map_selections(valid_bufnr, nil)
      end, "f: expected function, got nil")
    end)

    -- Test that different valid buffer number types are handled properly
    it("should handle different buffer number types", function()
      local action_state = require "telescope.actions.state"
      local original_get_current_picker = action_state.get_current_picker

      -- Mock that accepts any buffer number and returns minimal picker
      action_state.get_current_picker = function(bufnr)
        return {
          get_multi_selection = function()
            return {} -- empty selection
          end,
        }
      end

      local valid_function = function(selection) end

      -- Test with different number types that could be valid buffer numbers
      local test_cases = { 0, 1, 999 } -- Common buffer number patterns

      for _, bufnr in ipairs(test_cases) do
        local success, error_msg = pcall(function()
          utils.map_selections(bufnr, valid_function)
        end)

        -- Verify that failures are not due to vim.validate function parameter errors
        if not success then
          assert.is_false(
            string.match(error_msg or "", "expected function") ~= nil,
            "Buffer number " .. bufnr .. " should not cause function validation error"
          )
        end
      end

      -- Restore original function to avoid side effects
      action_state.get_current_picker = original_get_current_picker
    end)

    -- Test edge case: empty selections list
    it("should handle empty selections gracefully", function()
      local original_get_current_picker = action_state.get_current_picker

      action_state.get_current_picker = function(bufnr)
        return create_mock_picker_with_selections {} -- Empty selections
      end

      local call_count = 0
      local success, error_msg = pcall(function()
        utils.map_selections(1, function(selection)
          call_count = call_count + 1
        end)
      end)

      action_state.get_current_picker = original_get_current_picker

      assert.is_true(success, "Should handle empty selections without error: " .. (error_msg or ""))
      assert.are.equal(0, call_count, "Should not call function for empty selections")
    end)

    -- Performance test: ensure large selection sets are handled efficiently
    it("should handle large numbers of selections efficiently", function()
      local original_get_current_picker = action_state.get_current_picker

      -- Create substantial multi-selection dataset (realistic for bulk operations)
      local large_selections = {}
      for i = 1, 500 do
        table.insert(large_selections, { value = "selection_" .. i })
      end

      action_state.get_current_picker = function(bufnr)
        return create_mock_picker_with_selections(large_selections)
      end

      local processed_count = 0
      local start_time = os.clock()

      local success, error_msg = pcall(function()
        utils.map_selections(1, function(selection)
          processed_count = processed_count + 1
          assert.is_table(selection, "Selection should be a table")
          assert.is_string(selection.value, "Selection should have a value")
        end)
      end)

      local end_time = os.clock()
      local duration = end_time - start_time

      action_state.get_current_picker = original_get_current_picker

      assert.is_true(success, "Should handle large selections without error: " .. (error_msg or ""))
      assert.are.equal(500, processed_count, "Should process all 500 selections")
      assert.is_true(duration < 0.5, "Should complete within reasonable time (< 0.5 seconds), took: " .. duration)
    end)

    -- Integration test with realistic multi-selection scenario
    it("should work end-to-end with realistic multi-selection scenario", function()
      local original_get_current_picker = action_state.get_current_picker

      -- Simulate a realistic multi-selection scenario
      local test_selections = {
        { value = "src/main.lua", ordinal = "src/main.lua", filename = "main.lua" },
        { value = "src/utils.lua", ordinal = "src/utils.lua", filename = "utils.lua" },
        { value = "tests/test_main.lua", ordinal = "tests/test_main.lua", filename = "test_main.lua" },
      }

      action_state.get_current_picker = function(bufnr)
        return create_mock_picker_with_selections(test_selections)
      end

      local processed_files = {}
      local success, error_msg = pcall(function()
        utils.map_selections(1, function(selection)
          table.insert(processed_files, {
            path = selection.value,
            filename = selection.filename,
          })
        end)
      end)

      action_state.get_current_picker = original_get_current_picker

      assert.is_true(success, "Integration test should succeed: " .. (error_msg or ""))
      assert.are.equal(3, #processed_files, "Should have processed 3 selections")

      -- Verify the integration worked correctly
      assert.are.equal("src/main.lua", processed_files[1].path)
      assert.are.equal("main.lua", processed_files[1].filename)
      assert.are.equal("src/utils.lua", processed_files[2].path)
      assert.are.equal("utils.lua", processed_files[2].filename)
      assert.are.equal("tests/test_main.lua", processed_files[3].path)
      assert.are.equal("test_main.lua", processed_files[3].filename)
    end)

    -- =================================================================
    -- TDD TESTS FOR vim.validate SYNTAX MIGRATION (map_selections)
    -- These should FAIL with old syntax and PASS with new syntax
    -- =================================================================

    -- Test that verifies the new vim.validate argument-based syntax is used
    it("should use new vim.validate argument syntax for map_selections (not table syntax)", function()
      -- Mock vim.validate to track how it's called
      local original_vim_validate = vim.validate
      local validate_call_args = {}

      vim.validate = function(...)
        validate_call_args = { ... }
        return original_vim_validate(...)
      end

      -- Set up minimal mock
      action_state.get_current_picker = function(bufnr)
        return {
          get_multi_selection = function()
            return {} -- empty selection
          end,
        }
      end

      -- Call the function
      local success = pcall(function()
        utils.map_selections(1, function() end)
      end)

      -- Restore original functions
      vim.validate = original_vim_validate
      action_state.get_current_picker = original_get_current_picker

      -- Verify the NEW argument-based syntax: vim.validate("f", f, "function")
      -- Old syntax would pass a table: vim.validate({ f = { f, "function" } })
      -- New syntax passes separate arguments: vim.validate("f", function_value, "function")
      if success then
        assert.is_true(
          #validate_call_args == 3,
          "Expected 3 arguments to vim.validate (name, value, type), got " .. #validate_call_args
        )
        assert.are.equal("f", validate_call_args[1], "First argument should be parameter name 'f'")
        assert.are.equal("function", validate_call_args[3], "Third argument should be type 'function'")
        assert.is_function(validate_call_args[2], "Second argument should be the actual function value")
      end
    end)

    -- Test that confirms we're not using the deprecated table-based syntax
    it("should not use old table-based vim.validate syntax in map_selections", function()
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
          get_multi_selection = function()
            return {} -- empty selection
          end,
        }
      end

      -- Call the function
      pcall(function()
        utils.map_selections(1, function() end)
      end)

      -- Restore original functions
      vim.validate = original_vim_validate
      action_state.get_current_picker = original_get_current_picker

      -- This test ensures we're using the modern vim.validate syntax
      assert.is_false(used_table_syntax, "Should not use old table-based vim.validate syntax in map_selections")
    end)

    -- Test that verifies proper iteration through multi-selections
    it("should properly iterate through multi-selections", function()
      local action_state = require "telescope.actions.state"
      local original_get_current_picker = action_state.get_current_picker

      local test_selections = {
        { value = "first_selection" },
        { value = "second_selection" },
        { value = "third_selection" },
      }

      -- Set up mock picker with test selections
      action_state.get_current_picker = function(bufnr)
        return {
          get_multi_selection = function()
            return test_selections
          end,
        }
      end

      local processed_selections = {}
      local success = pcall(function()
        utils.map_selections(1, function(selection)
          table.insert(processed_selections, selection.value)
        end)
      end)

      -- Restore original function to avoid side effects
      action_state.get_current_picker = original_get_current_picker

      -- Verify successful iteration through all selections
      assert.is_true(success, "map_selections should execute without errors")
      assert.are.equal(3, #processed_selections, "Should have processed 3 selections")
      assert.are.equal("first_selection", processed_selections[1])
      assert.are.equal("second_selection", processed_selections[2])
      assert.are.equal("third_selection", processed_selections[3])
    end)
  end) -- End map_selections function validation tests
end) -- End main describe block
