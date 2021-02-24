# Documentation

is generating docs based on the tree sitter syntax tree. TJ wrote a grammar that includes the documentation in this syntax tree so we can do take this function header documentation and transform it into vim documentation. All documentation will be exported that is part of the returning module. So example:

local m = {}

--- Test Header
--@return 1: Returns always 1
function m.a()
  return 1
end

return m

Something like this.
What is missing?

The docgen has some problems on which people can work. This would happen in https://github.com/tjdevries/tree-sitter-lua and documentation of some modules here.
I would suggest we are documenting lua/telescope/builtin/init.lua rather than the files itself. We can use that init.lua file as "header" file, so we are not cluttering the other files.
How to do it:


## Auto-updates from CI

The easy way would be after this PR is merged

    write some docs
    commit and push
    wait a minute until the CI generates a new commit with the changes
    Look at this commit and the changes
    And apply new changes with git commit --amend and git push --force to remove that github ci commit again.
    Repeat until done

## Generate on your local machine

The other option would be setting up https://github.com/tjdevries/tree-sitter-lua

    Install Treesitter, either with package manager or with github release
    Install plugin as usual
    cd to plugin
    mkdir -p build parser Sadly does doesn't exist laughing
    make build_parser
    ln -s ../build/parser.so parser/lua.so We need the so in parser/ so it gets picked up by neovim. Either copy or symbolic link
    Make sure that nvim-treesitter lua parser is not installed and also delete the lua queries in that repository. queries/lua/*. If you are not doing that you will have a bad time
    cd into this project
    Write doc
    Run make docgen
    Repeat last two steps
