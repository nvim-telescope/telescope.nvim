local make_entry = require "telescope.make_entry"
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local finders = require "telescope.finders"
local previewers = require "telescope.previewers"
local pickers = require "telescope.pickers"
local sorters = require "telescope.sorters"

local WIP = {}

WIP.git_diff = function()
  local file_picker = pickers.new {
    previewer = previewers.new_termopen {
      command = "git diff %s",
    },
  }

  file_picker:find {
    prompt = "Git Diff Viewier",

    finder = finders.new {
      static = true,

      fn_command = function()
        return {
          command = "git",
          args = { "ls-files", "-m" },
        }
      end,
    },

    sorter = sorters.get_norcalli_sorter(),
  }
end

-- TODO: Make it so that when you select stuff, it's inserted
-- TODO: Make it so the previewer shows the help text.
WIP.completion = function(opts)
  local results = {}
  for k, _ in pairs(vim.api) do
    table.insert(results, k .. "()")
  end

  local lsp_reference_finder = finders.new {
    results = results,
  }

  -- TODO: Open the help text for the line.
  local reference_picker = pickers.new(opts, {
    prompt = "vim.api Help Reference",
    finder = lsp_reference_finder,
    sorter = sorters.get_norcalli_sorter(),
    previewer = previewers.help,
  })

  reference_picker:find()
end

WIP.reloader = function(opts)
  opts = opts or {}

  pickers.new(opts, {
    prompt = "Packages",
    finder = finders.new_table {
      results = vim.tbl_keys(package.loaded),
      entry_maker = make_entry.gen_from_string(),
    },
    sorter = sorters.get_generic_fuzzy_sorter(),

    attach_mappings = function(prompt_bufnr, map)
      local reload_package = function()
        local selection = action_state.get_selected_entry()

        actions.close(prompt_bufnr)

        print(vim.inspect(selection))
      end

      map("i", "<CR>", reload_package)
      map("n", "<CR>", reload_package)

      return true
    end,
  }):find()
end

-- TODO: Use tree sitter to get "everything" in your current scope / file / etc.
-- Fuzzy find ofver it, go to its definition.

return WIP
