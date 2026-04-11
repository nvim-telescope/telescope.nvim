# Contributing

Thanks for taking the time to submit code to Telescope if you're reading this!
We love having new contributors and love seeing the Neovim community come around this plugin and keep making it better.

At this time, we are content with the number and functionality of the pickers we offer built
in with Telescope and so we are currently not accepting new pickers
(see this [issue](https://github.com/nvim-telescope/telescope.nvim/issues/1228) for a discussion on this).

We are also conservative with integrating picker specific actions and features.
If you're still interested in filling a particular picker need, we encourage packaging it up as its own Telescope extension.
Read our [Bundling as extension](https://github.com/nvim-telescope/telescope.nvim/blob/master/developers.md#bundling-as-extension) guide here for more info on this.
See other Telescope extensions (and add yours) [here](https://github.com/nvim-telescope/telescope.nvim/wiki/Extensions).

That said, we welcome bug fixes, documentation improvements and non-picker specific features.
If you're submitting a new feature, it is a good idea to create an issue first to gauge interest and feasibility.

To learn how we go about writing documentation for this project, keep reading below!

## Documentation

The docs are generated from the code using emmylua annotations. To update them after making changes to the code, run `make docgen`. A "Check docs" workflow in CI ensures that the documentation matches any change to the code and its annotations.
