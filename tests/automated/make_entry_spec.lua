local make_entry = require "telescope.make_entry"

local eq = assert.are.same

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
