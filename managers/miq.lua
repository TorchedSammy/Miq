local core = require 'core'
local util = require 'plugins.miq.util'
local Promise = require 'plugins.miq.promise'

local M = {}

function M.installPlugin(spec)
	local url = spec.plugin
	if not util.isURL(spec.plugin) then
		-- TODO: check if nameOrUrl can be slugified
		url = 'https://github.com/' .. spec.plugin
	end

	local promise = Promise.new()
	core.add_thread(function()
		local _, _ = util.exec {'git', 'clone', url, USERDIR .. '/plugins/' .. spec.name}
		promise:resolve()
	end)
	return promise
end

function M.updatePlugin(spec)
	local promise = Promise.new()
	core.add_thread(function()
		local pdir = USERDIR .. '/plugins/' .. spec.name
		local log, code = util.gitCmd({'pull'}, pdir)
		if code ~= 0 then
			promise:reject()
			return
		end

		promise:resolve(log:match 'Already up to date' and true or false)
	end)
	return promise
end

return M
