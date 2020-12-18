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

local Leaf = {}
Leaf.__index = Leaf

function Leaf.new(opts)
  local self = setmetatable({}, Leaf)

  self.t = opts[1]
  self.callback = opts.callback

  return self
end

function Node:preprocess()
  local results = {}

  for k, v in pairs(self.t) do
    if type(k) == "number" then -- leaf

      if type(v) == "string" then
        -- its a leaf without a specific callback, just a regular string
        table.insert(results, { leaf = v })
      elseif type(v) == "table" then
        -- its a leaf with a specific callback and other options, a Leaf class
        table.insert(results, { leaf = v.t, callback = v.callback })
      else
        error "BUG: should not get here"
      end

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

function Stack:first()
  return self[1]
end

-- helper function to recurse with more arguments
-- remember contains the actual tree that is remembered so we can use it with ..
-- selections contains only the display so we can pass it into the callback
local function go(tree, opts, remember, selections)
  local root = remember:first()

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

        if entry == nil then
          error "No entry selected"
        end

        if entry.is_leaf then

          -- .. means go back
          if entry.value == ".." then
            -- first pop is the one you are currently in
            remember:pop()
            -- the last one is the last tree selected, but do not pop off,
            -- we want it to be available for the next prompt
            local last = remember:last()

            -- pop current selection because we went back
            selections:pop()

            go(last, opts, remember, selections)

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
          go(entry.value, opts, remember, selections)

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

  go(root, opts, remember, selections)
end

menu.test = function()
  -- all options for default will propagate if they are not specified for inner nodes
  menu.open(Node.new_root {
    {
      "top level leaf",
      "another top level leaf",
      ["a node"] = Node.new {
        {
          "second level leaf",
          "another second level leaf",
          ["second level node"] = Node.new {
            {
              Leaf.new {
                "another third level leaf with specific callback",
                -- this callback will override the default one
                callback = function() print('this is a specific callback') end
              },
              "third level leaf",
            },
            title = 'this title overrides the defualt one'
          }
        }
      }
    },
    -- default callback if not specified for leaf
    -- passed in a stack of all the selections that the user has made
    callback = function(selections)
      for _, selection in ipairs(selections) do
        print(selection)
      end
    end,
    -- this title will be default if title for node is not specified
    title = "testing menu",
  })
end

return menu
