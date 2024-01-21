local core = require 'core'
local common = require 'core.common'
local util = require 'plugins.miq.util'
local Promise = require 'plugins.miq.promise'

local M = {}

function M.installPlugin(spec)
	local promise = Promise.new()
	core.add_thread(function()
		local plugin = util.plugName(common.basename(spec.plugin))
		local src = common.home_expand(spec.plugin)
		if not util.fileExists(src) then
			promise:reject(string.format('Source %s does not exist', src))
		end

		local destDir = USERDIR .. string.format('/%s/', spec.library and 'libraries' or 'plugins')
		system.mkdir(destDir)

		local out, _ = util.exec {'ln', '-s', src, util.join {destDir, spec.name or plugin, ''}}
		promise:resolve()
	end)
	return promise
end

function M.updatePlugin(_)
	-- noop - local plugins should be updated separately
	local promise = Promise.new()
	promise:resolve(true)
	return promise
end

return M
