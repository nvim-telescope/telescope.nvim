local Previewer = require('telescope.previewers.previewer')
local term_previewer = require('telescope.previewers.term_previewer')
local buffer_previewer = require('telescope.previewers.buffer_previewer')

local previewers = {}

previewers.new = function(...)
  return Previewer:new(...)
end

previewers.new_termopen_previewer = term_previewer.new_termopen_previewer
previewers.cat                    = term_previewer.cat
previewers.vimgrep                = term_previewer.vimgrep
previewers.qflist                 = term_previewer.qflist

previewers.new_buffer_previewer   = buffer_previewer.new_buffer_previewer
previewers.buffer_previewer_maker = buffer_previewer.file_maker
previewers.vim_buffer_cat         = buffer_previewer.cat
previewers.vim_buffer_vimgrep     = buffer_previewer.vimgrep
previewers.vim_buffer_qflist      = buffer_previewer.qflist
previewers.git_branch_log         = buffer_previewer.git_branch_log
previewers.git_commit_diff        = buffer_previewer.git_commit_diff
previewers.git_file_diff          = buffer_previewer.git_file_diff
previewers.ctags                  = buffer_previewer.ctags
previewers.builtin                = buffer_previewer.builtin
previewers.help                   = buffer_previewer.help
previewers.man                    = buffer_previewer.man
previewers.autocommands           = buffer_previewer.autocommands
previewers.highlights             = buffer_previewer.highlights
previewers.display_content        = buffer_previewer.display_content

previewers.Previewer = Previewer

return previewers
