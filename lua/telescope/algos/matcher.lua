-- Fuzzy matching, based on the fzy algorithm
--
-- Based on Seth Warn's <https://github.com/swarn> Lua port of John Hawthorn's fzy
-- <https://github.com/jhawthorn/fzy>, with these adaptations:
-- - Speed: works on bytes (`string.byte`) instead of one-character strings and patterns, keeps
--   only two rows of the score matrices for `score`, and reuses all buffers across calls (no
--   allocation per entry); the lowered needle is cached, and an ASCII-only fast path skips the
--   UTF-8 handling. Apart from the word boundaries below, scores and positions for ASCII text are
--   those of the port.
-- - UTF-8: a character of the needle only matches a whole character of the haystack (the port
--   could match its bytes across different characters), and scores count characters, not bytes.
-- - Case: matching ignores case unless `case_sensitive` (the optional third argument of
--   `has_match`, `score` and `positions`) is true.
-- - Word boundaries: a character after any ASCII character that is not a letter or digit gets the
--   start-of-word bonus (as suggested by Seth Warn, and similar to fzf), not only after `-`, `_`
--   and space; `/` and `.` get a higher one (fzy gave `.` a lower one: here a file extension
--   counts as much as a path component, as in fzf). So `abc` prefers `ant!bat!cat` to
--   `azzzbzzzczz`, and `al` prefers `\alpha` to `\bfAlpha`.
--
-- > fzy tries to find the result the user intended. It does this by favouring
-- > matches on consecutive letters and starts of words. This allows matching
-- > using acronyms or different parts of the path." - J Hawthorn
--
-- Limitations (as in fzf-native): only ASCII letters are case-insensitive (`ä` doesn't match `Ä`),
-- no normalization (`a` doesn't match `ä`, precomposed doesn't match decomposed), word and
-- camelCase bonuses only for ASCII, and the length limit is in bytes.

local byte, find, max = string.byte, string.find, math.max

local SCORE_GAP_LEADING = -0.005
local SCORE_GAP_TRAILING = -0.005
local SCORE_GAP_INNER = -0.01
local SCORE_MATCH_CONSECUTIVE = 1.0
local SCORE_MATCH_SLASH = 0.9
local SCORE_MATCH_WORD = 0.8
local SCORE_MATCH_CAPITAL = 0.7
local SCORE_MATCH_DOT = 0.9
local SCORE_MAX = math.huge
local SCORE_MIN = -math.huge
local MATCH_MAX_LENGTH = 1024

-- bonus for a match, indexed by the previous byte: start of a word after any ASCII character that
-- is not a letter or digit, higher after `/` (paths are normalized to `/`, see `utils.normalize_sep`)
-- and `.` (file extensions); the camelCase bonus is handled in `prepare`
local BONUS = {} ---@type table<integer, number>
for b = 0, 255 do
  local alnum = (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122)
  BONUS[b] = (b < 128 and not alnum) and SCORE_MATCH_WORD or 0
end
BONUS[47] = SCORE_MATCH_SLASH
BONUS[46] = SCORE_MATCH_DOT

-- Byte maps for case folding: `FOLD` lowers A-Z, `SAME` is the identity (case sensitive). The mode
-- only picks the table, so the hot loops have no branch on it (which LuaJIT would compile for
-- whichever mode came first, slowing down the other one).
local FOLD, SAME = {}, {} ---@type table<integer, integer>, table<integer, integer>
for b = 0, 255 do
  FOLD[b] = (b >= 65 and b <= 90) and b + 32 or b
  SAME[b] = b
end

local function is_cont(b)
  return b >= 0x80 and b < 0xC0 -- UTF-8 continuation byte
end

-- The needle, cached by string identity and case sensitivity: bytes (lowered unless case
-- sensitive), continuation flags, and its characters (for `has_match`: a byte for ASCII, else the
-- character's bytes). `lower`: the byte map for the haystack (`FOLD` or `SAME`).
local last_needle, last_case_sensitive, n, needle_ascii, lower = nil, false, 0, true, FOLD
local nb, ncont = {}, {} ---@type table<integer, integer>, table<integer, boolean>
local chars, nchars = {}, 0 ---@type table<integer, integer|string>, integer

local function set_needle(needle, case_sensitive)
  case_sensitive = case_sensitive == true
  if needle == last_needle and case_sensitive == last_case_sensitive then
    return
  end
  last_needle, last_case_sensitive, n, nchars = needle, case_sensitive, #needle, 0
  lower = case_sensitive and SAME or FOLD
  needle_ascii = true
  local i = 1
  while i <= n do
    local c = byte(needle, i)
    if c >= 0x80 then
      needle_ascii = false
    end
    local len = c < 0x80 and 1 or c >= 0xF0 and 4 or c >= 0xE0 and 3 or c >= 0xC0 and 2 or 1
    nchars = nchars + 1
    chars[nchars] = len == 1 and lower[c] or needle:sub(i, i + len - 1)
    for k = i, i + len - 1 do
      local b = byte(needle, k) or 0
      nb[k] = lower[b]
      ncont[k] = k > i
    end
    i = i + len
  end
end

local fzy = {}

function fzy.has_match(needle, haystack, case_sensitive)
  set_needle(needle, case_sensitive)
  local j, m = 1, #haystack
  for k = 1, nchars do
    local c = chars[k]
    if type(c) == "number" then
      while true do
        if j > m then
          return false
        end
        local h = byte(haystack, j)
        j = j + 1
        if lower[h] == c then
          break
        end
      end
    else
      local s = find(haystack, c, j, true)
      if not s then
        return false
      end
      j = s + #c
    end
  end
  return true
end

-- The haystack: bytes (lowered unless case sensitive), match bonuses, continuation flags and the
-- number of characters up to each byte (for the leading gap). Reused across calls.
local hay, bonus, hcont, hidx = {}, {}, {}, {} ---@type table<integer, integer>, table<integer, number>, table<integer, boolean>, table<integer, integer>

-- Only bytes `first` to `last` are prepared (the window in which the needle can match, see `score`).
---@param haystack string
---@param first integer
---@param last integer
---@param m integer
local function prepare(haystack, first, last, m)
  -- the whole haystack decides the ASCII fast path (it counts the leading gap in bytes)
  local ascii = needle_ascii
  for j = 1, first - 1 do
    if byte(haystack, j) >= 0x80 then
      ascii = false
    end
  end
  for j = last + 1, m do
    if byte(haystack, j) >= 0x80 then
      ascii = false
    end
  end
  local prev = first > 1 and byte(haystack, first - 1) or 47 -- the start counts as after `/`
  for j = first, last do
    local c = byte(haystack, j)
    local upper = c >= 65 and c <= 90
    if upper and prev >= 97 and prev <= 122 then
      bonus[j] = SCORE_MATCH_CAPITAL
    else
      bonus[j] = BONUS[prev]
    end
    hay[j] = lower[c]
    ascii = ascii and c < 0x80
    prev = c
  end
  if not ascii then
    -- only needed (and read) without the ASCII fast path
    local chars_seen = 0
    for j = 1, m do
      local cont = is_cont(byte(haystack, j))
      hcont[j] = cont
      if not cont then
        chars_seen = chars_seen + 1
      end
      hidx[j] = chars_seen
    end
  end
  return ascii
end

-- One row of the matrices: `pD`/`pM` are the previous row (needle byte i - 1), `cD`/`cM` are filled.
-- `D[j]` is the best score with needle byte i matched at haystack byte j, `M[j]` the best score up
-- to j. A continuation byte only continues the previous byte's match at j - 1, without a bonus;
-- gaps over continuation bytes are free, so that scores count characters.
---@param pD table<integer, number>
---@param pM table<integer, number>
---@param cD table<integer, number>
---@param cM table<integer, number>
local function row(i, first, last, pD, pM, cD, cM, ascii)
  local prev_score = SCORE_MIN
  local gap_score = i == n and SCORE_GAP_TRAILING or SCORE_GAP_INNER
  local c = nb[i]
  if ncont[i] then
    for j = first, last do
      local score = SCORE_MIN
      if c == hay[j] and j > 1 then
        score = pD[j - 1]
      end
      cD[j] = score
      prev_score = max(score, hcont[j] and prev_score or prev_score + gap_score)
      cM[j] = prev_score
    end
    return
  elseif ascii then
    -- same as below without the UTF-8 lookups (`hidx[j] == j`, no continuation bytes)
    for j = first, last do
      if c == hay[j] then
        local score
        if i == 1 then
          score = (j - 1) * SCORE_GAP_LEADING + bonus[j]
        elseif j > 1 then
          score = max(pM[j - 1] + bonus[j], pD[j - 1] + SCORE_MATCH_CONSECUTIVE)
        else
          score = SCORE_MIN
        end
        cD[j] = score
        prev_score = max(score, prev_score + gap_score)
      else
        cD[j] = SCORE_MIN
        prev_score = prev_score + gap_score
      end
      cM[j] = prev_score
    end
    return
  end
  for j = first, last do
    if c == hay[j] then
      local score
      if i == 1 then
        score = (hidx[j] - 1) * SCORE_GAP_LEADING + bonus[j]
      elseif j > 1 then
        score = max(pM[j - 1] + bonus[j], pD[j - 1] + SCORE_MATCH_CONSECUTIVE)
      else
        score = SCORE_MIN
      end
      cD[j] = score
      prev_score = max(score, prev_score + gap_score)
    else
      cD[j] = SCORE_MIN
      prev_score = hcont[j] and prev_score or prev_score + gap_score
    end
    cM[j] = prev_score
  end
end

local D1, M1, D2, M2 = {}, {}, {}, {} ---@type table<integer, number>, table<integer, number>, table<integer, number>, table<integer, number>

---@param needle string
---@param haystack string
---@param case_sensitive? boolean
---@return number
function fzy.score(needle, haystack, case_sensitive)
  set_needle(needle, case_sensitive)
  local m = #haystack
  if n == 0 or m == 0 or m > MATCH_MAX_LENGTH or n > MATCH_MAX_LENGTH then
    return SCORE_MIN
  elseif n == m then
    return SCORE_MAX
  end
  -- Nothing matches before the first occurrence of the needle's first byte or after the last occurrence
  -- of its last byte: compute only that window, then add the trailing gaps as the full DP would.
  local c1, cn = nb[1], nb[n]
  local first, last = 1, m
  while first <= m and lower[byte(haystack, first)] ~= c1 do
    first = first + 1
  end
  while last >= first and lower[byte(haystack, last)] ~= cn do
    last = last - 1
  end
  if first > last then
    return SCORE_MIN
  end
  local ascii = prepare(haystack, first, last, m)
  -- only two rows are needed for the score
  local pD, pM, cD, cM = D1, M1, D2, M2
  if first > 1 then
    D1[first - 1], M1[first - 1], D2[first - 1], M2[first - 1] = SCORE_MIN, SCORE_MIN, SCORE_MIN, SCORE_MIN
  end
  for i = 1, n do
    row(i, first, last, pD, pM, cD, cM, ascii)
    pD, pM, cD, cM = cD, cM, pD, pM
  end
  local score = pM[last]
  for j = last + 1, m do
    if ascii or not hcont[j] then
      score = score + SCORE_GAP_TRAILING
    end
  end
  return score
end

-- full matrices for `positions` (rows reused across calls)
local D, M = {}, {}

function fzy.positions(needle, haystack, case_sensitive)
  set_needle(needle, case_sensitive)
  local m = #haystack
  if n == 0 or m == 0 or m > MATCH_MAX_LENGTH or n > MATCH_MAX_LENGTH then
    return {}
  elseif n == m then
    -- with equal lengths, a match is equality (up to case); no match, no positions
    local consecutive = {}
    for i = 1, n do
      if lower[byte(haystack, i)] ~= nb[i] then
        return {}
      end
      consecutive[i] = i
    end
    return consecutive
  end
  local ascii = prepare(haystack, 1, m, m)
  for i = 1, n do
    D[i], M[i] = D[i] or {}, M[i] or {}
    row(i, 1, m, D[i - 1], M[i - 1], D[i], M[i], ascii)
  end

  local positions = {}
  local match_required = false
  local j = m
  for i = n, 1, -1 do
    while j >= 1 do
      if D[i][j] ~= SCORE_MIN and (match_required or D[i][j] == M[i][j]) then
        match_required = (i ~= 1) and (j ~= 1) and (ncont[i] or M[i][j] == D[i - 1][j - 1] + SCORE_MATCH_CONSECUTIVE)
        positions[i] = j
        j = j - 1
        break
      else
        j = j - 1
      end
    end
  end

  return positions
end

--- Whether `needle` occurs in `haystack` at byte `at`, ignoring case unless `case_sensitive`.
function fzy.match_at(needle, haystack, at, case_sensitive)
  local len = #needle
  if at < 1 or at + len - 1 > #haystack then
    return false
  end
  local map = case_sensitive and SAME or FOLD
  for k = 1, len do
    if map[byte(haystack, at + k - 1)] ~= map[byte(needle, k)] then
      return false
    end
  end
  return true
end

--- Byte position of the first occurrence of `needle` in `haystack` from byte `init` (default 1),
--- ignoring case unless `case_sensitive` (pass true for needles without letters: faster), or nil.
function fzy.find(needle, haystack, case_sensitive, init)
  init = init or 1
  if case_sensitive then
    return (find(haystack, needle, init, true))
  end
  local first = FOLD[byte(needle, 1)]
  for at = init, #haystack - #needle + 1 do
    if FOLD[byte(haystack, at)] == first and fzy.match_at(needle, haystack, at, false) then
      return at
    end
  end
end

-- If strings a or b are empty or too long, `fzy.score(a, b) == fzy.get_score_min()`.
function fzy.get_score_min()
  return SCORE_MIN
end

-- For exact matches, `fzy.score(s, s) == fzy.get_score_max()`.
function fzy.get_score_max()
  return SCORE_MAX
end

-- For all strings a and b that
--  - are not covered by either `fzy.get_score_min()` or fzy.get_score_max()`, and
--  - are matched, such that `fzy.has_match(a, b) == true`,
-- then `fzy.score(a, b) > fzy.get_score_floor()` will be true.
function fzy.get_score_floor()
  return (MATCH_MAX_LENGTH + 1) * SCORE_GAP_INNER
end

return fzy
