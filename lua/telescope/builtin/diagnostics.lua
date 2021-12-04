local conf = require("telescope.config").values
local finders = require "telescope.finders"
local make_entry = require "telescope.make_entry"
local pickers = require "telescope.pickers"

local diagnostics = {}

local convert_diagnostic_type = function(severities, severity)
  -- convert from string to int
  if type(severity) == "string" then
    -- make sure that e.g. error is uppercased to ERROR
    return severities[severity:upper()]
  end
  -- otherwise keep original value, incl. nil
  return severity
end

local filter_diag_severity = function(opts, severity)
  if opts.severity ~= nil then
    return opts.severity == severity
  elseif opts.severity_limit ~= nil then
    return severity <= opts.severity_limit
  elseif opts.severity_bound ~= nil then
    return severity >= opts.severity_bound
  else
    return true
  end
end

local diagnostics_to_tbl = function(opts)
  opts = vim.F.if_nil(opts, {})
  local items = {}
  local severities = vim.diagnostic.severity
  local current_buf = vim.api.nvim_get_current_buf()

  opts.severity = convert_diagnostic_type(severities, opts.severity)
  opts.severity_limit = convert_diagnostic_type(severities, opts.severity_limit)
  opts.severity_bound = convert_diagnostic_type(severities, opts.severity_bound)

  local validate_severity = 0
  for _, v in ipairs { opts.severity, opts.severity_limit, opts.severity_bound } do
    if v ~= nil then
      validate_severity = validate_severity + 1
    end
    if validate_severity > 1 then
      print "Please pass valid severity parameters"
      return {}
    end
  end

  local bufnr_name_map = {}
  local preprocess_diag = function(diagnostic)
    if bufnr_name_map[diagnostic.bufnr] == nil then
      bufnr_name_map[diagnostic.bufnr] = vim.api.nvim_buf_get_name(diagnostic.bufnr)
    end

    local buffer_diag = {
      bufnr = diagnostic.bufnr,
      filename = bufnr_name_map[diagnostic.bufnr],
      lnum = diagnostic.lnum + 1,
      col = diagnostic.col + 1,
      text = vim.trim(diagnostic.message:gsub("[\n]", "")),
      type = severities[diagnostic.severity] or severities[1],
    }
    return buffer_diag
  end

  local diagnosis = opts.get_all and vim.diagnostic.get(nil)
    or { vim.diagnostic.get(current_buf, { namespace = opts.namespace }) }
  for _, namespace in ipairs(diagnosis) do
    for _, diagnostic in ipairs(namespace) do
      if filter_diag_severity(opts, diagnostic.severity) then
        table.insert(items, preprocess_diag(diagnostic))
      end
    end
  end

  -- sort results by bufnr (prioritize cur buf), severity, lnum
  table.sort(items, function(a, b)
    if a.bufnr == b.bufnr then
      if a.type == b.type then
        return a.lnum < b.lnum
      else
        return a.type < b.type
      end
    else
      -- prioritize for current bufnr
      if a.bufnr == current_buf then
        return true
      end
      if b.bufnr == current_buf then
        return false
      end
      return a.bufnr < b.bufnr
    end
  end)

  return items
end

diagnostics.document = function(opts)
  local locations = diagnostics_to_tbl(opts)

  if vim.tbl_isempty(locations) then
    print "No diagnostics found"
    return
  end

  opts.path_display = vim.F.if_nil(opts.path_display, "hidden")
  pickers.new(opts, {
    prompt_title = "Document Diagnostics",
    finder = finders.new_table {
      results = locations,
      entry_maker = opts.entry_maker or make_entry.gen_from_diagnostics(opts),
    },
    previewer = conf.qflist_previewer(opts),
    sorter = conf.prefilter_sorter {
      tag = "type",
      sorter = conf.generic_sorter(opts),
    },
  }):find()
end

diagnostics.workspace = function(opts)
  opts.path_display = vim.F.if_nil(opts.path_display, {})
  opts.prompt_title = "Workspace Diagnostics"
  opts.get_all = true
  diagnostics.diagnostics(opts)
end

local function apply_checks(mod)
  for k, v in pairs(mod) do
    mod[k] = function(opts)
      opts = opts or {}
      v(opts)
    end
  end

  return mod
end

return apply_checks(diagnostics)
