local api = vim.api
local actions = require('telescope.actions')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')

local conf = require('telescope.config').values

local menu = {}

local Node = {}
Node.__index = Node

Node.new = function(opts)
  local self = setmetatable({}, Node)

  self.t = opts[1]
  self.callback = opts.callback
  self.title = opts.title

  table.insert(self.t, "..")

  return self:preprocess()
end

Node.new_root = function(opts)
  local self = setmetatable({}, Node)

  self.t = opts[1]
  if opts.callback == nil then
    error "Root node must have default callback"
  else
    self.callback = opts.callback
  end
  self.title = opts.title or 'Menu'

  return self:preprocess()
end

Node.new_leaf = function(opts)
  local self = setmetatable({}, Node)

  self.t = { leaf = opts[1] }
  self.callback = opts.callback

  return self
end

function Node:preprocess()
  local results = {}

  if type(self.t) == "string" then
    table.insert(results, { leaf = self.t })
    self.t = results
    return self
  end

  for k, v in pairs(self.t) do
    if type(k) == "number" then -- leaf
      table.insert(results, { leaf = v })
    elseif type(k) == "string" then
      table.insert(results, { branch_name = k, branches = v })
    else
      error "BUG: should not get here"
    end
  end

  self.t = results

  return self
end

menu.Node = Node

do
  local Stack = {}
  Stack.__index = Stack

  function Stack.new(init)
    init = init or {}
    local self = setmetatable(init, Stack)
    return self
  end

  function Stack:push(...)
    local args = {...}
    for _, v in ipairs(args) do
      table.insert(self, v)
    end
  end

  function Stack:is_empty()
    return #self == 0
  end

  function Stack:pop()
    return table.remove(self)
  end

  -- the selections that the user has made, used for .., includes the entire tree in order to recurse
  local remember = Stack.new()
  -- the selections that the user has made, only the display, does not include the entire tree
  local selections = Stack.new()
  local root

  -- cleanup the state
  local function cleanup()
    root = nil
    remember = Stack.new()
    selections = Stack.new()
  end

  menu.open = function(tree, opts)
    opts = opts or {}

    opts.entry_maker = make_entry.gen_from_node(opts)

    local node = tree

    if root == nil then
      root = node
    end

    pickers.new(opts, {
      prompt_title = node.title,
      finder = finders.new_table {
        results = node.t,
        entry_maker = opts.entry_maker
      },
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr)
        actions._goto_file_selection:replace(function()
          actions.close(prompt_bufnr)

          local entry = actions.get_selected_entry()

          if entry.is_leaf then

            if entry.value == ".." then
              -- first pop is the one you are currently in
              remember:pop()
              -- second pop is the last one
              local last = remember:pop()

              -- if there is no last one, just open the root
              if last == nil then
                menu.open(root)
              else
                menu.open(last)
              end
              api.nvim_input('i')
              return
            end

            remember:push(entry.value)
            selections:push(entry.value)

            local callback = entry.callback or root.callback
            callback(selections)

            cleanup()
          else
            -- it is a node
            remember:push(entry.value)
            selections:push(entry.display) -- for tree only add display, not full tree

            -- recurse
            menu.open(entry.value, opts)
            -- sometimes does not start insert for some reason
            vim.api.nvim_input('i')
          end
        end)

        return true
      end,
    }):find()
  end
end

menu.test = function(opts)
  menu.open(Node.new_root {
    {
      "a leaf",
      "another_leaf",
      another_node = Node.new {
        {
          "inner",
          "inner2",
          second_level_node = Node.new {
            {
              -- Node.new_leaf {"inner inner leaf", callback = function() print('this is a specific callback') end},
              "another inner inner leaf",
            }
          }
        }
      }
    },
    callback = function(selections)
      for _, selection in ipairs(selections) do
        print(selection)
      end
    end,
    title = "testing",
  }, opts)
end

return menu
