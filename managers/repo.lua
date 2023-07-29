local core = require 'core'
local common = require 'core.common'
local util = require 'plugins.miq.util'
local db = require 'plugins.miq.db'
local localManager = require 'plugins.miq.managers.local'
local Promise = require 'plugins.miq.promise'

local M = {}

local repoDir = USERDIR .. '/miq-repos/'
function M.installPlugin(spec)
	local promise = Promise.new()
	core.add_thread(function()
		for repo, manifest in pairs(db.manifests()) do
			for _, addon in ipairs(manifest.addons) do
				if addon.id == spec.name then
					if addon.type and addon.type ~= 'plugin' then return end
					localManager.installPlugin({
						plugin = repoDir .. repo .. '/' .. addon.path,
						name = spec.name
					}):forward(promise)
				end
			end
		end
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
