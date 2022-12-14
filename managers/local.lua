local core = require 'core'
local common = require 'core.common'
local util = require 'plugins.miq.util'
local Promise = require 'plugins.miq.promise'

local M = {}

function M.installPlugin(spec)
	local promise = Promise.new()
	core.add_thread(function()
		local plugin = util.plugName(common.basename(spec.plugin))
		local _, _ = util.exec {'ln', '-s', common.home_expand(spec.plugin), USERDIR .. '/plugins/' .. plugin}
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
