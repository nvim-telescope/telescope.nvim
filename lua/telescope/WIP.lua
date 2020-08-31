
local finders = require('telescope.finders')
local previewers = require('telescope.previewers')
local pickers = require('telescope.pickers')
local sorters = require('telescope.sorters')

local WIP = {}

WIP.git_diff = function()
  local file_picker = pickers.new {
    previewer = previewers.new_termopen {
      command = "git diff %s"
    },
  }

  file_picker:find {
    prompt = "Git Diff Viewier",

    finder = finders.new {
      static = true,

      fn_command = function()
        return {
          command = 'git',
          args = {'ls-files', '-m'}
        }
      end,
    },

    sorter = sorters.get_norcalli_sorter()
  }
end

-- TODO: Make it so that when you select stuff, it's inserted
-- TODO: Make it so the previewer shows the help text.
WIP.completion = function()
  local results = {}
  for k, v in pairs(vim.api) do
    table.insert(results, k)
  end

  local lsp_reference_finder = finders.new {
    results = results
  }

  -- local reference_previewer = previewers.qflist
  local reference_picker = pickers.new {
    -- previewer = reference_previewer
  }

  reference_picker:find {
    prompt = 'LSP References',
    finder = lsp_reference_finder,
    sorter = sorters.get_norcalli_sorter(),
  }
end

-- TODO: Use tree sitter to get "everything" in your current scope / file / etc.
-- Fuzzy find ofver it, go to its definition.

return WIP
