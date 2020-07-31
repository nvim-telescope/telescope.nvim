
---------------------------
-- bk-tree datastructure
--
-- http://en.wikipedia.org/wiki/BK-tree
-- @module bk-tree
-- @author Robin Hübner
-- robinhubner@gmail.com
-- @release version 1.0.2
-- @license MIT

local bk_tree = {}


local function lazy_copy(t1)

	local cp = {}

	for k, v in pairs(t1) do
		cp[k] = v
	end

	return cp

end

local function min(a, b, c)

	local min_val = a

	if b < min_val then min_val = b end
	if c < min_val then min_val = c end

	return min_val

end

----------------------------------
--- Levenshtein distance function.
-- @tparam string s1
-- @tparam string s2
-- @treturn number the levenshtein distance
-- @within Metrics
function bk_tree.levenshtein_dist(s1, s2)
	
	if s1 == s2 then return 0 end
	if s1:len() == 0 then return s2:len() end
	if s2:len() == 0 then return s1:len() end
	if s1:len() < s2:len() then s1, s2 = s2, s1 end

	t = {}
	for i=1, #s1+1 do
		t[i] = {i-1}
	end

	for i=1, #s2+1 do
		t[1][i] = i-1
	end

	local cost
	for i=2, #s1+1 do
	
		for j=2, #s2+1 do
			cost = (s1:sub(i-1,i-1) == s2:sub(j-1,j-1) and 0) or 1
			t[i][j] = min(
				t[i-1][j] + 1,
				t[i][j-1] + 1,
				t[i-1][j-1] + cost)
		end

	end

	return t[#s1+1][#s2+1]
	
end

function bk_tree.hook(param)

	local name, callee = debug.getlocal(2, 1)
	local f = debug.getinfo(2, "f").func
	local p = debug.getinfo(3, "f").func
	--[[ previous function in the callstack, if called from the same place,
			don't add to the insert/remove counters. ]]--

	if f == bk_tree.insert and p ~= bk_tree.insert then
		callee.stats.nodes = callee.stats.nodes + 1
	elseif f == bk_tree.remove and p ~= bk_tree.remove then
		callee.stats.nodes = callee.stats.nodes - 1
	elseif f == bk_tree.query and p == bk_tree.query then
		callee.stats.queries = callee.stats.queries + 1
	end

end

--- Hooks debugging into tree execution.
-- Keeps track of number of nodes created, queries made,
-- note that this must be run directly after tree is created
-- in order to get correct information.
-- @within Debug
--- @usage
-- local bktree = require "bk-tree"
-- local tree = bktree:new("word")
-- tree:debug()
-- tree:insert("perceive")
-- tree:insert("beautiful")
-- tree:insert("definitely")
-- local result = tree:query("definately", 3)
-- tree:print_stats()
--
-- -- output
-- Nodes: 4
-- Queries: 3
-- Nodes Queried: 75%
function bk_tree:debug()

	local nc = 0
	if self.root then nc = 1 end
	self.stats = { nodes = nc, queries = 0 }
	debug.sethook(self.hook, "c")

end

--- Print execution stats.
-- Prints nodes queried and total nodes, as well as a fraction of 
-- nodes visited to satisfy the query, resets the counter of nodes queried when called.
-- @within Debug
-- @see debug
function bk_tree:print_stats()

	print("\nNodes: " .. self.stats.nodes)
	print("Queries: " .. self.stats.queries)
	print("Nodes Queried: " .. self.stats.queries/self.stats.nodes*100 .. "%\n")
	self.stats.queries = 0

end

--- Fetch execution stats.
-- Returns a copy of the execution stats that @{print_stats} would print, requires debug to have been enabled
-- to not just return defaults. Useful if you want to profile things.
-- @within Debug
-- @return {key = value,...}
function bk_tree:get_stats()

	return lazy_copy(self.stats)

end

---------------------------
--- Creates a new bk-tree.
-- @constructor
-- @string[opt] root_word the root of the new tree
-- @tparam[opt=levenshtein_dist] function dist_func the distance function used
-- @see levenshtein_dist
-- @return the new bk-tree instance
--- @usage
-- local bktree = require "bk-tree"
-- local tree = bktree:new("word")
function bk_tree:new(root_word, dist_func)

	local n_obj = {}
	if root_word then n_obj.root = { str = root_word, children = {} } end
	n_obj.dist_func = dist_func or self.levenshtein_dist

	setmetatable(n_obj, self)
	self.__index = self

	return n_obj

end

--------------------------------
--- Inserts word into the tree.
-- @string word
-- @treturn bool true if inserted, false if word already exists in tree
--- @usage
-- local bktree = require "bk-tree"
-- local tree = bktree:new("root")
-- local success = tree:insert("other_word")
function bk_tree:insert(word, node)

	node = node or self.root

	if not node then
		self.root = { str = word, children = {} }
		return true
	end	

	local dist = self.dist_func(word, node.str)
	if dist == 0 then return false end

	local some_node = node.children[dist]

	if not some_node then
		node.children[dist] = { str = word, children = {} }
		return true
	end	

	return self:insert(word, some_node)

end

--------------------------------
--- Query the tree for matches.
-- @string word
-- @tparam number n max edit distance to use when querying
-- @treturn {{str=string,distance=number},....} table of tables with matching words, empty table if no matches
--- @usage
-- local bktree = require "bk-tree"
-- local tree = bktree:new("word")
-- tree:insert("hello")
-- tree:insert("goodbye")
-- tree:insert("woop")
-- local result = tree:query("woop", 1)
function bk_tree:query(word, n, node, matches)

	node = node or self.root
	matches = matches or {}

	if not node then return matches end

	local dist = self.dist_func(word, node.str)
	if dist <= n then matches[#matches+1] = {str = node.str, distance = dist} end
	
	for k, child in pairs(node.children) do
		if child ~= nil then
			if k >= dist-n and k <= dist+n then
				self:query(word, n, child, matches)
			end
		end
	end

	return matches

end

---------------------------------------------------------
--- Queries the the tree for a match, sorts the results.
-- Calls @{query} and returns the results sorted.
-- @string word
-- @tparam number n max edit distance to use when querying
-- @treturn {{str=string,distance=number},....} table of tables with matching words sorted by distance, empty table if no matches
--- @usage
-- local bktree = require "bk-tree"
-- local tree = bktree:new("word")
-- tree:insert("woop")
-- tree:insert("worp")
-- tree:insert("warp")
-- local result = tree:query_sorted("woop", 3)
function bk_tree:query_sorted(word, n)

	local result = self:query(word, n)

	table.sort(result, function(a,b) return a.distance < b.distance end)

	return result

end


local tree = bk_tree:new("word")
tree:insert("hello")
tree:insert("welp")
tree:insert("function")
tree:insert("this long line what")
tree:insert("what this long line what")
print(vim.inspect(tree))
print(vim.inspect(tree:query_sorted("what", 3)))


return bk_tree
