local core = require 'core'
local common = require 'core.common'
local util = require 'plugins.miq.util'
local db = require 'plugins.miq.db'
local manifestlib = require 'plugins.miq.manifest'
local localManager = require 'plugins.miq.managers.local'
local Promise = require 'plugins.miq.promise'

local M = {}

local repoDir = USERDIR .. '/miq-repos/'
function M.installPlugin(spec)
	local promise = Promise.new()
	core.add_thread(function()
		local setup = false
		local manifests = db.manifests()

		local function setupPlugin(repo)
			-- match is for preventative measure against a user who includes the tag
			-- the repo field in a plugin spec isn't supposed to have it,
			-- since having a plugin on a specific version of a plugin repo
			-- does not seem like the most wise thing
			local manifest = manifests[repo]
			for _, addon in ipairs(manifest.addons) do
				if addon.id == spec.name then
					if addon.type and (addon.type ~= 'plugin' and addon.type ~= 'library') then return end
					if addon.remote then
						local out, code = manifestlib.downloadRepo(addon.remote)
						if code ~= 0 then
							promise:reject(out)
							return true
						end

						spec.repo = addon.remote
						setupPlugin(util.repoDir(spec.repo))

						return true
					end

					if addon.path or addon.type == 'library' then
						localManager.installPlugin({
							plugin = addon.type ~= 'library' and (repoDir .. repo .. '/' .. addon.path) or (repoDir .. repo),
							name = addon.path and common.basename(addon.path) or spec.name,
							library = addon.type == 'library'
						}):forward(promise)
						setup = true
						return true
					end
				end
			end
		end

		if spec.repo then
			setupPlugin(util.repoDir(spec.repo))
		else
			local stop
			for repo, manifest in pairs(db.manifests()) do
				stop = setupPlugin(repo)
				if stop then break end
			end

			if not setup and not stop then
				promise:reject('No suitable addon repository found.')
			end
		end
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
