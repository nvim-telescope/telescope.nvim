vim.opt.rtp:prepend "../plenary.nvim"
vim.opt.rtp:prepend "."
vim.opt.rtp:prepend ".deps/docgen.nvim"

require("docgen").run {
  name = "telescope",
  description = "Find, Filter, Preview, Pick. All lua, all the time.",
  files = {
    {
      "./lua/telescope/init.lua",
      title = "INTRODUCTION",
      tag = "telescope.nvim",
      fn_prefix = "telescope",
      fn_tag_prefix = "telescope",
    },
    -- "./lua/telescope/pickers.lua"
    "./lua/telescope/command.lua",
    "./lua/telescope/builtin/init.lua",
    "./lua/telescope/themes.lua",
    "./lua/telescope/mappings.lua",
    { "./lua/telescope/pickers/layout.lua", title = "LAYOUT", tag = "telescope.layout", fn_prefix = "layout" },
    {
      "./lua/telescope/pickers/layout_strategies.lua",
      title = "LAYOUT_STRATEGIES",
      tag = "telescope.layout_strategies",
      fn_prefix = "layout_strategies",
    },
    { "./lua/telescope/config/resolve.lua", title = "RESOLVE", tag = "telescope.resolve", fn_prefix = "resolver" },
    "./lua/telescope/make_entry.lua",
    "./lua/telescope/pickers/entry_display.lua",
    "./lua/telescope/utils.lua",
    "./lua/telescope/actions/init.lua",
    "./lua/telescope/actions/state.lua",
    "./lua/telescope/actions/set.lua",
    "./lua/telescope/actions/layout.lua",
    "./lua/telescope/actions/utils.lua",
    "./lua/telescope/actions/generate.lua",
    { "./lua/telescope/actions/history.lua", fn_prefix = "histories" },
    "./lua/telescope/previewers/init.lua",
  },
}
