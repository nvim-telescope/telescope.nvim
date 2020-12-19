local api = vim.api
local actions = require('telescope.actions')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')

local conf = require('telescope.config').values

local menu = {}

-- takes node
local function preprocess(node)
  print('arg to pairs')
  dump(node[1])
  local results = {}

  for key, value in pairs(node[1]) do
    if type(key) == "number" then -- leaf

      if type(value) == "string" then

        table.insert(results, {leaf = value})

      elseif type(value) == "table" then
        -- its a leaf with a specific callback and other options
        local processed = {}
        processed.leaf = value

        table.insert(results, processed)
      else
        error "BUG: should not get here"
      end

    elseif type(key) == "string" then -- node

      print('value:')
      dump(value)
      table.insert(value[1], "..")

      local processed = {}
      processed.branch_name = key
      processed.branches = value

      table.insert(results, processed)

    else
      error "BUG: should not get here"
    end
  end

  print('results:')
  dump(results)
  return results
end

function menu.node(opts)
  local node = {}
  node.t = opts[1]
  table.insert(node.t, "..") -- add go back
  node.callback = opts.callback
  node.title = opts.title

  return preprocess(node)
end

function menu.root(opts)
  local root = {}

  root.t = opts[1]
  if opts.callback == nil then
    error "Root node must have default callback"
  else
    root.callback = opts.callback
  end
  root.title = opts.title or 'Menu'

  return preprocess(root)
end

function menu.leaf(opts)
  local leaf = {}

  leaf.t = opts[1]
  leaf.callback = opts.callback

  return leaf
end

-- helper function to recurse with more arguments
-- remember contains the actual tree that is remembered so we can use it with ..
-- selections contains only the display so we can pass it into the callback
local function go(tree, opts, remember, selections)
  local root = remember[1]

  opts.entry_maker = opts.entry_maker or make_entry.gen_from_node(opts)

  pickers.new(opts, {
    prompt_title = tree.title or root.title,
    finder = finders.new_table {
      results = tree,
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
          if entry.value == ".." then
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

          table.insert(remember, entry.value)
          table.insert(selections, entry.value)

          dump(root)
          local callback = entry.callback or root.callback
          callback(selections)
        else
          -- it is a node
          dump(entry.value)
          local processed_value = preprocess(entry.value)
          dump(processed_value)
          table.insert(remember, processed_value)
          table.insert(selections, processed_value)

          -- recurse
          go(processed_value, opts, remember, selections)

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
  opts.tree = preprocess(opts.tree)

  local selections = {}

  local remember = {}
  table.insert(remember, opts.tree)

  dump(opts)

  go(opts.tree, opts, remember, selections)
end

-- menu.test = function()
--   -- all options for default will propagate if they are not specified for inner nodes
--   menu.open(menu.root {
--     {
--       "top level leaf",
--       "another top level leaf",
--       ["a node"] = menu.node {
--         {
--           "second level leaf",
--           "another second level leaf",
--           ["second level node"] = menu.node {
--             {
--               menu.leaf {
--                 "another third level leaf with specific callback",
--                 -- this callback will override the default one
--                 callback = function() print('this is a specific callback') end
--               },
--               "third level leaf",
--             },
--             title = 'this title overrides the defualt one'
--           }
--         }
--       }
--     },
--     -- default callback if not specified for leaf
--     -- passed in a stack of all the selections that the user has made
--     callback = function(selections)
--       for _, selection in ipairs(selections) do
--         print(selection)
--       end
--     end,
--     -- this title will be default if title for node is not specified
--     title = "testing menu",
--   })
-- end

menu.test = function()
  menu.open {
    tree = {
      {
        "top level leaf",
        "another top level leaf",
        ["a node"] = {
          -- instead of directly setting the key to the value, we set it to a table of options, [1] is the contents
          {
            "second level leaf",
            "another second level leaf",
            ["second level node"] = {
              {
                -- vs this way, we can have multiple options
                {
                  "third level leaf with a specific callback different",
                  -- for example we might want to set the description
                  description = 'this is a description', -- not implemented yet
                  callback = function()
                    print("this is a specific callback")
                  end,
                },
                "third level leaf",
              },
              -- because it is a table inside of a table, we can set options as the contents of the tree will be node[1]
              -- other options will be anything except [1]
              title = 'this title overrides the defualt one'
            }
          },
          title = 'second level title'
        }
      },
      title = 'test menu',
      callback = function(selections)
        for _, selection in pairs(selections) do
          print(selection)
        end
      end
    },
  }
end

return menu
