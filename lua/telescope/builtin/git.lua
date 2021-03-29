local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')
local utils = require('telescope.utils')
local entry_display = require('telescope.pickers.entry_display')

local conf = require('telescope.config').values

local git = {}

git.files = function(opts)
  local show_untracked = utils.get_default(opts.show_untracked, true)
  local recurse_submodules = utils.get_default(opts.recurse_submodules, false)
  if show_untracked and recurse_submodules then
    error("Git does not suppurt both --others and --recurse-submodules")
  end

  -- By creating the entry maker after the cwd options,
  -- we ensure the maker uses the cwd options when being created.
  opts.entry_maker = opts.entry_maker or make_entry.gen_from_file(opts)

  pickers.new(opts, {
    prompt_title = 'Git Files',
    finder = finders.new_oneshot_job(
      vim.tbl_flatten( {
        "git", "ls-files", "--exclude-standard", "--cached",
        show_untracked and "--others" or nil,
        recurse_submodules and "--recurse-submodules" or nil
      } ),
      opts
    ),
    previewer = conf.file_previewer(opts),
    sorter = conf.file_sorter(opts),
  }):find()
end

git.commits = function(opts)
  local results = utils.get_os_command_output({
    'git', 'log', '--pretty=oneline', '--abbrev-commit', '--', '.'
  }, opts.cwd)

  pickers.new(opts, {
    prompt_title = 'Git Commits',
    finder = finders.new_table {
      results = results,
      entry_maker = opts.entry_maker or make_entry.gen_from_git_commits(opts),
    },
    previewer = previewers.git_commit_diff.new(opts),
    sorter = conf.file_sorter(opts),
    attach_mappings = function()
      actions.select_default:replace(actions.git_checkout)
      return true
    end
  }):find()
end

git.bcommits = function(opts)
  local results = utils.get_os_command_output({
    'git', 'log', '--pretty=oneline', '--abbrev-commit', vim.fn.expand('%')
  }, opts.cwd)

  pickers.new(opts, {
    prompt_title = 'Git BCommits',
    finder = finders.new_table {
      results = results,
      entry_maker = opts.entry_maker or make_entry.gen_from_git_commits(opts),
    },
    previewer = previewers.git_commit_diff.new(opts),
    sorter = conf.file_sorter(opts),
    attach_mappings = function()
      actions.select_default:replace(actions.git_checkout)
      return true
    end
  }):find()
end

git.branches = function(opts)
  local format = '{'
              ..   '"head":%(if:equals=*)%(HEAD)%(then)true%(else)false%(end)'
              ..   ',"refname":"%(refname)"'
              ..   ',"authorname":"%(authorname)"'
              ..   '%(if)%(upstream)%(then)'
              ..     ',"upstream":"%(upstream:lstrip=2)"'
              ..   '%(else)'
              ..     ',"upstream":""'
              ..   '%(end)'
              ..   ',"committerdate":"%(committerdate:format-local:%Y/%m/%d %H:%M:%S)"'
              .. '}'
  local output = utils.get_os_command_output({ 'git', 'for-each-ref', '--format', format }, opts.cwd)

  local results = {}
  local widths = {
    name = 0,
    authorname = 0,
    upstream = 0,
    committerdate = 0,
  }
  local register_entry = function(entry, trim_refname_prefix)
    entry.name = string.sub(entry.refname, string.len(trim_refname_prefix)+1)
    for key, value in pairs(widths) do
      widths[key] = math.max(value, vim.fn.strdisplaywidth(entry[key]))
    end
    if string.len(entry.upstream) > 0 then
      widths.upstream_indicator = 2
    end
    table.insert(results, entry)
  end
  for _, v in ipairs(output) do
    local entry = vim.fn.json_decode(v)
    if entry.head then
      goto continue
    elseif vim.startswith(entry.refname, 'refs/remotes/') then
      register_entry(entry, 'refs/remotes/')
    elseif vim.startswith(entry.refname, 'refs/heads/') then
      register_entry(entry, 'refs/heads/')
    end
    ::continue::
  end
  if #results == 0 then
    return
  end

  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = widths.name },
      { width = widths.authorname },
      { width = widths.upstream_indicator },
      { width = widths.upstream },
      { width = widths.committerdate },
    }
  }

  local make_display = function(entry)
    return displayer {
      {entry.name, 'TelescopeResultsIdentifier'},
      {entry.authorname},
      {string.len(entry.upstream) > 0 and '=>' or ''},
      {entry.upstream, 'TelescopeResultsIdentifier'},
      {entry.committerdate}
    }
  end

  pickers.new(opts, {
    prompt_title = 'Git Branches',
    finder = finders.new_table {
      results = results,
      entry_maker = function(entry)
        entry.value = entry.name
        entry.ordinal = entry.name
        entry.display = make_display
        return entry
      end
    },
    previewer = previewers.git_branch_log.new(opts),
    sorter = conf.file_sorter(opts),
    attach_mappings = function(_, map)
      actions.select_default:replace(actions.git_checkout)
      map('i', '<c-t>', actions.git_track_branch)
      map('n', '<c-t>', actions.git_track_branch)

      map('i', '<c-r>', actions.git_rebase_branch)
      map('n', '<c-r>', actions.git_rebase_branch)

      map('i', '<c-d>', actions.git_delete_branch)
      map('n', '<c-d>', actions.git_delete_branch)

      map('i', '<c-u>', false)
      map('n', '<c-u>', false)
      return true
    end
  }):find()
end

git.status = function(opts)
  local gen_new_finder = function()
    local expand_dir = utils.if_nil(opts.expand_dir, true, opts.expand_dir)
    local git_cmd = {'git', 'status', '-s', '--', '.'}

    if expand_dir then
      table.insert(git_cmd, table.getn(git_cmd) - 1, '-u')
    end

    local output = utils.get_os_command_output(git_cmd, opts.cwd)

    if table.getn(output) == 0 then
      print('No changes found')
      return
    end

    return finders.new_table {
      results = output,
      entry_maker = opts.entry_maker or make_entry.gen_from_git_status(opts)
    }
  end

  local initial_finder = gen_new_finder()
  if not initial_finder then return end

  pickers.new(opts, {
    prompt_title = 'Git Status',
    finder = initial_finder,
    previewer = previewers.git_file_diff.new(opts),
    sorter = conf.file_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.git_staging_toggle:enhance {
        post = function()
          action_state.get_current_picker(prompt_bufnr):refresh(gen_new_finder(), { reset_prompt = true })
        end,
      }

      map('i', '<tab>', actions.git_staging_toggle)
      map('n', '<tab>', actions.git_staging_toggle)
      return true
    end
  }):find()
end

local set_opts_cwd = function(opts)
  if opts.cwd then
    opts.cwd = vim.fn.expand(opts.cwd)
  else
    opts.cwd = vim.loop.cwd()
  end

  -- Find root of git directory and remove trailing newline characters
  local git_root, ret = utils.get_os_command_output({ "git", "rev-parse", "--show-toplevel" }, opts.cwd)
  local use_git_root = utils.get_default(opts.use_git_root, true)

  if ret ~= 0 then
    error(opts.cwd .. ' is not a git directory')
  else
    if use_git_root then
      opts.cwd = git_root[1]
    end
  end
end

local function apply_checks(mod)
  for k, v in pairs(mod) do
    mod[k] = function(opts)
      opts = opts or {}

      set_opts_cwd(opts)
      v(opts)
    end
  end

  return mod
end

return apply_checks(git)
