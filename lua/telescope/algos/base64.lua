--[[

 base64 -- v1.5.3 public domain Lua base64 encoder/decoder
 no warranty implied; use at your own risk

 Needs bit32.extract function. If not present it's implemented using BitOp
 or Lua 5.3 native bit operators. For Lua 5.1 fallbacks to pure Lua
 implementation inspired by Rici Lake's post:
   http://ricilake.blogspot.co.uk/2007/10/iterating-bits-in-lua.html

 author: Ilya Kolbin (iskolbin@gmail.com)
 url: github.com/iskolbin/lbase64

 COMPATIBILITY

 Lua 5.1+, LuaJIT

 LICENSE

 See end of file for license information.

--]]

local base64 = {}

local extract = _G.bit32 and _G.bit32.extract -- Lua 5.2/Lua 5.3 in compatibility mode
if not extract then
  if _G.bit then -- LuaJIT
    local shl, shr, band = _G.bit.lshift, _G.bit.rshift, _G.bit.band
    extract = function(v, from, width)
      return band(shr(v, from), shl(1, width) - 1)
    end
  elseif _G._VERSION == "Lua 5.1" then
    extract = function(v, from, width)
      local w = 0
      local flag = 2 ^ from
      for i = 0, width - 1 do
        local flag2 = flag + flag
        if v % flag2 >= flag then
          w = w + 2 ^ i
        end
        flag = flag2
      end
      return w
    end
  else -- Lua 5.3+
    extract = load [[return function( v, from, width )
			return ( v >> from ) & ((1 << width) - 1)
		end]]()
  end
end

function base64.makeencoder(s62, s63, spad)
  local encoder = {}
  -- stylua: ignore
	for b64code, char in pairs{[0]='A','B','C','D','E','F','G','H','I','J',
		'K','L','M','N','O','P','Q','R','S','T','U','V','W','X','Y',
		'Z','a','b','c','d','e','f','g','h','i','j','k','l','m','n',
		'o','p','q','r','s','t','u','v','w','x','y','z','0','1','2',
		'3','4','5','6','7','8','9',s62 or '+',s63 or'/',spad or'='} do
		encoder[b64code] = char:byte()
	end
  return encoder
end

function base64.makedecoder(s62, s63, spad)
  local decoder = {}
  for b64code, charcode in pairs(base64.makeencoder(s62, s63, spad)) do
    decoder[charcode] = b64code
  end
  return decoder
end

local DEFAULT_ENCODER = base64.makeencoder()
local DEFAULT_DECODER = base64.makedecoder()

local char, concat = string.char, table.concat

function base64.encode(str, encoder, usecaching)
  encoder = encoder or DEFAULT_ENCODER
  local t, k, n = {}, 1, #str
  local lastn = n % 3
  local cache = {}
  for i = 1, n - lastn, 3 do
    local a, b, c = str:byte(i, i + 2)
    local v = a * 0x10000 + b * 0x100 + c
    local s
    if usecaching then
      s = cache[v]
      if not s then
        s = char(
          encoder[extract(v, 18, 6)],
          encoder[extract(v, 12, 6)],
          encoder[extract(v, 6, 6)],
          encoder[extract(v, 0, 6)]
        )
        cache[v] = s
      end
    else
      s = char(
        encoder[extract(v, 18, 6)],
        encoder[extract(v, 12, 6)],
        encoder[extract(v, 6, 6)],
        encoder[extract(v, 0, 6)]
      )
    end
    t[k] = s
    k = k + 1
  end
  if lastn == 2 then
    local a, b = str:byte(n - 1, n)
    local v = a * 0x10000 + b * 0x100
    t[k] = char(encoder[extract(v, 18, 6)], encoder[extract(v, 12, 6)], encoder[extract(v, 6, 6)], encoder[64])
  elseif lastn == 1 then
    local v = str:byte(n) * 0x10000
    t[k] = char(encoder[extract(v, 18, 6)], encoder[extract(v, 12, 6)], encoder[64], encoder[64])
  end
  return concat(t)
end

function base64.decode(b64, decoder, usecaching)
  decoder = decoder or DEFAULT_DECODER
  local pattern = "[^%w%+%/%=]"
  if decoder then
    local s62, s63
    for charcode, b64code in pairs(decoder) do
      if b64code == 62 then
        s62 = charcode
      elseif b64code == 63 then
        s63 = charcode
      end
    end
    pattern = ("[^%%w%%%s%%%s%%=]"):format(char(s62), char(s63))
  end
  b64 = b64:gsub(pattern, "")
  local cache = usecaching and {}
  local t, k = {}, 1
  local n = #b64
  local padding = b64:sub(-2) == "==" and 2 or b64:sub(-1) == "=" and 1 or 0
  for i = 1, padding > 0 and n - 4 or n, 4 do
    local a, b, c, d = b64:byte(i, i + 3)
    local s
    if usecaching then
      local v0 = a * 0x1000000 + b * 0x10000 + c * 0x100 + d
      s = cache[v0]
      if not s then
        local v = decoder[a] * 0x40000 + decoder[b] * 0x1000 + decoder[c] * 0x40 + decoder[d]
        s = char(extract(v, 16, 8), extract(v, 8, 8), extract(v, 0, 8))
        cache[v0] = s
      end
    else
      local v = decoder[a] * 0x40000 + decoder[b] * 0x1000 + decoder[c] * 0x40 + decoder[d]
      s = char(extract(v, 16, 8), extract(v, 8, 8), extract(v, 0, 8))
    end
    t[k] = s
    k = k + 1
  end
  if padding == 1 then
    local a, b, c = b64:byte(n - 3, n - 1)
    local v = decoder[a] * 0x40000 + decoder[b] * 0x1000 + decoder[c] * 0x40
    t[k] = char(extract(v, 16, 8), extract(v, 8, 8))
  elseif padding == 2 then
    local a, b = b64:byte(n - 3, n - 2)
    local v = decoder[a] * 0x40000 + decoder[b] * 0x1000
    t[k] = char(extract(v, 16, 8))
  end
  return concat(t)
end

return base64

--[[
MIT LICENSE
Copyright (c) 2018 Ilya Kolbin
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]
