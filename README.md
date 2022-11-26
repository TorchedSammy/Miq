# Miq
> 🐌 Packer-inspired plugin Manager for Lite XL.

Miq is a *declarative* plugin manager for Lite XL, inspired by packer
for Neovim. Miq plugins are installed by declaring them in a Lua table,
then either calling the `install` function or running the install command.

> **Warning**
> Miq is work in progress!
> To test out Miq, I use it myself, but there may be other problems.
> If there are, please report them by opening an issue.

# Install
Miq can be installed like any other Lite XL plugin, since it is pure Lua.
Clone Miq to your Lite XL plugins directory:  
```
git clone https://github.com/TorchedSammy/Miq ~/.config/lite-xl/plugins/miq
```

# Quickstart
Here is an example of how to specify Miq plugins:
```lua
local config = require 'core.config'

-- Plugins are specified in this table:
config.plugins.miq.plugins = {
	-- Miq can manage itself
	'TorchedSammy/Miq',

	-- Normal plugins hosted on a single git repo can be specified with AuthorName/RepoName
	'lite-xl/lite-xl-lsp',

	-- If needed, you can setup a local plugin, which will simply be symlinked.
	-- I personally do this for Miq.
	'~/lite-xl-plugin-path'

	-- Any native plugin or similar that needs compiling can have a post install command.
	{'TorchedSammy/Litepresence', run = 'go get && go build'}

	-- The destination plugin name can be specified if other plugins rely on a special name
	-- (gitdiff-highlight requires itself with an underscore)
	{'vincens2005/lite-xl-gitdiff-highlight', name = 'gitdiff_highlight'}
}
```

Once all plugins are specified, the `Miq: Install` command can be ran to install them.

# Details
## Plugin Spec
Each plugin is defined via its spec. When declaring a plugin as a string,
the fields will be filled in with their defaults. If you want to specify more though,
you need to declare it as a table.

Here are the available fields for a plugin spec:
```lua
{
	-- The identifier for the plugin. This is usually in the form of the
	-- slug (AuthorName/RepoName) and does not need to be specified as
	-- `plugin`, since the 1st key of the spec will be used as it.
	plugin = '',
	-- A command to run after installing/upgrading plugins
	run = '',
	-- The name of the plugin when installed. This is mainly intended for
	-- "complex" plugins (those on single repos) which expect a different
	-- name than what Miq defaults to.
	-- By default, this will simply be based on the identifier, lowercasing it
	-- and removing "lite-xl-" prefixes and ".lxl" suffixes
	name = ''
}
```

# License
MIT
