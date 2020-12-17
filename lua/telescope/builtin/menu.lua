local api = vim.api
local actions = require('telescope.actions')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local path = require('telescope.path')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')
local sorters = require('telescope.sorters')
local utils = require('telescope.utils')

local conf = require('telescope.config').values

local filter = vim.tbl_filter

local menu = {}

Node = {}
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

  self.t = opts[1]
  self.callback = opts.callback

  return self:preprocess()
end

function Node:preprocess()
  local results = {}

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
    local args = vim.tbl_flatten {...}
    for _, v in ipairs(args) do
      table.insert(self, v)
    end
  end

  function Stack:is_empty()
    return (#(self.t or {})) == 0
  end

  function Stack:pop()
    table.remove(self)
  end

  local selections = Stack.new()
  local root

  -- cleanup the state
  local function cleanup()
    root = nil
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
              local last = selections:pop()
              if selections:is_empty() then
                menu.open(root)
              else
                menu.open(root[last])
              end
              api.nvim_input('i')
              return
            end

            selections:push(entry.value)
            local callback = node.callback or root.callback
            callback(selections)

            cleanup()
          else
            -- it is a node
            selections:push(entry.value)
            -- recurse
            opts.prompt_title = entry.value.title or root.title
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
      "blah",
      another_node = Node.new {
        {
          "inner",
          "inner2",
        }
      }
    },
    callback = function(selections)
      dump(selections)
    end,
    title = "testing",
  }, opts)
  -- menu.menu {
  --   n = Node.new_root {
  --     t = {
  --       "a_leaf",
  --       "another_leaf",
  --       "blah",
  --       ["1 level deep node"] = Node.new_root {
  --         t = {
  --           "leaf",
  --           "another_leaf",
  --           "inside_a_node",
  --         }
  --       },
  --       ["2 level deep node"] = {
  --         t = {
  --           "leaf",
  --           "another_leaf",
  --           "inside_a_node",
  --           node_inside_node = Node.new_root {
  --             t = {
  --               "final_leaf",
  --             }
  --           },
  --         }
  --       },
  --     },
  --   },
  --   title = 'test menu',
  --   callback = function(selections)
  --     print("test callback selection:", selections[#selections])
  --   end
  -- }
end

return menu
