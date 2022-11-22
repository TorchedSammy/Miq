local core = require 'core'
local util = require 'plugins.miq.util'
local Promise = require 'plugins.miq.promise'

local M = {}

function M.installPlugin(nameOrUrl)
	local url = nameOrUrl
	local slug = util.slugify(nameOrUrl)
	if not util.isURL(nameOrUrl) then
		-- TODO: check if nameOrUrl can be slugified
		url = 'https://github.com/' .. nameOrUrl
	end

	local promise = Promise.new()
	core.add_thread(function()
		local plugin = util.plugName(slug)
		local _, _ = util.exec {'git', 'clone', url, USERDIR .. '/plugins/' .. plugin}
		promise:resolve()
	end)
	return promise
end
return M
