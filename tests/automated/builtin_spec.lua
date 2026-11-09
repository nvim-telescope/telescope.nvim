local builtin = require "telescope.builtin"

local eq = assert.eq

describe("builtin.buffers", function()
  local function listed_buffer(name)
    local bufnr = vim.fn.bufadd(name)
    vim.bo[bufnr].buflisted = true
    return bufnr
  end

  local function delete_named_buffers()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(bufnr) ~= "" then
        vim.api.nvim_buf_delete(bufnr, { force = true })
      end
    end
  end
  before_each(delete_named_buffers)
  after_each(delete_named_buffers)

  it("filters buffers outside of cwd with cwd_only", function()
    listed_buffer(vim.fs.joinpath(vim.fs.dirname(vim.uv.cwd()), "outside.txt"))
    local win = vim.api.nvim_get_current_win()
    eq(true, (pcall(builtin.buffers, { cwd_only = true })))
    -- nothing left to show, so no picker was opened
    eq(win, vim.api.nvim_get_current_win())
  end)

  it("keeps buffers inside of cwd with cwd_only", function()
    listed_buffer(vim.fs.joinpath(vim.uv.cwd(), "README.md"))
    local win = vim.api.nvim_get_current_win()
    eq(true, (pcall(builtin.buffers, { cwd_only = true })))
    local prompt_bufnr = vim.api.nvim_get_current_buf()
    eq("TelescopePrompt", vim.bo[prompt_bufnr].filetype)
    require("telescope.actions").close(prompt_bufnr)
    eq(win, vim.api.nvim_get_current_win())
  end)
end)

describe("builtin.grep_string", function()
  it("searches open buffers outside of cwd with grep_open_files", function()
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

  it("does not need a word under the cursor when search is given", function()
    -- the test runner suppresses E348 ("No string under cursor"), so simulate it
    local expand = vim.fn.expand
    vim.fn.expand = function(expr, ...)
      if expr == "<cword>" then
        error "Vim:E348: No string under cursor"
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

describe("telescope.ui_select", function()
  local actions = require "telescope.actions"
  local action_state = require "telescope.actions.state"

  local function select(steps)
    local got
    require("telescope").ui_select({ { name = "apple" }, { name = "banana" } }, {
      format_item = function(item)
        return item.name
      end,
    }, function(item, idx)
      got = { item = item, idx = idx }
    end)
    local prompt_bufnr = vim.api.nvim_get_current_buf()
    local picker = action_state.get_current_picker(prompt_bufnr)
    vim.wait(1000, function()
      return picker.manager and picker.manager:num_results() == 2
    end)
    steps(prompt_bufnr, picker)
    vim.wait(1000, function()
      return got ~= nil
    end)
    return got
  end

  it("passes the chosen item and its index", function()
    local got = select(function(prompt_bufnr, picker)
      picker:set_prompt "banana"
      vim.wait(1000, function()
        local entry = action_state.get_selected_entry()
        return entry ~= nil and entry.value.name == "banana"
      end)
      actions.select_default(prompt_bufnr)
    end)
    eq({ item = { name = "banana" }, idx = 2 }, got)
  end)

  it("passes nil when closed", function()
    eq({}, select(actions.close))
  end)

  it("passes nil when the picker is left", function()
    local win = vim.api.nvim_get_current_win()
    eq(
      {},
      select(function()
        vim.api.nvim_set_current_win(win)
      end)
    )
  end)

  it("passes nil without opening a picker if there are no items", function()
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

describe("pickers.new on_close", function()
  it("calls the picker's and the caller's on_close when the picker is closed", function()
    local calls = {}
    require("telescope.pickers")
      .new({
        on_close = function()
          table.insert(calls, "caller")
        end,
      }, {
        finder = require("telescope.finders").new_table { results = { "a" } },
        on_close = function()
          table.insert(calls, "picker")
        end,
      })
      :find()
    require("telescope.actions").close(vim.api.nvim_get_current_buf())
    vim.wait(1000, function()
      return #calls == 2
    end)
    eq({ "picker", "caller" }, calls)
  end)
end)
