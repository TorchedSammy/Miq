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

		local destDir = USERDIR .. string.format('/%s/', spec.library and 'libraries' or 'plugins')
		local dest = util.join {destDir, spec.name or plugin, ''}
		system.mkdir(destDir)

		if not util.fileExists(src) then
			promise:reject(string.format('Source %s does not exist', src))
		end

		if util.fileExists(dest) then
			promise:resolve()
			return
		end


		local out, code = util.exec {'ln', '-s', src, dest}
		if code ~= 0 then promise:reject(out) else promise:resolve() end
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
