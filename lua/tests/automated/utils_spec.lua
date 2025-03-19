local Path = require "plenary.path"
local utils = require "telescope.utils"

local eq = assert.are.equal

local os_sep = utils.get_separator()

local function new_relpath(unix_path)
  return Path:new(unpack(vim.split(unix_path, "/"))).filename
end

local function new_abspath(unix_path)
  unix_path = unix_path:gsub("^[/]+", "")
  return new_relpath(vim.loop.os_homedir() .. os_sep .. unix_path)
end

describe("path_expand()", function()
  it("removes trailing os_sep", function()
    local path = new_abspath "a/b"
    eq(path, utils.path_expand(path .. os_sep))
  end)

  it("works with root dir", function()
    if utils.iswin then
      eq([[C:\]], utils.path_expand [[C:\]])
      eq([[C:\]], utils.path_expand [[C:/]])
    else
      eq("/", utils.path_expand "/")
    end
  end)

  it("works with ~", function()
    local path = new_abspath "src/foo"
    eq(path, utils.path_expand "~/src/foo")
  end)

  it("handles duplicate os_sep", function()
    if utils.iswin then
      eq([[C:\Users\a]], utils.path_expand [[C:\\\Users\\a]])
    else
      eq("/home/user", utils.path_expand "/home///user")
    end
  end)

  it("preserves fake whitespace characters and whitespace", function()
    local path_space = new_relpath "foo/hello world"
    eq(path_space, utils.path_expand(path_space))

    -- backslash is always path sep in windows
    if not utils.iswin then
      local path_newline = [[/home/user/hello\nworld]]
      eq(path_newline, utils.path_expand(path_newline))
    end
  end)

  describe("early return for uri", function()
    local uris = {
      [[https://www.example.com/index.html]],
      [[ftp://ftp.example.com/files/document.pdf]],
      [[mailto:user@example.com]],
      [[tel:+1234567890]],
      [[file:///home/user/documents/report.docx]],
      [[news:comp.lang.python]],
      [[ldap://ldap.example.com:389/dc=example,dc=com]],
      [[git://github.com/user/repo.git]],
      [[steam://run/123456]],
      [[magnet:?xt=urn:btih:6B4C3343E1C63A1BC36AEB8A3D1F52C4EDEEB096]],
    }

    for _, uri in ipairs(uris) do
      it(uri, function()
        eq(uri, utils.path_expand(uri))
      end)
    end
  end)

  it("handles % expand", function()
    eq(vim.fn.expand "%", utils.path_expand "%")
  end)

  it("handles < expand", function()
    eq(vim.fn.expand "<cfile>", utils.path_expand "<cfile>")
  end)
end)

describe("is_uri", function()
  describe("detects valid uris", function()
    local uris = {
      [[https://www.example.com/index.html]],
      [[ftp://ftp.example.com/files/document.pdf]],
      [[mailto:user@example.com]],
      [[tel:+1234567890]],
      [[file:///home/user/documents/report.docx]],
      [[news:comp.lang.python]],
      [[ldap://ldap.example.com:389/dc=example,dc=com]],
      [[git://github.com/user/repo.git]],
      [[steam://run/123456]],
      [[magnet:?xt=urn:btih:6B4C3343E1C63A1BC36AEB8A3D1F52C4EDEEB096]],
    }

    for _, uri in ipairs(uris) do
      it(uri, function()
        assert.True(utils.is_uri(uri))
      end)
    end
  end)

  describe("detects invalid uris/paths", function()
    local inputs = {
      "hello",
      "hello:",
      "123",
      "",
    }
    for _, input in ipairs(inputs) do
      it(input, function()
        assert.False(utils.is_uri(input))
      end)
    end
  end)

  describe("handles windows paths", function()
    local paths = {
      [[C:\Users\Usuario\Documents\archivo.txt]],
      [[D:\Projects\project_folder\source_code.py]],
      [[E:\Music\song.mp3]],
    }

    for _, uri in ipairs(paths) do
      it(uri, function()
        assert.False(utils.is_uri(uri))
      end)
    end
  end)

  describe("handles linux paths", function()
    local paths = {
      [[/home/usuario/documents/archivo.txt]],
      [[/var/www/html/index.html]],
      [[/mnt/backup/backup_file.tar.gz]],
    }

    for _, path in ipairs(paths) do
      it(path, function()
        assert.False(utils.is_uri(path))
      end)
    end
  end)

  describe("handles macos paths", function()
    local paths = {
      [[/Users/Usuario/Documents/archivo.txt]],
      [[/Applications/App.app/Contents/MacOS/app_executable]],
      [[/Volumes/ExternalDrive/Data/file.xlsx]],
    }

    for _, path in ipairs(paths) do
      it(path, function()
        assert.False(utils.is_uri(path))
      end)
    end
  end)
end)

describe("__separates_file_path_location", function()
  local suites = {
    {
      input = "file.txt:12:4",
      file = "file.txt",
      row = 12,
      col = 4,
    },
    {
      input = "file.txt:12",
      file = "file.txt",
      row = 12,
      col = 0,
    },
    {
      input = "file:12:4",
      file = "file",
      row = 12,
      col = 4,
    },
    {
      input = "file:12:",
      file = "file",
      row = 12,
      col = 0,
    },
    {
      input = "file:",
      file = "file",
    },
  }

  for _, suite in ipairs(suites) do
    it("separtates file path for " .. suite.input, function()
      local file, row, col = utils.__separate_file_path_location(suite.input)

      eq(file, suite.file)
      eq(row, suite.row)
      eq(col, suite.col)
    end)
  end
end)

describe("transform_path", function()
  local cwd = (function()
    if utils.iswin then
      return [[C:\Users\user\projects\telescope.nvim]]
    else
      return "/home/user/projects/telescope.nvim"
    end
  end)()

  local function assert_path(path_display, path, expect)
    local opts = { cwd = cwd, __length = 15 }
    if type(path_display) == "string" then
      opts.path_display = { path_display }
      eq(expect, utils.transform_path(opts, path))
      opts.path_display = { [path_display] = true }
      eq(expect, utils.transform_path(opts, path))
    elseif type(path_display) == "table" then
      opts.path_display = path_display
      eq(expect, utils.transform_path(opts, path))
    elseif type(path_display) == "function" then
      opts.path_display = path_display
      eq(expect, utils.transform_path(opts, path))
    elseif path_display == nil then
      eq(expect, utils.transform_path(opts, path))
    end
  end

  it("handles nil path", function()
    assert_path(nil, nil, "")
  end)

  it("returns back uri", function()
    local uri = [[https://www.example.com/index.html]]
    assert_path(nil, uri, uri)
  end)

  it("handles 'hidden' path_display", function()
    eq("", utils.transform_path({ cwd = cwd, path_display = "hidden" }, "foobar"))
    assert_path("hidden", "foobar", "")
  end)

  it("returns relative path for default opts", function()
    local relative = Path:new { "lua", "telescope", "init.lua" }
    local absolute = Path:new { cwd, relative }
    assert_path(nil, absolute.filename, relative.filename)
    assert_path(nil, relative.filename, relative.filename)
  end)

  it("handles 'tail' path_display", function()
    local path = new_relpath "lua/telescope/init.lua"
    assert_path("tail", path, "init.lua")
  end)

  it("handles 'smart' path_display", function()
    local path1 = new_relpath "lua/telescope/init.lua"
    local path2 = new_relpath "lua/telescope/finders.lua"
    local path3 = new_relpath "lua/telescope/finders/async_job_finder.lua"
    local path4 = new_relpath "plugin/telescope.lua"

    assert_path("smart", path1, path1)
    assert_path("smart", path2, new_relpath "../telescope/finders.lua")
    assert_path("smart", path3, new_relpath "../telescope/finders/async_job_finder.lua")
    assert_path("smart", path4, path4)
  end)

  it("handles 'absolute' path_display", function()
    local relative = Path:new { "lua", "telescope", "init.lua" }
    local absolute = Path:new { cwd, relative }

    -- TODO: feels like 'absolute' should turn relative paths to absolute
    -- assert_path("absolute", relative.filename, absolute.filename)
    assert_path("absolute", absolute.filename, absolute.filename)
  end)

  it("handles default 'shorten' path_display", function()
    assert_path("shorten", new_relpath "lua/telescope/init.lua", new_relpath "l/t/init.lua")
  end)

  it("handles 'shorten' with number", function()
    assert_path({ shorten = 2 }, new_relpath "lua/telescope/init.lua", new_relpath "lu/te/init.lua")
  end)

  it("handles 'shorten' with option table", function()
    assert_path({ shorten = { len = 2 } }, new_relpath "lua/telescope/init.lua", new_relpath "lu/te/init.lua")
    assert_path(
      { shorten = { len = 2, exclude = { 1, 3, -1 } } },
      new_relpath "lua/telescope/builtin/init.lua",
      new_relpath "lua/te/builtin/init.lua"
    )
  end)

  it("handles default 'truncate' path_display", function()
    assert_path({ "truncate" }, new_relpath "lua/telescope/init.lua", new_relpath "…scope/init.lua")
  end)

  it("handles 'filename_first' path_display", function()
    assert_path("filename_first", new_relpath "init.lua", new_relpath "init.lua")
    assert_path("filename_first", new_relpath "lua/telescope/init.lua", new_relpath "init.lua lua/telescope")
  end)

  it("handles 'filename_first' path_display with the option to reverse directories", function()
    assert_path({ filename_first = { reverse_directories = true } }, new_relpath "init.lua", new_relpath "init.lua")
    assert_path(
      { filename_first = { reverse_directories = true } },
      new_relpath "lua/telescope/init.lua",
      new_relpath "init.lua telescope/lua"
    )
    assert_path({ filename_first = { reverse_directories = false } }, new_relpath "init.lua", new_relpath "init.lua")
    assert_path(
      { filename_first = { reverse_directories = false } },
      new_relpath "lua/telescope/init.lua",
      new_relpath "init.lua lua/telescope"
    )
  end)

  it("handles function passed to path_display", function()
    assert_path(function(_, path)
      return string.gsub(path, "^doc", "d")
    end, new_relpath "doc/mydoc.md", new_relpath "d/mydoc.md")
  end)
end)

describe("path_tail", function()
  local function assert_tails(paths)
    for _, path in ipairs(paths) do
      it("gets the tail of " .. path, function()
        local tail = vim.fn.fnamemodify(path, ":p:t")
        eq(tail, utils.path_tail(path))
      end)
    end
  end

  if jit and jit.os:lower() == "windows" then
    describe("handles windows paths", function()
      local paths = {
        [[C:\Users\username\AppData\Local\nvim-data\log]],
        [[D:\Projects\project_folder\source_code.py]],
        [[E:\Music\song.mp3]],
        [[/home/usuario/documents/archivo.txt]],
        [[/var/www/html/index.html]],
        [[/mnt/backup/backup_file.tar.gz]],
      }

      assert_tails(paths)
    end)
  elseif jit and jit.os:lower() == "linux" then
    describe("handles linux paths", function()
      local paths = {
        [[/home/usuario/documents/archivo.txt]],
        [[/var/www/html/index.html]],
        [[/mnt/backup/backup_file.tar.gz]],
      }

      assert_tails(paths)
    end)
  elseif jit and jit.os:lower() == "osx" then
    describe("handles macos paths", function()
      local paths = {
        [[/Users/Usuario/Documents/archivo.txt]],
        [[/Applications/App.app/Contents/MacOS/app_executable]],
        [[/Volumes/ExternalDrive/Data/file.xlsx]],
      }

      assert_tails(paths)
    end)
  end
end)

describe("split_lines", function()
  local expect = {
    "",
    "",
    "line3 of the file",
    "",
    "line5 of the file",
    "",
    "",
    "line8 of the file, last line of file",
    "",
  }

  local function get_fake_file(line_ending)
    return table.concat(expect, line_ending)
  end

  local newline_file = get_fake_file "\n"
  local carriage_newline_file = get_fake_file "\r\n"

  if utils.iswin then
    describe("handles files on Windows", function()
      it("reads file with newline only", function()
        assert.are.same(expect, utils.split_lines(newline_file))
      end)
      it("reads file with carriage return and newline", function()
        assert.are.same(expect, utils.split_lines(carriage_newline_file))
      end)
    end)
  else
    describe("handles files on non Windows environment", function()
      it("reads file with newline only", function()
        assert.are.same(expect, utils.split_lines(newline_file))
      end)
    end)
  end
end)
