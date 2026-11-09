-- The fzy matching algorithm
--
-- Based on Seth Warn's <https://github.com/swarn> Lua port of John Hawthorn's fzy
-- <https://github.com/jhawthorn/fzy>, with these adaptations:
-- - Speed: works on bytes (`string.byte`) instead of one-character strings and patterns, keeps
--   only two rows of the score matrices for `score`, and reuses all buffers across calls (no
--   allocation per entry); the lowered needle is cached, and an ASCII-only fast path skips the
--   UTF-8 handling. Scores and positions for ASCII text are those of the port.
-- - UTF-8: a character of the needle only matches a whole character of the haystack (the port
--   could match its bytes across different characters), and scores count characters, not bytes.
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
local SCORE_MATCH_DOT = 0.6
local SCORE_MAX = math.huge
local SCORE_MIN = -math.huge
local MATCH_MAX_LENGTH = 1024

-- bonus for a match, indexed by the previous byte (paths are normalized to `/`, see
-- `utils.normalize_sep`); the camelCase bonus is handled in `prepare`
local BONUS = {}
for b = 0, 255 do
  BONUS[b] = 0
end
BONUS[47] = SCORE_MATCH_SLASH -- /
BONUS[45], BONUS[95], BONUS[32] = SCORE_MATCH_WORD, SCORE_MATCH_WORD, SCORE_MATCH_WORD -- - _ space
BONUS[46] = SCORE_MATCH_DOT -- .

local function is_cont(b)
  return b >= 0x80 and b < 0xC0 -- UTF-8 continuation byte
end

-- The needle, cached by string identity: lowered bytes, continuation flags, and its characters
-- (for `has_match`: a lowered byte for ASCII, else the character's bytes).
local last_needle, n, needle_ascii = nil, 0, true
local nb, ncont = {}, {}
local chars, nchars = {}, 0

local function set_needle(needle)
  if needle == last_needle then
    return
  end
  last_needle, n, nchars = needle, #needle, 0
  needle_ascii = not find(needle, "[\128-\255]")
  local i = 1
  while i <= n do
    local c = byte(needle, i)
    local len = c < 0x80 and 1 or c >= 0xF0 and 4 or c >= 0xE0 and 3 or c >= 0xC0 and 2 or 1
    nchars = nchars + 1
    chars[nchars] = len == 1 and ((c >= 65 and c <= 90) and c + 32 or c) or needle:sub(i, i + len - 1)
    for k = i, i + len - 1 do
      local b = byte(needle, k) or 0
      nb[k] = (b >= 65 and b <= 90) and b + 32 or b
      ncont[k] = k > i
    end
    i = i + len
  end
end

local fzy = {}

function fzy.has_match(needle, haystack)
  set_needle(needle)
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
        if h == c or (h >= 65 and h <= 90 and h + 32 == c) then
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

-- The haystack: lowered bytes, match bonuses, continuation flags and the number of characters up
-- to each byte (for the leading gap). Reused across calls.
local hay, bonus, hcont, hidx = {}, {}, {}, {}

local function prepare(haystack, m)
  local last, chars_seen = 47, 0 -- the start counts as after `/`
  local ascii = true
  for j = 1, m do
    local c = byte(haystack, j)
    local upper = c >= 65 and c <= 90
    if upper and last >= 97 and last <= 122 then
      bonus[j] = SCORE_MATCH_CAPITAL
    else
      bonus[j] = BONUS[last]
    end
    hay[j] = upper and c + 32 or c
    local cont = is_cont(c)
    hcont[j] = cont
    if not cont then
      chars_seen = chars_seen + 1
    end
    hidx[j] = chars_seen
    ascii = ascii and c < 0x80
    last = c
  end
  return ascii and needle_ascii
end

-- One row of the matrices: `pD`/`pM` are the previous row (needle byte i - 1), `cD`/`cM` are filled.
-- `D[j]` is the best score with needle byte i matched at haystack byte j, `M[j]` the best score up
-- to j. A continuation byte only continues the previous byte's match at j - 1, without a bonus;
-- gaps over continuation bytes are free, so that scores count characters.
local function row(i, m, pD, pM, cD, cM, ascii)
  local prev_score = SCORE_MIN
  local gap_score = i == n and SCORE_GAP_TRAILING or SCORE_GAP_INNER
  local c = nb[i]
  if ncont[i] then
    for j = 1, m do
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
    for j = 1, m do
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
  for j = 1, m do
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

local D1, M1, D2, M2 = {}, {}, {}, {}

function fzy.score(needle, haystack)
  set_needle(needle)
  local m = #haystack
  if n == 0 or m == 0 or m > MATCH_MAX_LENGTH or n > MATCH_MAX_LENGTH then
    return SCORE_MIN
  elseif n == m then
    return SCORE_MAX
  end
  local ascii = prepare(haystack, m)
  -- only two rows are needed for the score
  local pD, pM, cD, cM = D1, M1, D2, M2
  for i = 1, n do
    row(i, m, pD, pM, cD, cM, ascii)
    pD, pM, cD, cM = cD, cM, pD, pM
  end
  return pM[m]
end

-- full matrices for `positions` (rows reused across calls)
local D, M = {}, {}

function fzy.positions(needle, haystack)
  set_needle(needle)
  local m = #haystack
  if n == 0 or m == 0 or m > MATCH_MAX_LENGTH or n > MATCH_MAX_LENGTH then
    return {}
  elseif n == m then
    local consecutive = {}
    for i = 1, n do
      consecutive[i] = i
    end
    return consecutive
  end
  local ascii = prepare(haystack, m)
  for i = 1, n do
    D[i], M[i] = D[i] or {}, M[i] or {}
    row(i, m, D[i - 1], M[i - 1], D[i], M[i], ascii)
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
