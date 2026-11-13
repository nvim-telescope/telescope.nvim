local log = require "telescope.log"
local utils = require "telescope.utils"

local sorters = {}

local ngram_highlighter = function(ngram_len, prompt, display)
  local highlights = {}
  display = display:lower()

  for disp_index = 1, #display do
    local char = display:sub(disp_index, disp_index + ngram_len - 1)
    if prompt:find(char, 1, true) then
      table.insert(highlights, {
        start = disp_index,
        finish = disp_index + ngram_len - 1,
      })
    end
  end

  return highlights
end

local FILTERED = -1

local Sorter = {}
Sorter.__index = Sorter

---@class Sorter
--- Sorter sorts a list of results by return a single integer for a line,
--- given a prompt
---
--- Lower number is better (because it's like a closer match)
--- But, any number below 0 means you want that line filtered out.
---@field scoring_function function: Function that has the interface: (sorter, prompt, line): number
---@field tags table: Unique tags collected at filtering for tag completion
---@field filter_function function: Function that can filter results
---@field highlighter function: Highlights results to display them pretty
---@field discard boolean: Whether this is a discardable style sorter or not.
---@field score function: Override the score function if desired.
---@field init function: Function to run when creating sorter
---@field start function: Function to run on every new prompt
---@field finish function: Function to run after every new prompt
---@field destroy function: Functo to run when destroying sorter
function Sorter:new(opts)
  opts = opts or {}

  return setmetatable({
    score = opts.score,
    state = {},
    tags = opts.tags,

    -- State management
    init = opts.init,
    start = opts.start,
    finish = opts.finish,
    destroy = opts.destroy,
    _status = nil,

    filter_function = opts.filter_function,
    scoring_function = opts.scoring_function,
    highlighter = opts.highlighter,
    discard = opts.discard,
    _discard_state = {
      filtered = {},
      prompt = "",
    },
  }, Sorter)
end

function Sorter:_init()
  self._status = "init"
  if self.init then
    self:init()
  end
end

function Sorter:_destroy()
  self._status = "destroy"
  if self.destroy then
    self:destroy()
  end
end

-- Discards (entries the previous prompt filtered out) are kept while the prompt is extended, and
-- reset otherwise. The picker then also scores only the previous matches (`Picker:_narrowable`);
-- after deleting characters, everything is scored again.
function Sorter:_start(prompt)
  self._status = "start"
  if self.start then
    self:start(prompt)
  end

  if not self.discard then
    return
  end

  local previous = self._discard_state.prompt
  local len_previous = #previous

  if #prompt < len_previous then
    log.trace "Reset discard because shorter prompt"
    self._discard_state.filtered = {}
  elseif string.sub(prompt, 1, len_previous) ~= previous then
    log.trace "Reset discard no match"
    self._discard_state.filtered = {}
  end

  self._discard_state.prompt = prompt
end

function Sorter:_finish(prompt)
  self._status = "finish"
  if self.finish then
    self:finish(prompt)
  end
end

--- Score `entry` for `prompt` and pass the result to `cb_add(score, entry)`, or to `cb_filter(entry)`
--- if it is filtered out. Without callbacks, return the score (`FILTERED`, i.e. -1, if filtered out).
--- Discards (see `_start`) are only used and recorded when called with `cb_filter`, as the picker
--- does; a call without it scores the entry on its own.
function Sorter:score(prompt, entry, cb_add, cb_filter)
  if not entry or not entry.ordinal then
    return
  end

  if self._status and self._status ~= "start" then
    return
  end

  local ordinal = entry.ordinal
  local discard = self.discard and cb_filter ~= nil
  if discard and self:_was_discarded(prompt, entry) then
    return cb_filter(entry)
  end

  local filter_score
  if self.filter_function ~= nil then
    if self.tags then
      self.tags:insert(entry)
    end
    filter_score, prompt = self:filter_function(prompt, entry, cb_add, cb_filter)
  end

  if filter_score == FILTERED then
    if cb_filter then
      return cb_filter(entry)
    end
    return FILTERED
  end

  local score = self:scoring_function(prompt or "", ordinal, entry, cb_add, cb_filter)
  if score == FILTERED then
    if not cb_filter then
      return FILTERED
    end
    if discard then
      self:_mark_discarded(prompt, entry)
    end
    return cb_filter(entry)
  end

  if cb_add then
    return cb_add(score, entry)
  else
    return score
  end
end

-- A discarded entry is stamped with the current `_discard_state.filtered` table, so that replacing
-- that table (on a prompt that doesn't extend the previous one, or by a sorter's `start`) forgets all
-- discards at once, and marking needs no hash insert per entry.
function Sorter:_was_discarded(_, entry)
  return self.discard and rawget(entry, "_discarded") == self._discard_state.filtered
end

function Sorter:_mark_discarded(_, entry)
  if not self.discard then
    return
  end

  rawset(entry, "_discarded", self._discard_state.filtered)
end

function sorters.new(...)
  return Sorter:new(...)
end

sorters.Sorter = Sorter

---@return table<string, string>
local make_cached_tail = function()
  local match_string = "[^/]*$"
  return setmetatable({}, {
    __index = function(t, k)
      local tail = string.match(k, match_string)

      rawset(t, k, tail)
      return tail
    end,
  })
end

---@return table<string, table<integer, true>>
local make_cached_uppers = function()
  return setmetatable({}, {
    __index = function(t, k)
      local obj = {}
      for i = 1, #k do
        local s_byte = k:byte(i, i)
        if s_byte <= 90 and s_byte >= 65 then
          obj[s_byte] = true
        end
      end

      rawset(t, k, obj)
      return obj
    end,
  })
end

-- the overlapping n-grams of a string
local make_cached_ngrams = function(n)
  return setmetatable({}, {
    __index = function(t, k)
      local ngrams = {}
      for i = 1, #k - n + 1 do
        ngrams[i] = k:sub(i, i + n - 1)
      end

      rawset(t, k, ngrams)
      return ngrams
    end,
  })
end

-- how many of `ngrams` occur in `line`, and how many of those occur after the previous match
local match_ngrams = function(ngrams, line)
  local match_count, consecutive_matches, previous_match_index = 0, 0, 0
  for i = 1, #ngrams do
    local match_start = line:find(ngrams[i], 1, true)
    if match_start then
      match_count = match_count + 1
      if match_start > previous_match_index then
        consecutive_matches = consecutive_matches + 1
      end
      previous_match_index = match_start
    end
  end
  return match_count, consecutive_matches
end

sorters.get_fuzzy_file = function(opts)
  opts = opts or {}

  local ngram_len = opts.ngram_len or 2

  local cached_ngrams = make_cached_ngrams(ngram_len)

  local cached_tails = make_cached_tail()
  local cached_uppers = make_cached_uppers()

  return Sorter:new {
    scoring_function = function(_, prompt, line)
      local N = #prompt

      if N == 0 or N < ngram_len then
        return 1
      end

      local prompt_lower = prompt:lower()
      local line_lower = line:lower()

      local prompt_lower_ngrams = cached_ngrams[prompt_lower]

      -- Contains the original string
      local contains_string = line_lower:find(prompt_lower, 1, true)

      local prompt_uppers = cached_uppers[prompt]
      local line_uppers = cached_uppers[line]

      local uppers_matching = 0
      for k, _ in pairs(prompt_uppers) do
        if line_uppers[k] then
          uppers_matching = uppers_matching + 1
        end
      end

      local tail = cached_tails[line_lower]
      local contains_tail = tail:find(prompt_lower, 1, true)

      local match_count, consecutive_matches = match_ngrams(prompt_lower_ngrams, line_lower)

      local tail_modifier = 1
      if contains_tail then
        tail_modifier = 2
      end

      local denominator = (
        (10 * match_count / #prompt_lower_ngrams)
        -- biases for shorter strings
        + 3 * match_count * ngram_len / #line
        + consecutive_matches
        + N / (contains_string or (2 * #line))
        -- + 30/(c1 or 2*N)
        + uppers_matching
      ) * tail_modifier

      if denominator == 0 or denominator ~= denominator then
        return -1
      end

      if #prompt > 2 and denominator < 0.5 then
        return -1
      end

      return 1 / denominator
    end,

    highlighter = opts.highlighter or function(_, prompt, display)
      return ngram_highlighter(ngram_len, prompt, display)
    end,
  }
end

sorters.get_generic_fuzzy_sorter = function(opts)
  opts = opts or {}

  local ngram_len = opts.ngram_len or 2

  local cached_ngrams = make_cached_ngrams(ngram_len)

  return Sorter:new {
    -- self
    -- prompt (which is the text on the line)
    -- line (entry.ordinal)
    -- entry (the whole entry)
    scoring_function = function(_, prompt, line, _)
      if #prompt < ngram_len then
        return 1
      end

      local prompt_lower = prompt:lower()
      local line_lower = line:lower()

      local prompt_ngrams = cached_ngrams[prompt_lower]

      local N = #prompt

      local contains_string = line_lower:find(prompt_lower, 1, true)

      local match_count, consecutive_matches = match_ngrams(prompt_ngrams, line_lower)

      -- formula by ashkan
      local denominator = (
        (10 * match_count / #prompt_ngrams)
        -- biases for shorter strings (note: this can bias towards repeated finds of the same
        -- subpattern with overlapping n-grams)
        + 3 * match_count * ngram_len / #line
        + consecutive_matches
        + N / (contains_string or (2 * #line)) -- + 30/(c1 or 2*N)

      )

      if denominator == 0 or denominator ~= denominator then
        return -1
      end

      if #prompt > 2 and denominator < 0.5 then
        return -1
      end

      return 1 / denominator
    end,

    highlighter = opts.highlighter or function(_, prompt, display)
      return ngram_highlighter(ngram_len, prompt, display)
    end,
  }
end

sorters.fuzzy_with_index_bias = function(opts)
  opts = opts or {}
  opts.ngram_len = 2

  local fuzzy_sorter = sorters.get_generic_fuzzy_sorter(opts)

  return Sorter:new {
    scoring_function = function(_, prompt, line, entry, cb_add, cb_filter)
      local base_score = fuzzy_sorter:scoring_function(prompt, line, entry, cb_add, cb_filter)

      if base_score == FILTERED then
        return FILTERED
      end

      return math.min(entry.index ^ 0.25, 2) * base_score
    end,
    highlighter = fuzzy_sorter.highlighter,
  }
end

local fzy_case_modes = { ignore_case = true, respect_case = true, smart_case = true }

-- Sorter using the fzy algorithm (`telescope.algos.matcher`) with fzf's query syntax
-- (`telescope.algos.query`): space-separated terms that must all match, `'exact`, `^prefix`,
-- `suffix$`, `!inverse`, `a | b` alternatives.
-- `opts.case_mode` (as for telescope-fzf-native): "ignore_case" (default), "respect_case", or
-- "smart_case" (per term: respect case if it contains an uppercase letter); only for ASCII letters.
sorters.get_fzy_sorter = function(opts)
  opts = opts or {}
  local matcher = require "telescope.algos.matcher"
  local query = require "telescope.algos.query"
  local OFFSET = -matcher.get_score_floor()
  local SCORE_MIN = matcher.get_score_min()
  local case_mode = opts.case_mode or "ignore_case"
  assert(fzy_case_modes[case_mode], "invalid case_mode: " .. tostring(case_mode))

  local last_prompt ---@type string?
  local last_query ---@type telescope.algos.query.Query
  local function parse(prompt)
    if prompt ~= last_prompt then
      last_prompt, last_query = prompt, query.parse(prompt, case_mode)
    end
    return last_query
  end

  return sorters.Sorter:new {
    discard = true,

    -- Discarding (and narrowing to the previous matches) needs a query that can only match fewer
    -- lines than the previous one; for others (e.g. a longer inverse term, a new alternative),
    -- forget the discards.
    start = function(self, prompt)
      local q = parse(prompt)
      if self.state.query and not query.restricts(q, self.state.query) then
        self._discard_state.filtered = {}
      end
      self.state.query = q
    end,

    scoring_function = function(_, prompt, line)
      local q = parse(prompt)
      local score ---@type number
      if q.single then
        -- a single fuzzy term: check for a match before running the scoring algorithm
        local term = q[1][1] --[[@as telescope.algos.query.Term]]
        if not matcher.has_match(term.text, line, term.cs) then
          return -1
        end
        score = matcher.score(term.text, line, term.cs)
      elseif #q == 0 then
        return 1
      else
        local s = query.score(q, line)
        if not s then
          return -1
        end
        score = s
      end

      -- The score is -inf for empty queries and overlong strings. Since this function converts
      -- all scores into the range (0, 1), convert these to 1 as a suitable "worst score" value.
      if score == SCORE_MIN then
        return 1
      end

      -- Poor non-empty matches can also have negative values. Offset the score (per set of terms,
      -- whose scores add up) so that all values are positive, then invert to match the
      -- telescope.Sorter "smaller is better" convention. Note that for exact matches, the score is
      -- +inf, which when inverted becomes 0.
      return 1 / (score + OFFSET * #q)
    end,

    highlighter = function(_, prompt, display)
      local q = parse(prompt)
      if q.single then
        local term = q[1][1] --[[@as telescope.algos.query.Term]]
        return matcher.positions(term.text, display, term.cs)
      end
      return query.positions(q, display)
    end,
  }
end

sorters.highlighter_only = function()
  local matcher = require "telescope.algos.matcher"
  return Sorter:new {
    scoring_function = function()
      return 1
    end,

    highlighter = function(_, prompt, display)
      return matcher.positions(prompt, display)
    end,
  }
end

sorters.empty = function()
  return Sorter:new {
    scoring_function = function()
      return 1
    end,
  }
end

-- Bad & Dumb Sorter
sorters.get_levenshtein_sorter = function()
  return Sorter:new {
    scoring_function = function(_, prompt, line)
      return require "telescope.algos.string_distance"(prompt, line)
    end,
  }
end

local substr_highlighter = function(make_display)
  return function(_, prompt, display)
    local highlights = {}
    display = make_display(prompt, display)

    local search_terms = utils.max_split(prompt, "%s")
    local hl_start, hl_end

    for _, word in pairs(search_terms) do
      hl_start, hl_end = display:find(word, 1, true)
      if hl_start then
        table.insert(highlights, { start = hl_start, finish = hl_end })
      end
    end

    return highlights
  end
end

sorters.get_substr_matcher = function()
  ---@type fun(prompt: string, display: string): string
  local make_display = vim.o.smartcase
      and function(prompt, display)
        local has_upper_case = not not prompt:match "%u"
        return has_upper_case and display or display:lower()
      end
    or function(_, display)
      return display:lower()
    end

  return Sorter:new {
    highlighter = substr_highlighter(make_display),
    scoring_function = function(_, prompt, _, entry)
      if #prompt == 0 then
        return 1
      end

      local display = make_display(prompt, entry.ordinal)

      local search_terms = utils.max_split(prompt, "%s")
      for _, word in pairs(search_terms) do
        if not display:find(word, 1, true) then
          return -1
        end
      end

      return entry.index
    end,
  }
end

local substr_matcher = function(_, prompt, line, _)
  local display = line:lower()
  local search_terms = utils.max_split(prompt:lower(), "%s")
  local matched = 0
  local total_search_terms = 0
  for _, word in pairs(search_terms) do
    total_search_terms = total_search_terms + 1
    if display:find(word, 1, true) then
      matched = matched + 1
    end
  end

  return matched == total_search_terms and 0 or FILTERED
end

-- the tag at the start of a prompt (e.g. `:function: `)
local function tag_pattern(delimiter)
  return "^(" .. delimiter .. "(%S+)" .. "[" .. delimiter .. "%s]" .. ")"
end

local filter_function = function(opts)
  local scoring_function = vim.nonnil(opts.filter_function, substr_matcher)
  local tag = vim.nonnil(opts.tag, "ordinal")
  local filter = tag_pattern(opts.delimiter)

  return function(_, prompt, entry)
    local matched = prompt:match(filter)

    if matched == nil then
      return 0, prompt
    end
    -- clear prompt of tag
    prompt = prompt:sub(#matched + 1, -1)
    local query = vim.trim(matched:gsub(opts.delimiter, ""))
    return scoring_function(_, query, entry[tag], _), prompt
  end
end

local function create_tag_set(tag)
  tag = vim.nonnil(tag, "ordinal")
  local set = {}
  return setmetatable(set, {
    __index = {
      insert = function(set_, entry)
        local value = entry[tag]
        if not set_[value] then
          set_[value] = true
        end
      end,
    },
  })
end

sorters.prefilter = function(opts)
  local sorter = opts.sorter
  opts.delimiter = vim.nonnil(opts.delimiter, ":")
  sorter._delimiter = opts.delimiter
  sorter.tags = create_tag_set(opts.tag)
  sorter.filter_function = filter_function(opts)
  sorter._was_discarded = function()
    return false
  end
  -- highlight for the prompt without the tag, as it is scored
  local highlighter = sorter.highlighter
  if highlighter then
    local filter = tag_pattern(opts.delimiter)
    sorter.highlighter = function(self, prompt, display)
      local matched = prompt:match(filter)
      return highlighter(self, matched and prompt:sub(#matched + 1) or prompt, display)
    end
  end
  return sorter
end

return sorters
