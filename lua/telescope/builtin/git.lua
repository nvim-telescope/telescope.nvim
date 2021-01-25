local actions = require('telescope.actions')
local finders = require('telescope.finders')
local make_entry = require('telescope.make_entry')
local pickers = require('telescope.pickers')
local previewers = require('telescope.previewers')
local utils = require('telescope.utils')

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
    prompt_title = 'Git File',
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
  local results = utils.get_os_command_output({ 'git', 'log', '--pretty=oneline', '--abbrev-commit' })

  pickers.new(opts, {
    prompt_title = 'Git Commits',
    finder = finders.new_table {
      results = results,
      entry_maker = opts.entry_maker or make_entry.gen_from_git_commits(opts),
    },
    previewer = previewers.git_commit_diff.new(opts),
    sorter = conf.file_sorter(opts),
    attach_mappings = function()
      actions.select:replace(actions.git_checkout)
      return true
    end
  }):find()
end

git.bcommits = function(opts)
  local results = utils.get_os_command_output({
    'git', 'log', '--pretty=oneline', '--abbrev-commit', vim.fn.expand('%')
  })

  pickers.new(opts, {
    prompt_title = 'Git BCommits',
    finder = finders.new_table {
      results = results,
      entry_maker = opts.entry_maker or make_entry.gen_from_git_commits(opts),
    },
    previewer = previewers.git_commit_diff.new(opts),
    sorter = conf.file_sorter(opts),
    attach_mappings = function()
      actions.select:replace(actions.git_checkout)
      return true
    end
  }):find()
end

git.branches = function(opts)
  -- Does this command in lua (hopefully):
  -- 'git branch --all | grep -v HEAD | sed "s/.* //;s#remotes/[^/]*/##" | sort -u'
  local output = utils.get_os_command_output({ 'git', 'branch', '--all' })

  local tmp_results = {}
  for _, v in ipairs(output) do
    if not string.match(v, 'HEAD') and v ~= '' then
      v = string.gsub(v, '.* ', '')
      v = string.gsub(v, '^remotes/[^/]*/', '')
      tmp_results[v] = true
    end
  end

  local results = {}
  for k, _ in pairs(tmp_results) do
    table.insert(results, k)
  end

  pickers.new(opts, {
    prompt_title = 'Git Branches',
    finder = finders.new_table {
      results = results,
      entry_maker = function(entry)
        return {
          value = entry,
          ordinal = entry,
          display = entry,
        }
      end
    },
    previewer = previewers.git_branch_log.new(opts),
    sorter = conf.file_sorter(opts),
    attach_mappings = function()
      actions.select:replace(actions.git_checkout)
      return true
    end
  }):find()
end

git.status = function(opts)
  local output = utils.get_os_command_output{ 'git', 'status', '-s' }

  if table.getn(output) == 0 then
    print('No changes found')
    return
  end

  pickers.new(opts, {
    prompt_title = 'Git Status',
    finder = finders.new_table {
      results = output,
      entry_maker = make_entry.gen_from_git_status(opts)
    },
    previewer = previewers.git_file_diff.new(opts),
    sorter = conf.file_sorter(opts),
    attach_mappings = function(_, map)
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
  local git_root = vim.fn.systemlist("git -C " .. opts.cwd .. " rev-parse --show-toplevel")[1]

  if vim.v.shell_error ~= 0 then
    error(opts.cwd .. ' is not a git directory')
  else
    opts.cwd = git_root
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
