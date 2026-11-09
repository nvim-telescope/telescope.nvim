local make_entry = require "telescope.make_entry"

local eq = assert.eq

describe("gen_from_ctags", function()
  local root = vim.uv.cwd()

  local function tag(file)
    return ('foo\t%s\t/^foo$/;"\tkind:f'):format(file)
  end

  local function current_file_maker(file, cwd)
    local bufnr = vim.fn.bufadd(vim.fs.joinpath(root, file))
    return make_entry.gen_from_ctags { bufnr = bufnr, cwd = cwd, only_current_file = true }
  end

  it("keeps tags of the current file with only_current_file", function()
    local maker = current_file_maker "README.md"
    eq("README.md", maker(tag "README.md").filename)
    eq("./README.md", maker(tag "./README.md").filename)
    eq(vim.fs.joinpath(root, "README.md"), maker(tag(vim.fs.joinpath(root, "README.md"))).filename)
  end)

  it("drops tags of other files with only_current_file", function()
    local maker = current_file_maker "README.md"
    eq(nil, maker(tag "lua/telescope/init.lua"))
  end)

  it("resolves tag files relative to opts.cwd", function()
    local maker = current_file_maker("lua/telescope/init.lua", vim.fs.joinpath(root, "lua"))
    eq("telescope/init.lua", maker(tag "telescope/init.lua").filename)
    eq(nil, maker(tag "lua/telescope/init.lua"))
  end)
end)

describe("gen_from_buffer", function()
  local root = vim.uv.cwd()
  local maker = make_entry.gen_from_buffer { bufnr_width = 1 }
  local bufnr = vim.api.nvim_get_current_buf()

  local function entry(name)
    return maker { bufnr = bufnr, flag = " ", info = { name = name, hidden = 0, changed = 0, lnum = 0 } }
  end

  it("uses names relative to cwd", function()
    local e = entry(vim.fs.joinpath(root, "README.md"))
    eq("README.md", e.filename)
    eq(bufnr .. " : README.md", e.ordinal)
    eq(vim.fs.joinpath(root, "README.md"), e.path)
  end)

  it("abbreviates the home directory outside of cwd", function()
    local sep = require("telescope.utils").pathsep
    eq("~" .. sep .. "outside.txt", entry(vim.uv.os_homedir() .. sep .. "outside.txt").filename)
  end)

  it("keeps URIs", function()
    eq("term://~/foo//1:sh", entry("term://~/foo//1:sh").filename)
    eq("oil:///tmp/", entry("oil:///tmp/").filename)
  end)
end)

describe("entry paths", function()
  local root = vim.uv.cwd()
  local readme = vim.fs.joinpath(root, "README.md")

  it("gen_from_file resolves relative values and keeps absolute ones", function()
    local maker = make_entry.gen_from_file { cwd = vim.fs.joinpath(root, "lua") }
    eq(readme, maker("../README.md").path)
    eq(readme, maker(readme).path)
  end)

  it("gen_from_vimgrep resolves relative values and keeps absolute ones", function()
    local maker = make_entry.gen_from_vimgrep { cwd = vim.fs.joinpath(root, "lua") }
    eq(readme, maker("../README.md:1:1:text").path)
    eq(readme, maker(readme .. ":1:1:text").path)
  end)

  it("does not expand environment variables in file names", function()
    vim.env.TELESCOPE_TEST_VAR = "expanded"
    local maker = make_entry.gen_from_vimgrep { cwd = root }
    eq(vim.fs.joinpath(root, "$TELESCOPE_TEST_VAR.lua"), maker("$TELESCOPE_TEST_VAR.lua:1:1:text").path)
  end)
end)
