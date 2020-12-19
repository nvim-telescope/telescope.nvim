local api = vim.api
local actions = require('telescope.actions')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')

local conf = require('telescope.config').values

local menu = {}

--- will mutate table
local function extend_non_number_keys(table, add)
  for k, v in pairs(add) do
    if type(k) == "string" then
      table[k] = v
    end
  end
end

-- takes node syntax and processes it into internal representation,
-- does no fully preprocess root, as that is a special node without a key of string, it is just there
local function process(node)
  local results = {}

  for key, value in pairs(node[1]) do
    if type(key) == "number" then -- leaf

      if type(value) == "string" then

        table.insert(results, {leaf = value, conf = {}})

      elseif type(value) == "table" then
        -- its a leaf with a specific callback and other options

        local processed = {leaf = value[1]}
        -- all non numbers keys are conf for the leaf
        processed.conf = {}
        extend_non_number_keys(processed.conf, value)
        table.insert(results, processed)

      else
        error "BUG: should not get here"
      end

    elseif type(key) == "string" then -- node

      table.insert(value[1], "..")
      local preprocessed = {branch_name = key, branches = process(value)}
      preprocessed.conf = {}
      extend_non_number_keys(preprocessed.conf, value)
      table.insert(results, preprocessed) -- recurse until we hit a leaf

    else
      error "BUG: should not get here"
    end
  end

  return results
end

local function process_root(root)
  local processed = {branches = process(root), branch_name = "root"}
  processed.conf = {}
  extend_non_number_keys(processed.conf, root)

  return processed
end

local Tree = {}
Tree.__index = Tree

function Tree:iter()
end

function Tree:display()
end

function Tree.new(tree_syntax)
  local root = process_root(tree_syntax)
  return setmetatable(root, Tree)
end

menu.process = process
menu.process_root = process_root
menu.Tree = Tree

-- helper function to recurse with more arguments
-- remember contains the actual tree that is remembered so we can use it with ..
-- selections contains only the display so we can pass it into the callback
local function go(tree, opts, remember, selections)
  local root = remember[1]

  opts.entry_maker = opts.entry_maker or make_entry.gen_from_node(opts)

  pickers.new(opts, {
    prompt_title = tree.conf.title or root.conf.title,
    finder = finders.new_table {
      results = tree.branches,
      entry_maker = opts.entry_maker
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions._goto_file_selection:replace(function()
        actions.close(prompt_bufnr)

        local entry = actions.get_selected_entry()

        if entry == nil then
          error "No entry selected"
        end

        if entry.is_leaf then

          -- .. means go back
          if entry.leaf == ".." then
            -- first pop is the one you are currently in
            table.remove(remember)
            -- the last one is the last tree selected, but do not pop off,
            -- we want it to be available for the next prompt
            local last = remember[#remember]

            -- pop current selection because we went back
            table.remove(selections)

            -- no need to process because it is the last one
            go(last, opts, remember, selections)

            api.nvim_input('i')
            return
          end

          table.insert(remember, entry)
          table.insert(selections, entry.leaf)

          local callback = entry.conf.callback or root.conf.callback
          callback(selections)
        else
          -- it is a node
          table.insert(remember, entry)
          table.insert(selections, entry.branch_name)

          -- recurse
          go(entry, opts, remember, selections)

          -- sometimes does not start insert for some reason
          vim.api.nvim_input('i')
        end
      end)

      return true
    end,
  }):find()
end

-- entry point for menu
menu.open = function(opts)
  opts = opts or {}
  opts.tree = process_root(opts.tree)

  local selections = {}

  local remember = {}
  table.insert(remember, opts.tree)

  go(opts.tree, opts, remember, selections)
end

menu.test = function()
  menu.open {
    tree = {
      {
        "hello dude",
        ["a node"] = {
          {
            "a leaf inside of the node",
            "another leaf inside of node",
            ["second level node"] = {
              {
                "leaf inside second level node",
                {
                  "another leaf inside second level node with specific callback",
                  callback = function()
                    print('this is a specific callback')
                  end,
                },
              },
              title = 'this overrides the root title'
            }
          },
          -- no need to speecify title here, it is propagated from the root
        }
      },
      title = 'test menu',
      callback = function(selections)
        for _, selection in ipairs(selections) do
          print(selection)
        end
      end,
    }
  }
end

return menu
