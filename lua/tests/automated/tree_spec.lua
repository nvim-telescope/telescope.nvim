local preprocess = require('telescope.builtin.menu').preprocess

local _eq = function(a, b)
  b = preprocess(b)
  assert.are.same(a, b)
end

describe('preprocess function', function()
  it('should preprocess simple', function()
    local tree = {
      {
        "top level leaf",
        "another top level leaf",
      },
    }

    local expected = {
      {
        {leaf = "top level leaf", conf = {}},
        {leaf = "another top level leaf", conf = {}},
      },
      conf = {}
    }

    _eq(expected, tree)
  end)

  it('should preprocess with configuration', function()
    local tree = {
      {
        "top level leaf",
        "another top level leaf",
      },
      title = 'test menu',
      callback = print,
    }

    local expected = {
      {
        {leaf = "top level leaf", conf = {}},
        {leaf = "another top level leaf", conf = {}},
      },
      conf = {
        title = 'test menu',
        callback = print,
      }
    }

    _eq(expected, tree)
  end)

  it('should preprocess with two levels', function()
    local tree = {
      {
        "top level leaf",
        "another top level leaf",
        ["a node"] = {
          {
            "second level leaf",
            "another second level leaf",
          }
        }
      },
    }

    local expected = {
      {
        {leaf = "top level leaf", conf = {}},
        {leaf = "another top level leaf", conf = {}},
        {
          branch_name = "a node",
          branches = {
            {leaf = "second level leaf", conf = {}},
            {leaf = "another second level leaf", conf = {}},
            {leaf = "..", conf = {}},
          },
          conf = {}
        },
      },
      conf = {}
    }

    _eq(expected, tree)
  end)

  it('should preprocess with two levels and conf', function()
    local tree = {
      {
        "top level leaf",
        "another top level leaf",
        ["a node"] = {
          {
            "second level leaf",
            "another second level leaf",
          },
        }
      },
    }

    local expected = {
      {leaf = "top level leaf", conf = {}},
      {leaf = "another top level leaf", conf = {}},
      {
        branch_name = "a node",
        branches = {
          {leaf = "second level leaf", conf = {}},
          {leaf = "another second level leaf", conf = {}},
          {leaf = "..", conf = {}},
          conf = {}
        },
      },
      conf = {}
    }

    -- _eq(expected, tree)
  end)

  it('should preprocess the tree correctly with only one level', function()
    local tree = {
      {
        "top level leaf",
        "another top level leaf",
        ["a node"] = {
          {
            {
              "second level leaf with a specific callback different",
              description = 'this is a description',
              callback = function()
                print("this is a specific callback")
              end,
            },
            "another leaf",
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
    }

    local res = preprocess(tree)

    local expected = {
      {
        {leaf = "top level leaf"},
        {leaf = "another top level leaf"},
        {
          branch_name = "a node",
          branches = {
            {
              leaf = "second level leaf with a specific callback different",
              conf = {
                description = 'this is a description',
                callback = function()
                  print("this is a specific callback")
                end,
              }
            },
            "another leaf",
          },
          conf = {
            title = 'second level title'
          }
        }
      },
      conf = {
        title = 'test menu',
        callback = function(selections)
          for _, selection in pairs(selections) do
            print(selection)
          end
        end
      }
    }

    -- eq(res, expected)
  end)
end)
