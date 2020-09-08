#!/usr/local/bin/lua

-- Copyright (c) 2011 Patrick Joseph Donnelly
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local DEBUG = false;

local assert = assert;
local pairs = pairs;
local require = require;

local io = require "io";
local read = io.read;
local write = io.write;

local lpeg = require "lpeg";

lpeg.setmaxstack(2000);

local locale = lpeg.locale();

local P = lpeg.P;
local S = lpeg.S;
local V = lpeg.V;

local C = lpeg.C;
local Cb = lpeg.Cb;
local Cc = lpeg.Cc;
local Cg = lpeg.Cg;
local Cs = lpeg.Cs;
local Cmt = lpeg.Cmt;
local Cf = lpeg.Cf;

local NEWLINE = Cc "\n";
local n = 0;
local function indent (s, i, ...)
  return true, ("  "):rep(n); -- two spaces
end
local INDENT = Cmt(true, indent);
local INDENT_INCREASE_TRUE = Cmt(true, function (s, i, ...) n = n+1; return true; end);
local INDENT_DECREASE_TRUE = Cmt(true, function (s, i, ...) n = n-1; return true; end);
local INDENT_DECREASE_FALSE = Cmt(true, function (s, i, ...) n = n-1; return false; end);
local function INDENT_INCREASE (p, nonewline)
  if nonewline then
    return INDENT_INCREASE_TRUE * p * INDENT_DECREASE_TRUE + INDENT_DECREASE_FALSE;
  else
    return INDENT_INCREASE_TRUE * NEWLINE * p * INDENT_DECREASE_TRUE + INDENT_DECREASE_FALSE;
  end
end
local SPACE = Cc " ";

local shebang = P "#" * (P(1) - P "\n")^0 * P "\n";

local function K (k) -- keyword
  return C(k) * -(locale.alnum + P "_");
end

local lua = {
  C(shebang)^-1 * V "filler" * V "chunk" * V "filler" * -P(1);

  -- keywords

  keywords = K "and" + K "break" + K "do" + K "else" + K "elseif" +
             K "end" + K "false" + K "for" + K "function" + K "if" +
             K "in" + K "local" + K "nil" + K "not" + K "or" + K "repeat" +
             K "return" + K "then" + K "true" + K "until" + K "while";

  -- longstrings

  longstring = C { -- from Roberto Ierusalimschy's lpeg examples
    (V "open" * (P(1) - V "closeeq")^0 * V "close") / function (...) return end;

    open = "[" * Cg((P "=")^0, "init") * P "[" * (P "\n")^-1;
    close = "]" * C((P "=")^0) * "]";
    closeeq = Cmt(V "close" * Cb "init", function (s, i, a, b) return a == b end)
  };

  -- comments & whitespace

  all_but_last_space = (C(1) - ((locale.space - P "\n")^0 * (P "\n" + -P(1))))^0 * (locale.space - P "\n")^0 * (C "\n" + -P(1) * Cc "\n");
  one_line_comment = C "--" * V "all_but_last_space";
  multi_line_comment = C "--" * V "longstring";
  comment = V "multi_line_comment" + V "one_line_comment";

  shorten_comment = V "multi_line_comment" +
  --                  C "--" * Cc "[[ " * (locale.space - P "\n")^0 * (C(1) - P "\n")^0 * (P "\n" + -P(1)) * Cc " ]]"; -- change one-line comment to multi-line comment so it doesn't need line terminator
                    V "one_line_comment" * INDENT;

  space = (locale.space + (#V "shorten_comment" * SPACE * V "shorten_comment" * SPACE))^0; -- match comment before indenting (lpeg limitation)
  space_after_stat = ((locale.space - P "\n")^0 * (P ";")^-1 * (locale.space - P "\n")^0 * SPACE * V "one_line_comment") +
                     (V "space" * P ";")^-1 * NEWLINE;

  filler = ((((locale.space - P "\n")^0 * P "\n")^2 * Cc "\n" + (locale.space + (#V "comment" * INDENT * V "comment" * (C "\n")^-1)))^0) + V "space";

  -- Types and Comments

  Name = C(locale.alpha + P "_") * C(locale.alnum + P "_")^0 - V "keywords";
  Number = C((P "-")^-1 * V "space" * P "0x" * locale.xdigit^1 * -(locale.alnum + P "_")) +
           C((P "-")^-1 * V "space" * locale.digit^1 * (P "." * locale.digit^0)^-1 * (S "eE" * (P "-")^-1 * locale.digit^1)^-1 * -(locale.alnum + P "_")) +
           C((P "-")^-1 * V "space" * P "." * locale.digit^1 * (S "eE" * (P "-")^-1 * locale.digit^1)^-1 * -(locale.alnum + P "_"));
  String = C(P "\"" * (P "\\" * P(1) + (1 - P "\""))^0 * P "\"") +
           C(P "'" * (P "\\" * P(1) + (1 - P "'"))^0 * P "'") +
           V "longstring";

  -- Lua Complete Syntax

  chunk = (V "filler" * INDENT * V "stat" * V "space_after_stat")^0 * (V "filler" * INDENT * V "laststat" * V "space_after_stat")^-1;

  block = V "chunk";

  stat = K "do" * INDENT_INCREASE(V "filler" * V "block" * V "filler") * INDENT * K "end" +
         K "while" * SPACE * V "space" * V "exp" * V "space" * SPACE * K "do" * INDENT_INCREASE(V "filler" * V "block" * V "filler") * INDENT * K "end" +
         K "repeat" * INDENT_INCREASE(V "filler" * V "block" * V "filler") * INDENT * K "until" * SPACE * V "space" * V "exp" +
         K "if" * SPACE * V "space" * V "exp" * V "space" * SPACE * K "then" * INDENT_INCREASE(V "filler" * V "block" * V "filler") * (INDENT * K "elseif" * SPACE * V "space" * V "exp" * V "space" * SPACE * K "then" * INDENT_INCREASE(V "filler" * V "block" * V "filler"))^0 * (INDENT * K "else" * INDENT_INCREASE(V "filler" * V "block" * V "filler"))^-1 * INDENT * K "end" +
         K "for" * SPACE * V "space" * V "Name" * V "space" * SPACE * C "=" * SPACE * V "space" * V "exp" * V "space" * C "," * SPACE * V "space" * V "exp" * (V "space" * C "," * SPACE * V "space" * V "exp")^-1 * V "space" * SPACE * K "do" * INDENT_INCREASE(V "filler" * V "block" * V "filler") * INDENT * K "end" +
         K "for" * SPACE * V "space" * V "namelist" * V "space" * SPACE * K "in" * SPACE * V "space" * V "explist" * V "space" * SPACE * K "do" * INDENT_INCREASE(V "filler" * V "block" * V "filler") * INDENT * K "end" +
         K "function" * SPACE * V "space" * V "funcname" * SPACE * V "space" * V "funcbody" +
         K "local" * SPACE * V "space" * K "function" * SPACE * V "space" * V "Name" * V "space" * SPACE * V "funcbody" +
         K "local" * SPACE * V "space" * V "namelist" * (SPACE * V "space" * C "=" * SPACE * V "space" * V "explist")^-1  * Cc ";" +
         V "varlist" * V "space" * SPACE * C "=" * SPACE * V "space" * V "explist" * Cc ";" +
         V "functioncall" * Cc ";";

  laststat = K "return" * (SPACE * V "space" * V "explist")^-1 * Cc ";" + K "break" * Cc ";";

  funcname = V "Name" * (V "space" * C "." * V "space" * V "Name")^0 * (V "space" * C ":" * V "space" * V "Name")^-1;

  namelist = V "Name" * (V "space" * C "," * SPACE * V "space" * V "Name")^0;

  varlist = V "var" * (V "space" * C "," * SPACE * V "space" * V "var")^0;

  -- Let's come up with a syntax that does not use left recursion (only listing changes to Lua 5.1 extended BNF syntax)
  -- value ::= nil | false | true | Number | String | '...' | function | tableconstructor | functioncall | var | '(' exp ')'
  -- exp ::= unop exp | value [binop exp]
  -- prefix ::= '(' exp ')' | Name
  -- index ::= '[' exp ']' | '.' Name
  -- call ::= args | ':' Name args
  -- suffix ::= call | index
  -- var ::= prefix {suffix} index | Name
  -- functioncall ::= prefix {suffix} call

  -- Something that represents a value (or many values)
  value = K "nil" +
          K "false" +
          K "true" +
          V "Number" +
          V "String" +
          C "..." +
          V "function" +
          V "tableconstructor" +
          V "functioncall" +
          V "var" +
          C "(" * V "space" * V "exp" * V "space" * C ")";

  -- An expression operates on values to produce a new value or is a value
  exp = V "unop" * V "space" * V "exp" +
        V "value" * (V "space" * V "binop" * V "space" * V "exp")^-1;

  -- Index and Call
  index = C "[" * V "space" * V "exp" * V "space" * C "]" +
          C "." * V "space" * V "Name";
  call = V "args" +
         C ":" * V "space" * V "Name" * V "space" * V "args";

  -- A Prefix is a the leftmost side of a var(iable) or functioncall
  prefix = C "(" * V "space" * V "exp" * V "space" * C ")" +
           V "Name";
  -- A Suffix is a Call or Index
  suffix = V "call" +
           V "index";

  var = V "prefix" * (V "space" * V "suffix" * #(V "space" * V "suffix"))^0 * V "space" * V "index" +
        V "Name";
  functioncall = V "prefix" * (V "space" * V "suffix" * #(V "space" * V "suffix"))^0 * V "space" * V "call";

  explist = V "exp" * (V "space" * C "," * SPACE * V "space" * V "exp")^0;

  args = C "(" * INDENT_INCREASE(V "space" * (V "explist" * V "space")^-1, true) * C ")" +
         SPACE * V "tableconstructor" +
         SPACE * V "String";

  ["function"] = K "function" * SPACE * V "space" * V "funcbody";

  funcbody = C "(" * V "space" * (V "parlist" * V "space")^-1 * C ")" * INDENT_INCREASE(V "block" * V "space") * INDENT * K "end";

  parlist = V "namelist" * (V "space" * C "," * SPACE * V "space" * C "...")^-1 +
            C "...";

  tableconstructor = C "{" * (INDENT_INCREASE(V "filler" * V "fieldlist" * V "filler") * INDENT + V "filler") * C "}";

  field_space_after = (locale.space - P "\n")^0 * SPACE * V "one_line_comment";
  fieldlist = INDENT * V "field" * (V "space" * V "fieldsep" * (V "field_space_after" + NEWLINE) * V "filler" * INDENT * V "field")^0 * (V "space" * V "fieldsep")^-1 * NEWLINE;

  field = C "[" * V "space" * V "exp" * V "space" * C "]" * SPACE * V "space" * C "=" * SPACE * V "space" * V "exp" +
          V "Name" * SPACE * V "space" * C "=" * SPACE * V "space" * V "exp" +
          V "exp";

  fieldsep = C "," +
             P ";" * Cc ","; -- use only commas

  binop = SPACE * K "and" * SPACE + -- match longest token sequences first
          SPACE * K "or" * SPACE +
          SPACE * C ".." * SPACE +
          SPACE * C "<=" * SPACE +
          SPACE * C ">=" * SPACE +
          SPACE * C "==" * SPACE +
          SPACE * C "~=" * SPACE +
          SPACE * C "+" * SPACE +
          SPACE * (C "-" - P "--") * SPACE +
          SPACE * C "*" * SPACE +
          SPACE * C "/" * SPACE +
          C "^" + -- no space for power
          SPACE * C "%" * SPACE +
          SPACE * C "<" * SPACE +
          SPACE * C ">" * SPACE;

  unop = (C "-" - P "--") +
         C "#" +
         K "not" * SPACE;
};

if DEBUG then
  local level = 0;
  for k, p in pairs(lua) do
    local enter = lpeg.Cmt(lpeg.P(true), function(s, p, ...)
      write((" "):rep(level*2), "ENTER ", k, ": ", s:sub(p, p), "\n");
      level = level+1;
      return true;
    end);
    local leave = lpeg.Cmt(lpeg.P(true), function(s, p, ...)
      level = level-1;
      write((" "):rep(level*2), "LEAVE ", k, "\n");
      return true;
    end) * (lpeg.P("k") - lpeg.P "k");
    lua[k] = lpeg.Cmt(enter * p + leave, function(s, p, ...)
      level = level-1;
      if k == "space" or k == "comment" then
        return true;
      end
      write((" "):rep(level*2), "MATCH ", k, "\n", s:sub(p - 200 < 0 and 1 or p-200, p-1), "\n");
      return true, ...;
    end);
  end
end

lua = Cf(lua, function (a, b) return a..b end);

write(assert(lua:match(assert(read "*a"))));
