-- fzf's query syntax on top of the matcher (`telescope.algos.matcher`), parsed as fzf does (see its
-- README, "Search syntax"):
--
--   sbtrkt     fuzzy match            'wild     exact match (substring)
--   'wild'     exact match at word boundaries
--   ^music     prefix (exact)         .mp3$     suffix (exact)          ^foo$   equal (exact)
--   !fire      inverse exact          !^music   inverse prefix          !.mp3$  inverse suffix
--   !'fire     inverse fuzzy
--
-- Terms are separated by spaces (`\ ` is a literal space) and must all match; `|` between terms
-- makes them alternatives (`^core go$ | rb$ | py$`). Case: per term, from `case_mode` (`smart_case`:
-- case sensitive if the term contains an uppercase letter). Prefix, suffix and equal terms ignore
-- leading and trailing whitespace of the entry unless they start or end with whitespace themselves.
--
-- A query is a list of sets (all must match), each a list of terms (alternatives, the first match
-- counts). The score is the sum of the matcher's scores of the matched terms; inverse terms add no
-- score and no highlights.

local matcher = require "telescope.algos.matcher"

local byte = string.byte

local M = {}

local FUZZY, EXACT, BOUNDARY, PREFIX, SUFFIX, EQUAL = "fuzzy", "exact", "boundary", "prefix", "suffix", "equal"

--- Parse `prompt` (see above) into a query. `query.single` is set if it is a single fuzzy term.
---@param prompt string
---@param case_mode? string: "ignore_case" (default), "respect_case", or "smart_case"
---@return table
function M.parse(prompt, case_mode)
  local str = prompt:gsub("\\ ", "\t"):gsub("^ +", ""):gsub(" +$", "")
  local query, set, after_bar = {}, nil, false
  for token in str:gmatch "[^ ]+" do
    local text = token:gsub("\t", " ")
    if set and not after_bar and text == "|" then
      after_bar = true
    else
      local cs = case_mode == "respect_case" or (case_mode == "smart_case" and text:find "[A-Z]" ~= nil)
      local typ, inv = FUZZY, false
      if text:sub(1, 1) == "!" then
        typ, inv, text = EXACT, true, text:sub(2)
      end
      if text ~= "$" and text:sub(-1) == "$" then
        typ, text = SUFFIX, text:sub(1, -2)
      end
      if #text > 2 and text:sub(1, 1) == "'" and text:sub(-1) == "'" then
        typ, text = BOUNDARY, text:sub(2, -2)
      elseif text:sub(1, 1) == "'" then
        typ, text = inv and FUZZY or EXACT, text:sub(2)
      elseif text:sub(1, 1) == "^" then
        typ, text = typ == SUFFIX and EQUAL or PREFIX, text:sub(2)
      end
      if #text > 0 then
        -- `plain`: no letters, so case doesn't matter (and the matcher's search is faster)
        local term = { type = typ, inv = inv, text = text, cs = cs, plain = cs or not text:find "[A-Za-z]" }
        if set and after_bar then
          set[#set + 1] = term
        else
          set = { term }
          query[#query + 1] = set
        end
      end
      after_bar = false
    end
  end
  query.single = #query == 1 and #query[1] == 1 and query[1][1].type == FUZZY and not query[1][1].inv
  return query
end

local function is_space(b)
  return b == 32 or (b >= 9 and b <= 13)
end

local function is_alnum(b)
  return (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or b >= 128
end

--- Find `term` in `line`: the byte range of the match (true for fuzzy terms), or nil.
local function find_term(term, line)
  local typ, text = term.type, term.text
  if typ == FUZZY then
    return matcher.has_match(text, line, term.cs) or nil
  end
  local cs = term.plain
  local n, len = #text, #line
  if typ == EXACT or typ == BOUNDARY then
    local at = matcher.find(text, line, cs)
    while at do
      local finish = at + n - 1
      if
        typ == EXACT
        or ((at == 1 or not is_alnum(byte(line, at - 1))) and (finish == len or not is_alnum(byte(line, finish + 1))))
      then
        return at, finish
      end
      at = matcher.find(text, line, cs, at + 1)
    end
    return nil
  end
  -- prefix, suffix, equal: ignore surrounding whitespace of the line, unless the term has it
  local first, last = 1, len
  if typ ~= SUFFIX and not is_space(byte(text, 1)) then
    while first <= len and is_space(byte(line, first)) do
      first = first + 1
    end
  end
  if typ ~= PREFIX and not is_space(byte(text, n)) then
    while last >= first and is_space(byte(line, last)) do
      last = last - 1
    end
  end
  local at = typ == SUFFIX and last - n + 1 or first
  if (typ == EQUAL and last - first + 1 ~= n) or not matcher.match_at(text, line, at, cs) then
    return nil
  end
  return at, at + n - 1
end

-- The first term of `set` that matches `line` (an inverse term matches if it isn't found), with the
-- byte range of the match.
local function match_set(set, line)
  for k = 1, #set do
    local term = set[k]
    local at, finish = find_term(term, line)
    if (not at) == term.inv then
      return term, at, finish
    end
  end
end

-- the matched term of each set (reused): `score` first checks that all sets match (cheap), and
-- only then scores the matched terms (the expensive part)
local matched = {}

--- The score of `line` for `query` (sum over the sets, see above), or nil if it doesn't match.
function M.score(query, line)
  for i = 1, #query do
    matched[i] = match_set(query[i], line)
    if not matched[i] then
      return nil
    end
  end
  local total = 0
  for i = 1, #query do
    local term = matched[i]
    if not term.inv then
      total = total + matcher.score(term.text, line, term.cs)
    end
  end
  return total
end

--- Byte positions in `line` to highlight for `query`: those of the matched terms of each set that
--- matches (sets are independent here: the display can differ from the ordinal that was scored).
function M.positions(query, line)
  local seen = {}
  for _, set in ipairs(query) do
    local term, at, finish = match_set(set, line)
    if term and not term.inv then
      if term.type == FUZZY then
        for _, p in ipairs(matcher.positions(term.text, line, term.cs)) do
          seen[p] = true
        end
      else
        for p = at, finish do
          seen[p] = true
        end
      end
    end
  end
  local positions = vim.tbl_keys(seen)
  table.sort(positions)
  return positions
end

local function same_term(a, b)
  return a.type == b.type and a.inv == b.inv and a.text == b.text and a.cs == b.cs
end

-- whether `new` (the term `old` after typing more) can only match lines that `old` matches
local function term_restricts(new, old)
  if new.inv or old.inv then
    return same_term(new, old)
  end
  if old.cs and not new.cs then
    return false
  end
  local t, o = new.type, old.type
  -- longer fuzzy, exact and prefix terms are stricter, also a fuzzy term that becomes anchored or exact
  if o == FUZZY or (t == o and (t == EXACT or t == PREFIX)) then
    return new.text:sub(1, #old.text) == old.text
  end
  -- longer suffix, equal and boundary terms are not; exact can become boundary, prefix equal
  return new.text == old.text and (t == o or (o == EXACT and t == BOUNDARY) or (o == PREFIX and t == EQUAL))
end

--- Whether `new` can only match lines that `old` matches (so that results of `old` that didn't match
--- can be discarded): the earlier sets are unchanged, the last set of `old` has the same terms with
--- the last one only made stricter, and `new` may add sets.
function M.restricts(new, old)
  if #new < #old then
    return false
  end
  for i = 1, #old do
    local n, o = new[i], old[i]
    if #n ~= #o then
      return false
    end
    for k = 1, #o do
      local last = i == #old and k == #o
      if not (same_term(n[k], o[k]) or (last and term_restricts(n[k], o[k]))) then
        return false
      end
    end
  end
  return true
end

return M
