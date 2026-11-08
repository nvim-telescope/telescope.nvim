local ui = require "telescope.pickers.ui"

local eq = assert.are.same

local chars = { "t", "r", "b", "l", "1", "2", "3", "4" } -- top, right, bottom, left, corners (Vim order)

describe("telescope.pickers.ui", function()
  local wins = {}
  local function create(opts)
    local win, o = ui.create(nil, vim.tbl_extend("keep", opts, { enter = false, width = 20, height = 5 }))
    table.insert(wins, win)
    return win, o.border, vim.api.nvim_win_get_config(win)
  end

  before_each(function()
    vim.o.columns, vim.o.lines = 80, 24
  end)

  after_each(function()
    for _, win in ipairs(wins) do
      pcall(vim.api.nvim_win_close, win, true)
    end
    wins = {}
  end)

  it("draws the border natively around the content at line/col", function()
    local win, _, cfg = create { line = 3, col = 5, borderchars = chars }
    eq({ "1", "t", "2", "r", "3", "b", "4", "l" }, cfg.border)
    -- the native position is the border's corner, the content starts at line 3, col 5
    eq({ 1, 3 }, { cfg.row, cfg.col })
    eq({ 20, 5 }, { vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win) })
  end)

  it("hides sides with thickness 0 and at the screen edge", function()
    local _, _, cfg = create { line = 3, col = 5, borderchars = chars, border = { 0, 1, 1, 1 } }
    eq({ "", "", "", "r", "3", "b", "4", "l" }, cfg.border)
    _, _, cfg = create { line = 1, col = 1, width = 80, borderchars = chars }
    eq({ "", "", "", "", "", "b", "", "" }, cfg.border)
  end)

  it("has no border without borderchars or with border = false", function()
    local _, border, cfg = create { line = 3, col = 5, borderchars = chars, border = false }
    eq({ nil, "none" }, { border, cfg.border == "none" and "none" or cfg.border })
    _, border = create { line = 3, col = 5 }
    eq(nil, border)
  end)

  it("puts N titles on top and S titles at the bottom", function()
    local _, _, cfg = create {
      line = 3,
      col = 5,
      borderchars = chars,
      title = { { pos = "SE", text = "foot" }, { pos = "NW", text = "head" } },
    }
    eq({ { { " head " } }, "left" }, { cfg.title, cfg.title_pos })
    eq({ { { " foot " } }, "right" }, { cfg.footer, cfg.footer_pos })
  end)

  it("keeps the title position on change_title and the title on move", function()
    local win, border = create {
      line = 3,
      col = 5,
      borderchars = chars,
      title = { { pos = "S", text = "old" } },
    }
    border:change_title "new"
    local cfg = vim.api.nvim_win_get_config(win)
    eq({ nil, { { " new " } } }, { cfg.title, cfg.footer })
    ui.move(win, { line = 10, col = 10, width = 30, height = 4 })
    cfg = vim.api.nvim_win_get_config(win)
    eq({ { { " new " } }, 8, 8 }, { cfg.footer, cfg.row, cfg.col })
    eq({ 30, 4 }, { vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win) })
  end)
end)
