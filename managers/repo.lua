local core = require 'core'
local common = require 'core.common'
local util = require 'plugins.miq.util'
local db = require 'plugins.miq.db'
local manifestlib = require 'plugins.miq.manifest'
local localManager = require 'plugins.miq.managers.local'
local Promise = require 'plugins.miq.promise'
local request = require 'plugins.miq.request.curl'

local M = {}

local repoDir = USERDIR .. '/miq-repos/'
function M.installPlugin(spec)
	local promise = Promise.new()
	core.add_thread(function()
		local setup = false
		local manifests = db.manifests()

		local function setupPlugin(repo)
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

					spec.repo = repo
					local src = addon.path and (repoDir .. repo .. '/' .. addon.path) or (repoDir .. repo)
					local name = addon.path and common.basename(addon.path) or spec.id

					localManager.installPlugin({
						plugin = src,
						name = name,
						library = addon.type == 'library'
					}):done(function()
						-- handle files
						if addon.files then
							for _, file in ipairs(addon.files) do
								if file.arch then
									if type(file.arch) == 'table' then
										if not util.contains(file.arch, ARCH) then goto continue end
									elseif type(file.arch) == 'string' then
										if file.arch ~= ARCH then goto continue end
									else
										promise:reject(string.format('Miq/Repo Manager: Invalid arch type found in plugin %s from repo %s', addon.id, spec.repo))
									end
								end

								local filename = common.basename(file.url)
								local destDir = util.join {USERDIR, spec.library and 'libraries' or 'plugins'}
								local archivePath = util.join {destDir, filename}

								request.download(file.url, archivePath)
								:done(function()
									local extractor
									local extToChop

									if filename:match '%.tar%.gz$' or filename:match '%.tar' then
										extToChop = filename:match '%.tar%.gz$' or filename:match '%.tar'
										extractor = require 'plugins.miq.extractors.tar'
									end

									if extractor then
										extractor.extract(archivePath, util.join {destDir, addon.id})
										:done(function()
											os.remove(archivePath)
											promise:resolve()
										end)
										:fail(function(out)
											os.remove(archivePath)
											promise:reject(out)
										end)
									end
								end)
								:fail(function(res)
									promise:reject(res)
								end)

								::continue::
							end
						end
					end)
					:fail(function(...) promise:reject(...) end)
					setup = true
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
