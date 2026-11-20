local t = require("test.testutil")
local sut = require("tests.sut")
local describe, it, before_each, after_each, eq = t.describe, t.it, t.before_each, t.after_each, t.eq
local n = require("test.functional.testnvim")()
local exec_lua = n.exec_lua

sut.setup()

local chars = { "t", "r", "b", "l", "1", "2", "3", "4" } -- top, right, bottom, left, corners (Vim order)

describe("telescope.pickers.ui", function()
  local function create(opts)
    local win, cfg, border = exec_lua(function()
      local win, border = require("telescope.pickers.ui").create(
        nil,
        vim.tbl_extend("keep", opts, { enter = false, width = 20, height = 5 })
      )
      return win, vim.api.nvim_win_get_config(win), border ~= nil or nil
    end)
    return win, border, cfg
  end

  before_each(function()
    n.api.nvim_set_option_value("columns", 80, {})
    n.api.nvim_set_option_value("lines", 24, {})
  end)

  after_each(function()
    for _, win in ipairs(n.api.nvim_list_wins()) do
      if n.api.nvim_win_get_config(win).relative ~= "" then
        pcall(n.api.nvim_win_close, win, true)
      end
    end
  end)

  it("draws the border natively around the content at line/col", function()
    local win, _, cfg = create({ line = 3, col = 5, borderchars = chars })
    eq({ "1", "t", "2", "r", "3", "b", "4", "l" }, cfg.border)
    -- the native position is the border's corner, the content starts at line 3, col 5
    eq({ 1, 3 }, { cfg.row, cfg.col })
    eq({ 20, 5 }, { n.api.nvim_win_get_width(win), n.api.nvim_win_get_height(win) })
  end)

  it("hides sides with thickness 0 and at the screen edge", function()
    local _, _, cfg = create({ line = 3, col = 5, borderchars = chars, border = { 0, 1, 1, 1 } })
    eq({ "", "", "", "r", "3", "b", "4", "l" }, cfg.border)
    _, _, cfg = create({ line = 1, col = 1, width = 80, borderchars = chars })
    eq({ "", "", "", "", "", "b", "", "" }, cfg.border)
  end)

  it("has no border without borderchars or with border = false", function()
    local _, border, cfg = create({ line = 3, col = 5, borderchars = chars, border = false })
    eq({ nil, "none" }, { border, cfg.border == "none" and "none" or cfg.border })
    _, border = create({ line = 3, col = 5 })
    eq(nil, border)
  end)

  it("puts N titles on top and S titles at the bottom", function()
    local _, _, cfg = create({
      line = 3,
      col = 5,
      borderchars = chars,
      title = { { pos = "SE", text = "foot" }, { pos = "NW", text = "head" } },
    })
    eq({ { { " head " } }, "left" }, { cfg.title, cfg.title_pos })
    eq({ { { " foot " } }, "right" }, { cfg.footer, cfg.footer_pos })
  end)

  it("keeps the title position on change_title and the title on move", function()
    exec_lua(function()
      local ui = require("telescope.pickers.ui")
      local eq = require("test.assert").eq
      local function create(opts)
        local win, border = ui.create(nil, vim.tbl_extend("keep", opts, { enter = false, width = 20, height = 5 }))
        return win, border, vim.api.nvim_win_get_config(win)
      end
      local win, border = create({
        line = 3,
        col = 5,
        borderchars = chars,
        title = { { pos = "S", text = "old" } },
      })
      border:change_title("new")
      local cfg = vim.api.nvim_win_get_config(win)
      eq({ nil, { { " new " } } }, { cfg.title, cfg.footer })
      ui.move(win, { line = 10, col = 10, width = 30, height = 4 })
      cfg = vim.api.nvim_win_get_config(win)
      eq({ { { " new " } }, 8, 8 }, { cfg.footer, cfg.row, cfg.col })
      eq({ 30, 4 }, { vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win) })
    end)
  end)
end)
