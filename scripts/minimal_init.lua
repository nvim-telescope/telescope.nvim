vim.o.rtp = os.getenv "PLENTEST" .. ",.," .. vim.o.rtp
vim.o.rtp = ",../tree-sitter-lua," .. vim.o.rtp

vim.cmd.runtime { "plugin/telescope", bang = true }
vim.g.telescope_test_delay = 100
