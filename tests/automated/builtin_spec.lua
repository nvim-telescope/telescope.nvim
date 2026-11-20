local t = require("test.testutil")
local sut = require("tests.sut")
local describe, it, before_each, after_each, eq = t.describe, t.it, t.before_each, t.after_each, t.eq
local n = require("test.functional.testnvim")()
local exec_lua = n.exec_lua

sut.setup()

describe("builtin.buffers", function()
  local function listed_buffer(name)
    local bufnr = n.fn.bufadd(name)
    n.api.nvim_set_option_value("buflisted", true, { buf = bufnr })
    return bufnr
  end

  local function delete_named_buffers()
    for _, bufnr in ipairs(n.api.nvim_list_bufs()) do
      if n.api.nvim_buf_get_name(bufnr) ~= "" then
        n.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end
  before_each(delete_named_buffers)
  after_each(delete_named_buffers)

  it("filters buffers outside of cwd with cwd_only", function()
    listed_buffer(vim.fs.joinpath(vim.fs.dirname(vim.uv.cwd()), "outside.txt"))
    exec_lua(function()
      local builtin = require("telescope.builtin")
      local eq = require("test.assert").eq
      local win = vim.api.nvim_get_current_win()
      eq(true, (pcall(builtin.buffers, { cwd_only = true })))
      -- nothing left to show, so no picker was opened
      eq(win, vim.api.nvim_get_current_win())
    end)
  end)

  it("keeps buffers inside of cwd with cwd_only", function()
    listed_buffer(vim.fs.joinpath(vim.uv.cwd(), "README.md"))
    exec_lua(function()
      local builtin = require("telescope.builtin")
      local eq = require("test.assert").eq
      local win = vim.api.nvim_get_current_win()
      eq(true, (pcall(builtin.buffers, { cwd_only = true })))
      local prompt_bufnr = vim.api.nvim_get_current_buf()
      eq("TelescopePrompt", vim.bo[prompt_bufnr].filetype)
      require("telescope.actions").close(prompt_bufnr)
      eq(win, vim.api.nvim_get_current_win())
    end)
  end)
end)

describe("builtin.grep_string", function()
  it("searches open buffers outside of cwd with grep_open_files", function()
    exec_lua(function()
      local builtin = require("telescope.builtin")
      local eq = require("test.assert").eq
      local file = vim.fn.tempname()
      vim.fn.writefile({ "zzqtelescopeword" }, file)
      local bufnr = vim.fn.bufadd(file)
      vim.bo[bufnr].buflisted = true

      eq(true, (pcall(builtin.grep_string, { search = "zzqtelescopeword", grep_open_files = true })))
      local prompt_bufnr = vim.api.nvim_get_current_buf()
      local picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
      vim.wait(2000, function()
        return picker.manager and picker.manager:num_results() > 0
      end)
      local results = {}
      for entry in picker.manager:iter() do
        table.insert(results, vim.fs.basename(entry.filename))
      end
      require("telescope.actions").close(prompt_bufnr)
      vim.api.nvim_buf_delete(bufnr, { force = true })

      eq({ vim.fs.basename(file) }, results)
    end)
  end)

  it("does not need a word under the cursor when search is given", function()
    exec_lua(function()
      local builtin = require("telescope.builtin")
      local eq = require("test.assert").eq
      -- the test runner suppresses E348 ("No string under cursor"), so simulate it
      local expand = vim.fn.expand
      vim.fn.expand = function(expr, ...)
        if expr == "<cword>" then
          error("Vim:E348: No string under cursor")
        end
        return expand(expr, ...)
      end
      local ok = pcall(builtin.grep_string, { search = "zzqtelescopeword" })
      vim.fn.expand = expand
      eq(true, ok)
      local prompt_bufnr = vim.api.nvim_get_current_buf()
      eq("TelescopePrompt", vim.bo[prompt_bufnr].filetype)
      require("telescope.actions").close(prompt_bufnr)
    end)
  end)
end)

describe("builtin.commands", function()
  after_each(function()
    exec_lua(function()
      require("tests.picker_helpers").cleanup()
    end)
  end)

  it("shows commands with Lua completion", function()
    exec_lua(function()
      local h = require("tests.picker_helpers")
      local assert = require("test.assert")
      vim.api.nvim_create_user_command("TstLuaCmp", "", {
        nargs = 1,
        complete = function()
          return {}
        end,
      })
      local picker = h.picker("commands")
      h.type(picker, "TstLuaCmp")
      vim.api.nvim_del_user_command("TstLuaCmp")
      assert(h.best_result(picker):find("TstLuaCmp.*▏lua "))
    end)
  end)
end)

describe("telescope.ui_select", function()
  it("passes the chosen item and its index", function()
    local got = exec_lua(function()
      local action_state = require("telescope.actions.state")
      return require("tests.picker_helpers").ui_select(function(prompt_bufnr, picker)
        picker:set_prompt("banana")
        vim.wait(1000, function()
          local entry = action_state.get_selected_entry()
          return entry ~= nil and entry.value.name == "banana"
        end)
        require("telescope.actions").select_default(prompt_bufnr)
      end)
    end)
    eq({ item = { name = "banana" }, idx = 2 }, got)
  end)

  it("passes nil when closed", function()
    eq(
      {},
      exec_lua(function()
        return require("tests.picker_helpers").ui_select(require("telescope.actions").close)
      end)
    )
  end)

  it("passes nil when the picker is left", function()
    eq(
      {},
      exec_lua(function()
        local win = vim.api.nvim_get_current_win()
        return require("tests.picker_helpers").ui_select(function()
          vim.api.nvim_set_current_win(win)
        end)
      end)
    )
  end)

  it("passes nil without opening a picker if there are no items", function()
    exec_lua(function()
      local eq = require("test.assert").eq
      local win, got = vim.api.nvim_get_current_win(), nil
      require("telescope").ui_select({}, {}, function(item, idx)
        got = { item = item, idx = idx }
      end)
      vim.wait(1000, function()
        return got ~= nil
      end)
      eq({ {}, win }, { got, vim.api.nvim_get_current_win() })
    end)
  end)
end)

describe("pickers.new on_close", function()
  it("calls the picker's and the caller's on_close when the picker is closed", function()
    local calls = exec_lua(function()
      local calls = {}
      require("telescope.pickers")
        .new({
          on_close = function()
            table.insert(calls, "caller")
          end,
        }, {
          finder = require("telescope.finders").new_table({ results = { "a" } }),
          on_close = function()
            table.insert(calls, "picker")
          end,
        })
        :find()
      require("telescope.actions").close(vim.api.nvim_get_current_buf())
      vim.wait(1000, function()
        return #calls == 2
      end)
      return calls
    end)
    eq({ "picker", "caller" }, calls)
  end)
end)
