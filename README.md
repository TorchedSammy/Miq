# Miq
> 🐌 Packer-inspired plugin Manager for Lite XL.

Miq is a *declarative* plugin manager for Lite XL, inspired by packer
for Neovim. Miq plugins are installed by declaring them in a Lua table,
then either calling the `install` function or running the install command.

Miq is based on the LPM plugin manager (linked below), but can
still install plugins on its own.

> **Warning**
> Miq is work in progress!

# Install
Miq can work with [LPM](https://github.com/adamharrison/lite-xl-plugin-manager)
if it is installed. You can simply follow the instructions to build the executable,
then either put it in your path or set `lpm_prefix`:
```lua
local config = require 'core.config'

-- ~/lite-xl-plugin/manager
config.plugins.miq.lpm_prefix = HOME .. '/lite-xl-plugin-manager'
```

Reminder that if you do not want to setup LPM, Miq will install plugins fine.

# Usage
Miq plugins can be declared like so:

```lua
local config = require 'core.config'

config.plugins.miq.plugins = {
	'bigclock',
	'gitstatus',
	'language_go',
	'TorchedSammy/Litepresence'
}
```

And then installed via the `Miq: Install` command.
Once installed, you can restart Lite XL for all your plugins.

# License
MIT
