-- mod-version:3
local core = require 'core'
local common = require 'core.common'
local command = require 'core.command'
local config = require 'core.config'
local managers = require 'plugins.miq.managers'
local util = require 'plugins.miq.util'

config.plugins.miq = common.merge({
	lpm_prefix = '',
	fallback = true,
	plugins = {}
}, config.plugins.miq)

local M = {}

function M.install()
	for _, _p in ipairs(config.plugins.miq.plugins) do
		local p = type(_p) == 'string' and {_p} or _p
		local nameOrUrl = p[1]

		-- TODO: check if name or url can be slugified early,
		-- and block if it cant
		-- unless the user has specified a repo url
		-- (this is in the case of single files NOT managed by lpm, like bigclock)
		local name = util.plugName(nameOrUrl)

		local mg = managers[p.installMethod or 'lpm']
		mg.installPlugin(nameOrUrl):done(function()
			core.log(string.format('[Miq] Installed %s!', name))
		end):fail(function(log)
			if not config.plugins.miq.fallback then
				print(log)
				core.log(string.format('[Miq] Could not install %s.', name))
				return
			end
			if config.plugins.miq.fallback and p.installMethod ~= 'miq' then
				managers.miq.installPlugin(nameOrUrl)
			end
		end)
	end
end

command.add(nil, {
	['miq:install'] = function()
		M.install()
	end
})
return M
