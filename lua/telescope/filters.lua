local log = require "telescope.log"
-- TODO
--  make defaults for sorters overrideable
--

local util = require "telescope.utils"

local FILTERED = -1

-- filter function
-- tag: string|function
-- filter: function
local filters = {}

-- local substr_matcher = function(prompt, line)
--   local display = line:lower()
--   local search_terms = util.max_split(prompt:lower(), "%s")
--   local matched = 0
--   local total_search_terms = 0
--   for _, word in pairs(search_terms) do
--     total_search_terms = total_search_terms + 1
--     if display:find(word, 1, true) then
--       matched = matched + 1
--     end
--   end
--   return matched == total_search_terms and 0 or FILTERED
-- end

local partial_or_exact_match = function(prompt, line)
  return line:sub(1, #prompt):lower():find(prompt) and 0 or FILTERED
end

filters.tag = function(opts)
  opts = opts or {}
  local scoring_function = vim.F.if_nil(opts.filter_function, partial_or_exact_match)
  local tags_set = util.create_set()
  local tag_cache = {}
  local delimiter = vim.F.if_nil(opts.delimiter, ":")

  return setmetatable({}, {
    -- (table, sorter, prompt, entry)
    __call = function(_, _, prompt, entry)
      -- caching as `tag_maker` might be expensive
      if tag_cache[entry] == nil then
        tag_cache[entry] = opts.tag_maker and opts.tag_maker(entry) or entry[opts.tag]
      end
      local tag = tag_cache[entry]
      tags_set:insert(tag)

      local filter = "^(" .. delimiter .. "(%S+)" .. "[" .. delimiter .. "%s]" .. ")"
      local matched = prompt:match(filter)

      if matched == nil then
        return 0, prompt
      end
      -- clear prompt of tag
      prompt = prompt:sub(#matched + 1, -1)
      local query = vim.trim(matched:gsub(delimiter, ""))
      return scoring_function(query, tag), prompt
    end,
    __index = {
      tags = tags_set,
      delimiter = delimiter,
    },
  })
end

filters.stack = function(cb)
  -- validate all same delimiter
  -- join sets
  return setmetatable({}, {
    -- __call = function(_, _, _, prompt, entry)
    __call = function(_, _, prompt, entry)
      local ret_score = FILTERED
      local ret_prompt
      for _, func in ipairs(cb) do
        local score, filtered_prompt = func(_, prompt, entry)
        if math.max(score, ret_score) == score then
          ret_score = score
          ret_prompt = filtered_prompt
        end
      end
      return ret_score, ret_prompt
    end,
    __index = function(_, k)
      if k == "tags" then
        local tags = {}
        for _, func in ipairs(cb) do
          if func.tags then
            for tag, _ in pairs(func.tags) do
              if tags[tag] ~= true then
                tags[tag] = true
              end
            end
          end
        end
        return tags
      elseif k == "delimiter" then
        local delimiter = cb[1].delimiter
        for _, func in ipairs(cb) do
          assert(delimiter == func.delimiter, "Unified delimiter across filter_functions required.")
        end
        return delimiter
      else
        error "Invalid key"
      end
    end,
  })
end

-- TODO
-- resolve multiple prefilters:
--   - for a given filter - prompt; multiple prefilters could have same prefix
--

return filters
