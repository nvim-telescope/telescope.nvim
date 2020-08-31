

builtin.git_files = function(opts)
  opts = opts or {}

  opts.show_preview = get_default(opts.show_preview, true)

  opts.finder = opts.finder or finders.new {
    static = true,

    fn_command = function()
      return {
        command = 'git',
        args = {'ls-files'}
      }
    end,
  }

  opts.prompt = opts.prompt or 'Simple File'
  opts.previewer = opts.previewer or previewers.cat
  opts.sorter = opts.sorter or sorters.get_norcalli_sorter()

  pickers.new(opts):find()
end
