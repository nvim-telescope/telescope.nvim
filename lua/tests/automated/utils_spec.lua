local utils = require "telescope.utils"

describe("is_uri", function()
  it("detects valid uris", function()
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
      assert.True(utils.is_uri(uri))
    end
  end)

  it("handles windows paths", function()
    local paths = {
      [[C:\Users\Usuario\Documents\archivo.txt]],
      [[D:\Projects\project_folder\source_code.py]],
      [[E:\Music\song.mp3]],
    }
    for _, path in ipairs(paths) do
      assert.False(utils.is_uri(path))
    end
  end)

  it("handles linux paths", function()
    local paths = {
      [[/home/usuario/documents/archivo.txt]],
      [[/var/www/html/index.html]],
      [[/mnt/backup/backup_file.tar.gz]],
    }
    for _, path in ipairs(paths) do
      assert.False(utils.is_uri(path))
    end
  end)

  it("handles macos paths", function()
    local paths = {
      [[/Users/Usuario/Documents/archivo.txt]],
      [[/Applications/App.app/Contents/MacOS/app_executable]],
      [[/Volumes/ExternalDrive/Data/file.xlsx]],
    }
    for _, path in ipairs(paths) do
      assert.False(utils.is_uri(path))
    end
  end)
end)
