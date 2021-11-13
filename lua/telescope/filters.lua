local log = require "telescope.log"

-- TODO
--  make defaults for sorters overrideable

local _get_parent = (function()
  local formatted = string.format("^(.+)%s[^%s]+", "/", "/")
  return function(abs_path)
    return abs_path:match(formatted)
  end
end)()

local function convert_reg_to_pos(reg1, reg2)
  -- get {start: 'v', end: curpos} of visual selection 0-indexed
  local pos1 = vim.fn.getpos(reg1)
  local pos2 = vim.fn.getpos(reg2)
  -- (1, 0)-indexed
  return { pos1[2], pos1[3] + pos1[4] + 1 }, { pos2[2], pos2[3] + pos2[4] + 1 }
end

local utils = require "telescope.utils"
local from_entry = require "telescope.from_entry"

local get_dirs
function get_dirs(dirs, flattened_dirs, cwd)
  cwd = cwd or vim.loop.cwd()
  local handle = vim.loop.fs_scandir(cwd)
  if type(handle) == "string" then
    vim.api.nvim.nvim_err_writeln(handle)
    return
  end

  while true do
    local name, t = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end

    if name ~= ".git" then
      local abs = string.format("%s/%s", cwd, name)
      if not t then
        local stat = vim.loop.fs_stat(abs)
        t = stat and stat.type
      end

      if t == "directory" then
        dirs[abs] = cwd
        flattened_dirs[abs] = true
        dirs = get_dirs(dirs, flattened_dirs, abs)
      end
    end
  end
  return dirs
end

local FILTERED = -1

-- filter function
-- tag: string|function
-- filter: function
local filters = {}

local partial_or_exact_match = function(prompt, line)
  return line:sub(1, #prompt):lower():find(prompt) and 0 or FILTERED
end

filters.stack = function(cb)
  -- validate all same delimiter
  -- join sets
  return setmetatable({}, {
    -- __call = function(_, _, _, prompt, entry)
    __call = function(_, _, prompt, entry)
      local ret_score = math.huge
      local ret_prompt
      for _, func in ipairs(cb) do
        local score, filtered_prompt = func(_, prompt, entry)
        if math.min(score, ret_score) == score then
          ret_score = score
          ret_prompt = filtered_prompt
          if ret_score == FILTERED then
            break
          end
        end
      end
      return ret_score, ret_prompt
    end,
    __index = function(_, k)
      if k == "tags" then
        local tags = {}
        for _, func in ipairs(cb) do
          if type(func) == "table" and func.tags then
            for tag, _ in pairs(func.tags) do
              if tags[tag] ~= true then
                tags[tag] = true
              end
            end
          end
        end
        return tags
      elseif k == "delimiter" then
        local delimiter
        for _, func in ipairs(cb) do
          if type(func) == "table" and type(func.delimiter) == "string" then
            if delimiter == nil then
              delimiter = func.delimiter
            end
            assert(delimiter == func.delimiter, "Unified delimiter across filter_functions required.")
          end
        end
        return delimiter
      else
        error "Invalid key"
      end
    end,
  })
end

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

filters.lines = function(opts)
  opts = opts or {}
  -- this will get called before picker instantiation, so should be fine
  local current_buf = vim.api.nvim_get_current_buf()
  if vim.tbl_contains({ "v", "V", "" }, vim.api.nvim_get_mode().mode) then
    local pos1, pos2 = convert_reg_to_pos("v", ".")
    opts.start_line = math.min(pos1[1], pos2[1])
    opts.end_line = math.max(pos1[1], pos2[1])
    -- leaving visual mode required for prompt to be positioned correctly
    vim.cmd [[normal! :esc<CR>]]
  else
    opts.start_line = opts.start_line or 1
    opts.end_line = opts.end_line or math.huge
  end
  return function(_, prompt, entry)
    if entry.bufnr and entry.bufnr ~= current_buf then
      return FILTERED, prompt
    end
    if entry.lnum >= opts.start_line and entry.lnum <= opts.end_line then
      return 0, prompt
    end
    return FILTERED, prompt
  end
end

filters.paths = function(opts)
  opts = opts or {}
  opts.cwd = vim.F.if_nil(opts.cwd, vim.loop.cwd())
  local delimiter = ":"
  flattened_dirs = {}
  tag_cache = {}
  local path_tags = setmetatable({}, {
    __call = function(t, k)
      local ret = { [k] = true }
      while true do
        local value = rawget(t, k)
        if value == nil then
          break
        end
        ret[value] = true
        k = value
      end
      return ret
    end,
  })
  local cached_prompt
  local cached_match
  local cached_query
  local ret_prompt
  get_dirs(path_tags, flattened_dirs, opts.cwd)
  return setmetatable({}, {
    __call = function(_, _, prompt, entry)
      if prompt:sub(1, 1) ~= delimiter then
        return 0, prompt
      end

      if tag_cache[entry] == nil then
        -- local path = string.format("%s/%s", opts.cwd, entry.value)
        -- tag_cache
        tag_cache[entry] = _get_parent(string.format("%s/%s", opts.cwd, entry.value))
      end
      local tag = tag_cache[entry]

      if cached_prompt ~= prompt then
        cached_prompt = prompt
        local filter = "^(" .. delimiter .. "(%S+)" .. "[" .. delimiter .. "%s]" .. ")"
        catched_matched = cached_prompt:match(filter)
        ret_prompt = prompt:sub(#catched_matched + 1, -1)
        cached_query = vim.trim(catched_matched:gsub(delimiter, ""))
      end

      -- clear prompt of tag
      -- local query = vim.trim(matched:gsub(delimiter, ""))
      -- if not path_tags[query] then
      --   return 0, prompt
      -- end
      local valid_dirs = path_tags(tag)
      -- log.warn(valid_dirs)
      if valid_dirs[cached_query] == true then
        return 0, ret_prompt
      else
        return FILTERED, prompt
      end
    end,
    __index = {
      tags = flattened_dirs,
      delimiter = delimiter,
    },
  })
end

filters.treesitter = function(opts)
  local current_buf = vim.api.nvim_get_current_buf()

  local has_nvim_treesitter, _ = pcall(require, "nvim-treesitter")
  if not has_nvim_treesitter then
    print "You need to install nvim-treesitter"
    return
  end

  local has_textobjects, shared = pcall(require, "nvim-treesitter.textobjects.shared")
  if not has_textobjects or shared == nil then
    print "You need to install nvim-treesitter-textobjects"
    return
  end

  opts.textobject = vim.F.if_nil(opts.textobject, "@function.outer")
  -- 0, 0 indexed
  local bufnr, range = shared.textobject_at_point(opts.textobject)
  assert(current_buf == bufnr, "Alarm, alarm")
  local start_line, _, end_line, _ = unpack(range)
  start_line = start_line + 1
  end_line = end_line + 1
  return function(_, prompt, entry)
    if entry.bufnr and entry.bufnr ~= current_buf then
      return FILTERED, prompt
    end
    if entry.lnum >= start_line and entry.lnum <= end_line then
      return 0, prompt
    end
    return FILTERED, prompt
  end
end

filters.allowlist = function(opts)
  assert(opts.allowlist, "Allowlist [array of string] is required!")
  opts.from_entry = utils.get_defaults(opts.from_entry, from_entry.path)
  if type(opts.from_entry) == "string" then
    local key = opts.from_entry
    opts.from_entry = function(tbl)
      return tbl[key]
    end
  end
  return function(_, prompt, entry)
    for _, v in ipairs(opts.allowlist) do
      if opts.from_entry(entry):find(v) then
        return 0, prompt
      end
    end
    return FILTERED, prompt
  end
end

filters.tag = function(opts)
  opts = opts or {}
  local scoring_function = vim.F.if_nil(opts.filter_function, partial_or_exact_match)
  local tags_set = utils.create_set()
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
      local query = vim.trim(matched:gsub(delimiter, ""))
      if tags_set[query] ~= true then
        return 0, prompt
      end

      prompt = prompt:sub(#matched + 1, -1)
      return scoring_function(query, tag), prompt
    end,
    __index = {
      tags = tags_set,
      delimiter = delimiter,
    },
  })
end

-- TODO
-- resolve multiple prefilters:
--   - for a given filter - prompt; multiple prefilters could have same prefix
--

return filters
