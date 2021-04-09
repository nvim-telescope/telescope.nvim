local a = vim.api

local ns = a.nvim_create_namespace("treesitter/highlighter")
print(ns)
local bufnr = 0

-- P(a.nvim_buf_get_extmarks(bufnr, ns, 0, -1, { details = true }))

local parser = vim.treesitter.get_parser(bufnr, "lua")
local query = vim.treesitter.get_query("lua", "highlights")
P(query)

local root = parser:parse()[1]:root()
print("root", root)

local highlighter = vim.treesitter.highlighter.new(parser)
local highlighter_query = highlighter:get_query("lua")

for id, node, metadata in query:iter_captures(root, bufnr, 0, -1) do
  local row1, col1, row2, col2 = node:range()
  print(highlighter_query.hl_cache[id])
  -- print(id, node, metadata, vim.treesitter.get_node_text(node, bufnr))
  -- print(">>>>", row1, col1, row2, col2)
end
