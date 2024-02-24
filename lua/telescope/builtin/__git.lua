local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"
local finders = require "telescope.finders"
local make_entry = require "telescope.make_entry"
local operators = require "telescope.operators"
local pickers = require "telescope.pickers"
local previewers = require "telescope.previewers"
local utils = require "telescope.utils"
local entry_display = require "telescope.pickers.entry_display"
local strings = require "plenary.strings"
local Path = require "plenary.path"

local conf = require("telescope.config").values
local git_command = utils.__git_command

local git = {}

local get_git_command_output = function(args, opts)
  return utils.get_os_command_output(git_command(args, opts), opts.cwd)
end

git.files = function(opts)
  if opts.is_bare then
    utils.notify("builtin.git_files", {
      msg = "This operation must be run in a work tree",
      level = "ERROR",
    })
    return
  end

  local show_untracked = vim.F.if_nil(opts.show_untracked, false)
  local recurse_submodules = vim.F.if_nil(opts.recurse_submodules, false)
  if show_untracked and recurse_submodules then
    utils.notify("builtin.git_files", {
      msg = "Git does not support both --others and --recurse-submodules",
      level = "ERROR",
    })
    return
  end

  -- By creating the entry maker after the cwd options,
  -- we ensure the maker uses the cwd options when being created.
  opts.entry_maker = vim.F.if_nil(opts.entry_maker, make_entry.gen_from_file(opts))
  opts.git_command = vim.F.if_nil(
    opts.git_command,
    git_command({ "-c", "core.quotepath=false", "ls-files", "--exclude-standard", "--cached" }, opts)
  )

  pickers
    .new(opts, {
      prompt_title = "Git Files",
      __locations_input = true,
      finder = finders.new_oneshot_job(
        vim.tbl_flatten {
          opts.git_command,
          show_untracked and "--others" or nil,
          recurse_submodules and "--recurse-submodules" or nil,
        },
        opts
      ),
      previewer = conf.grep_previewer(opts),
      sorter = conf.file_sorter(opts),
    })
    :find()
end

git.commits = function(opts)
  opts.entry_maker = vim.F.if_nil(opts.entry_maker, make_entry.gen_from_git_commits(opts))
  opts.git_command =
    vim.F.if_nil(opts.git_command, git_command({ "log", "--pretty=oneline", "--abbrev-commit", "--", "." }, opts))

  pickers
    .new(opts, {
      prompt_title = "Git Commits",
      finder = finders.new_oneshot_job(opts.git_command, opts),
      previewer = {
        previewers.git_commit_diff_to_parent.new(opts),
        previewers.git_commit_diff_to_head.new(opts),
        previewers.git_commit_diff_as_was.new(opts),
        previewers.git_commit_message.new(opts),
      },
      sorter = conf.file_sorter(opts),
      attach_mappings = function(_, map)
        actions.select_default:replace(actions.git_checkout)
        map({ "i", "n" }, "<c-r>m", actions.git_reset_mixed)
        map({ "i", "n" }, "<c-r>s", actions.git_reset_soft)
        map({ "i", "n" }, "<c-r>h", actions.git_reset_hard)
        return true
      end,
    })
    :find()
end

git.stash = function(opts)
  opts.show_branch = vim.F.if_nil(opts.show_branch, true)
  opts.entry_maker = vim.F.if_nil(opts.entry_maker, make_entry.gen_from_git_stash(opts))
  opts.git_command = vim.F.if_nil(opts.git_command, git_command({ "--no-pager", "stash", "list" }, opts))

  pickers
    .new(opts, {
      prompt_title = "Git Stash",
      finder = finders.new_oneshot_job(opts.git_command, opts),
      previewer = previewers.git_stash_diff.new(opts),
      sorter = conf.file_sorter(opts),
      attach_mappings = function()
        actions.select_default:replace(actions.git_apply_stash)
        return true
      end,
    })
    :find()
end

local get_current_buf_line = function(winnr)
  local lnum = vim.api.nvim_win_get_cursor(winnr)[1]
  return vim.trim(vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(winnr), lnum - 1, lnum, false)[1])
end

local bcommits_picker = function(opts, title, finder)
  return pickers.new(opts, {
    prompt_title = title,
    finder = finder,
    previewer = {
      previewers.git_commit_diff_to_parent.new(opts),
      previewers.git_commit_diff_to_head.new(opts),
      previewers.git_commit_diff_as_was.new(opts),
      previewers.git_commit_message.new(opts),
    },
    sorter = conf.file_sorter(opts),
    attach_mappings = function()
      actions.select_default:replace(actions.git_checkout_current_buffer)
      local transfrom_file = function()
        return opts.current_file and Path:new(opts.current_file):make_relative(opts.cwd) or ""
      end

      local get_buffer_of_orig = function(selection)
        local value = selection.value .. ":" .. transfrom_file()
        local content = utils.get_os_command_output({ "git", "--no-pager", "show", value }, opts.cwd)

        local bufnr = vim.api.nvim_create_buf(false, true)
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, content)
        vim.api.nvim_buf_set_name(bufnr, "Original")
        return bufnr
      end

      local vimdiff = function(selection, command)
        local ft = vim.bo.filetype
        vim.cmd "diffthis"

        local bufnr = get_buffer_of_orig(selection)
        vim.cmd(string.format("%s %s", command, bufnr))
        vim.bo.filetype = ft
        vim.cmd "diffthis"

        vim.api.nvim_create_autocmd("WinClosed", {
          buffer = bufnr,
          nested = true,
          once = true,
          callback = function()
            vim.api.nvim_buf_delete(bufnr, { force = true })
          end,
        })
      end

      actions.select_vertical:replace(function(prompt_bufnr)
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        vimdiff(selection, "leftabove vert sbuffer")
      end)

      actions.select_horizontal:replace(function(prompt_bufnr)
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        vimdiff(selection, "belowright sbuffer")
      end)

      actions.select_tab:replace(function(prompt_bufnr)
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        vim.cmd("tabedit " .. transfrom_file())
        vimdiff(selection, "leftabove vert sbuffer")
      end)
      return true
    end,
  })
end

git.bcommits = function(opts)
  opts.current_line = (opts.current_file == nil) and get_current_buf_line(opts.winnr) or nil
  opts.current_file = vim.F.if_nil(opts.current_file, vim.api.nvim_buf_get_name(opts.bufnr))
  opts.entry_maker = vim.F.if_nil(opts.entry_maker, make_entry.gen_from_git_commits(opts))
  opts.git_command =
    vim.F.if_nil(opts.git_command, git_command({ "log", "--pretty=oneline", "--abbrev-commit", "--follow" }, opts))

  local title = "Git BCommits"
  local finder = finders.new_oneshot_job(
    vim.tbl_flatten {
      opts.git_command,
      opts.current_file,
    },
    opts
  )
  bcommits_picker(opts, title, finder):find()
end

git.bcommits_range = function(opts)
  opts.current_line = (opts.current_file == nil) and get_current_buf_line(opts.winnr) or nil
  opts.current_file = vim.F.if_nil(opts.current_file, vim.api.nvim_buf_get_name(opts.bufnr))
  opts.entry_maker = vim.F.if_nil(opts.entry_maker, make_entry.gen_from_git_commits(opts))
  opts.git_command = vim.F.if_nil(
    opts.git_command,
    git_command({ "log", "--pretty=oneline", "--abbrev-commit", "--no-patch", "-L" }, opts)
  )
  local visual = string.find(vim.fn.mode(), "[vV]") ~= nil

  local line_number_first = opts.from
  local line_number_last = vim.F.if_nil(opts.to, line_number_first)
  if visual then
    line_number_first = vim.F.if_nil(line_number_first, vim.fn.line "v")
    line_number_last = vim.F.if_nil(line_number_last, vim.fn.line ".")
  elseif opts.operator then
    opts.operator = false
    opts.operator_callback = true
    operators.run_operator(git.bcommits_range, opts)
    return
  elseif opts.operator_callback then
    line_number_first = vim.fn.line "'["
    line_number_last = vim.fn.line "']"
  elseif line_number_first == nil then
    line_number_first = vim.F.if_nil(line_number_first, vim.fn.line ".")
    line_number_last = vim.F.if_nil(line_number_last, vim.fn.line ".")
  end
  local line_range =
    string.format("%d,%d:%s", line_number_first, line_number_last, Path:new(opts.current_file):make_relative(opts.cwd))

  local title = "Git BCommits in range"
  local finder = finders.new_oneshot_job(
    vim.tbl_flatten {
      opts.git_command,
      line_range,
    },
    opts
  )
  bcommits_picker(opts, title, finder):find()
end

git.branches = function(opts)
  local format = "%(HEAD)"
    .. "%(refname)"
    .. "%(authorname)"
    .. "%(upstream:lstrip=2)"
    .. "%(committerdate:format-local:%Y/%m/%d %H:%M:%S)"

  local output = get_git_command_output(
    { "for-each-ref", "--perl", "--format", format, "--sort", "-authordate", opts.pattern },
    opts
  )

  local show_remote_tracking_branches = vim.F.if_nil(opts.show_remote_tracking_branches, true)

  local results = {}
  local widths = {
    name = 0,
    authorname = 0,
    upstream = 0,
    committerdate = 0,
  }
  local unescape_single_quote = function(v)
    return string.gsub(v, "\\([\\'])", "%1")
  end
  local parse_line = function(line)
    local fields = vim.split(string.sub(line, 2, -2), "''")
    local entry = {
      head = fields[1],
      refname = unescape_single_quote(fields[2]),
      authorname = unescape_single_quote(fields[3]),
      upstream = unescape_single_quote(fields[4]),
      committerdate = fields[5],
    }
    local prefix
    if vim.startswith(entry.refname, "refs/remotes/") then
      if show_remote_tracking_branches then
        prefix = "refs/remotes/"
      else
        return
      end
    elseif vim.startswith(entry.refname, "refs/heads/") then
      prefix = "refs/heads/"
    else
      return
    end
    local index = 1
    if entry.head ~= "*" then
      index = #results + 1
    end

    entry.name = string.sub(entry.refname, string.len(prefix) + 1)
    for key, value in pairs(widths) do
      widths[key] = math.max(value, strings.strdisplaywidth(entry[key] or ""))
    end
    if string.len(entry.upstream) > 0 then
      widths.upstream_indicator = 2
    end
    table.insert(results, index, entry)
  end
  for _, line in ipairs(output) do
    parse_line(line)
  end
  if #results == 0 then
    return
  end

  local displayer = entry_display.create {
    separator = " ",
    items = {
      { width = 1 },
      { width = widths.name },
      { width = widths.authorname },
      { width = widths.upstream_indicator },
      { width = widths.upstream },
      { width = widths.committerdate },
    },
  }

  local make_display = function(entry)
    return displayer {
      { entry.head },
      { entry.name, "TelescopeResultsIdentifier" },
      { entry.authorname },
      { string.len(entry.upstream) > 0 and "=>" or "" },
      { entry.upstream, "TelescopeResultsIdentifier" },
      { entry.committerdate },
    }
  end

  pickers
    .new(opts, {
      prompt_title = "Git Branches",
      finder = finders.new_table {
        results = results,
        entry_maker = function(entry)
          entry.value = entry.name
          entry.ordinal = entry.name
          entry.display = make_display
          return make_entry.set_default_entry_mt(entry, opts)
        end,
      },
      previewer = previewers.git_branch_log.new(opts),
      sorter = conf.file_sorter(opts),
      attach_mappings = function(_, map)
        actions.select_default:replace(actions.git_checkout)
        map({ "i", "n" }, "<c-t>", actions.git_track_branch)
        map({ "i", "n" }, "<c-r>", actions.git_rebase_branch)
        map({ "i", "n" }, "<c-a>", actions.git_create_branch)
        map({ "i", "n" }, "<c-s>", actions.git_switch_branch)
        map({ "i", "n" }, "<c-d>", actions.git_delete_branch)
        map({ "i", "n" }, "<c-y>", actions.git_merge_branch)
        return true
      end,
    })
    :find()
end

git.status = function(opts)
  if opts.is_bare then
    utils.notify("builtin.git_status", {
      msg = "This operation must be run in a work tree",
      level = "ERROR",
    })
    return
  end

  local args = { "status", "--porcelain=v1", "--", "." }

  local gen_new_finder = function()
    if vim.F.if_nil(opts.expand_dir, true) then
      table.insert(args, #args - 1, "-uall")
    end
    local git_cmd = git_command(args, opts)
    opts.entry_maker = vim.F.if_nil(opts.entry_maker, make_entry.gen_from_git_status(opts))
    return finders.new_oneshot_job(git_cmd, opts)
  end

  local initial_finder = gen_new_finder()
  if not initial_finder then
    return
  end

  pickers
    .new(opts, {
      prompt_title = "Git Status",
      finder = initial_finder,
      previewer = previewers.git_file_diff.new(opts),
      sorter = conf.file_sorter(opts),
      on_complete = {
        function(self)
          local lines = self.manager:num_results()
          local prompt = action_state.get_current_line()
          if lines == 0 and prompt == "" then
            utils.notify("builtin.git_status", {
              msg = "No changes found",
              level = "ERROR",
            })
            actions.close(self.prompt_bufnr)
          end
        end,
      },
      attach_mappings = function(prompt_bufnr, map)
        actions.git_staging_toggle:enhance {
          post = function()
            local picker = action_state.get_current_picker(prompt_bufnr)

            -- temporarily register a callback which keeps selection on refresh
            local selection = picker:get_selection_row()
            local callbacks = { unpack(picker._completion_callbacks) } -- shallow copy
            picker:register_completion_callback(function(self)
              self:set_selection(selection)
              self._completion_callbacks = callbacks
            end)

            -- refresh
            picker:refresh(gen_new_finder(), { reset_prompt = false })
          end,
        }

        map({ "i", "n" }, "<tab>", actions.git_staging_toggle)
        return true
      end,
    })
    :find()
end

local try_worktrees = function(opts)
  local worktrees = conf.git_worktrees

  if vim.tbl_islist(worktrees) then
    for _, wt in ipairs(worktrees) do
      if vim.startswith(opts.cwd, wt.toplevel) then
        opts.toplevel = wt.toplevel
        opts.gitdir = wt.gitdir
        if opts.use_git_root then
          opts.cwd = wt.toplevel
        end
        return
      end
    end
  end

  error(opts.cwd .. " is not a git directory")
end

local current_path_toplevel = function()
  local gitdir = vim.fn.finddir(".git", vim.fn.expand "%:p" .. ";")
  if gitdir == "" then
    return nil
  end
  return Path:new(gitdir):parent():absolute()
end

local set_opts_cwd = function(opts)
  opts.use_git_root = vim.F.if_nil(opts.use_git_root, true)
  if opts.cwd then
    opts.cwd = vim.fn.expand(opts.cwd)
  elseif opts.use_file_path then
    opts.cwd = current_path_toplevel()
    if not opts.cwd then
      opts.cwd = vim.fn.expand "%:p:h"
      try_worktrees(opts)
      return
    end
  else
    opts.cwd = vim.loop.cwd()
  end

  local toplevel, ret = utils.get_os_command_output({ "git", "rev-parse", "--show-toplevel" }, opts.cwd)

  if ret ~= 0 then
    local in_worktree = utils.get_os_command_output({ "git", "rev-parse", "--is-inside-work-tree" }, opts.cwd)
    local in_bare = utils.get_os_command_output({ "git", "rev-parse", "--is-bare-repository" }, opts.cwd)

    if in_worktree[1] ~= "true" and in_bare[1] ~= "true" then
      try_worktrees(opts)
    elseif in_worktree[1] ~= "true" and in_bare[1] == "true" then
      opts.is_bare = true
    end
  else
    if opts.use_git_root then
      opts.cwd = toplevel[1]
    end
  end
end

local function apply_checks(mod)
  for k, v in pairs(mod) do
    mod[k] = function(opts)
      opts = vim.F.if_nil(opts, {})

      set_opts_cwd(opts)
      v(opts)
    end
  end

  return mod
end

return apply_checks(git)
