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

local Stack = {}
Stack.__index = Stack

function Stack.new(init)
  local self = setmetatable({}, Stack)
  if init ~= nil then
    self:push(init)
  end
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

function Stack:last()
  return self[#self]
end

-- helper function to recurse with more arguments
-- remember contains the actual tree that is remembered so we can use it with ..
-- selections contains only the display so we can pass it into the callback
local function go(tree, opts, root, remember, selections)
  opts.entry_maker = opts.entry_maker or make_entry.gen_from_node(opts)

  pickers.new(opts, {
    prompt_title = tree.title or root.title,
    finder = finders.new_table {
      results = tree.t,
      entry_maker = opts.entry_maker
    },
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr)
      actions._goto_file_selection:replace(function()
        actions.close(prompt_bufnr)

        local entry = actions.get_selected_entry()

        if entry.is_leaf then

          -- .. means go back
          if entry.value == ".." then
            -- first pop is the one you are currently in
            remember:pop()
            -- the last one is the last tree selected, but do not pop off, we want it to be available for the next prompt
            local last = remember:last()

            -- pop current selection because we went back
            selections:pop()

            go(last, opts, root, remember, selections)
            api.nvim_input('i')
            return
          end

          remember:push(entry.value)
          selections:push(entry.value)

          local callback = entry.callback or root.callback
          callback(selections)
        else
          -- it is a node
          remember:push(entry.value)
          selections:push(entry.display) -- for tree only add display, not full tree

          -- recurse
          go(entry.value, opts, root, remember, selections)

          -- sometimes does not start insert for some reason
          vim.api.nvim_input('i')
        end
      end)

      return true
    end,
  }):find()
end

-- entry point for menu
menu.open = function(root)
  local selections = Stack.new()
  local remember = Stack.new(root)
  local opts = {}

  go(root, opts, root, remember, selections)
end

menu.test = function()
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
  })
end

return menu
