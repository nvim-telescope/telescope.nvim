RELOAD('telescope')

local sorter = require('telescope.sorters').get_fuzzy_file()

-- Test for tail.
assert(sorter:score("aaa", "aaa/bbb") > sorter:score("aaa", "bbb/aaa"))
assert(
  sorter:score("path", "/path/to/directory/file.txt")
  > sorter:score("path", "/file/to/directory/path.txt")
)

-- Matches well for UpperCase (basically just bonus points for having uppercase letters)
assert(sorter:score("AAA", "/blah/this/aaa/that") > sorter:score("AAA", "/blah/this/AAA/that"))

-- TODO: Determine our strategy for these
-- TODO: Make it so that capital letters count extra for being after a path sep.
-- assert(sorter:score("ftp", "/folder/to/python") > sorter:score("FTP", "/folder/to/python"))

-- TODO: Make it so that 
-- assert(sorter:score("build", "/home/tj/build/neovim") > sorter:score("htbn", "/home/tj/build/neovim"))
