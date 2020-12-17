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
  self.title = opts.title or 'Menu'

  table.insert(self.t, "..")

  return self
end

Node.new_root = function(opts)
  dump(opts)
  local self = setmetatable({}, Node)

  self.t = opts[1]
  if opts.callback == nil then
    error "Root node must have default callback"
  else
    self.callback = opts.callback
  end
  self.title = opts.title or 'Menu'

  return self
end

menu.Node = Node

local function preprocess(tree, root)
  local results = {}

  for k, v in pairs(tree) do
    if type(v) == "string" then -- leaf
      table.insert(results, { leaf = v, root = root }) -- and have each element have the table. So you also have it when we hit enter
    elseif type(k) == "string" then
      table.insert(results, { branch = k, root = root }) -- when selecting you can then just check if branch is not nil. if thats the case the restart menu
    else
      -- we should never get here. Am i correct?
    end
  end

  table.insert(results, { branch = '..', root = root })

  return results
end

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
    local node = tree
    dump(node)

    if root == nil then
      root = node
    end

    pickers.new(opts, {
      prompt_title = node.title,
      finder = finders.new_tree {
        results = node.t,
      },
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(prompt_bufnr)
        actions._goto_file_selection:replace(function()
          actions.close(prompt_bufnr)

          local entry = actions.get_selected_entry()
          local value = entry.value
          local key = entry.key

          if value == nil then
            -- it is a leaf
            if key == ".." then
              local last = selections:pop()
              if selections:is_empty() then
                menu.open(root)
              else
                menu.open(root[last])
              end
              api.nvim_input('i')
              return
            end

            selections:push(key)
            local callback = node.callback or root.callback
            callback(selections)

            cleanup()

          elseif type(value) == "table" then
            -- it is a node
            selections:push(key)
            -- recurse
            menu.open(value, opts)
            -- sometimes does not start insert for some reason
            vim.api.nvim_input('i')
          else
            error "value must be leaf or table"
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
