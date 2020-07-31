
local function ngrams(counts, doc)
  local DEPTH = 5
  local docLen = #doc
  local min, concat = math.min, table.concat
  for i = 1, docLen - 1 do
    for j = i, min(i + DEPTH - 1, docLen) do
      if not doc[j] then break end
      local k = concat(doc, " ", i, j)
      counts[k] = (counts[k] or 0) + 1
    end
  end
end


local bz = io.popen('bzcat /home/tj/Downloads/pages.xml.bz2')
local title, content = "", ""
local inText = false

local numDocs = 0
local globalCounts = {}

local function set(t) 
  local s = {}
  for _, v in pairs(t) do s[v] = true end
  return s
end

local bad = set({
                  'after', 'also', 'article', 'date', 'defaultsort', 'external', 'first', 'from',
                  'have', 'html', 'http', 'image', 'infobox', 'links', 'name', 'other', 'preserve',
                  'references', 'reflist', 'space', 'that', 'this', 'title', 'which', 'with',
                  'quot', 'ref', 'name', 'http', 'amp', 'ndash', 'www', 'cite', 'nbsp',
                  'style', 'text', 'align', 'center', 'background'
                })

local function isnumber(w)
  s, e = w:find("[0-9]+")
  return s
end

for line in bz:lines() do
  local _, _, mTitle = line:find("<title>(.*)</title>")
  local _, _, bText = line:find("<text[^>]*>([^<]*)")
  local eText, _ = line:find("</text>")

  if mTitle then
    title = mTitle
  elseif bText then
    content = bText
    inText = true
  elseif inText then
    content = content .. line
  end
  
  if eText then
    words = {}
    for v in content:gmatch("%w+") do
      v = v:lower()
      if #v >= 3 and #v < 12 and not bad[v] and not isnumber(v) then
        table.insert(words, v)
      else
        table.insert(words, nil)
      end
    end

    ngrams(globalCounts, words)
    inText = false

    numDocs = numDocs + 1
    if numDocs % 10 == 0 then
      io.write(string.format("Working... %d documents processed.\r", numDocs))
      io.flush()
    end
    
    if numDocs == 500 then
      local f = io.open('/tmp/freqs.lua.txt', 'w')
      for k, v in pairs(globalCounts) do
        f:write(k, '\t', v, '\n')
      end
      f:close()

      globalCounts = {}
      os.exit(0)
    end
  end  
end
