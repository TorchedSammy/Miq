local common = require 'core.common'
local json = require 'plugins.miq.json'
local util = require 'plugins.miq.util'

local manifests = {} -- hexified keys for repo urls (excluding the tag)
local data = {
	plugins = {},
	repos = {} -- keys are hexified
}
local M = {}

function M.init()
	if util.fileExists(USERDIR .. '/.miq-store') then
		data = dofile(USERDIR .. '/.miq-store') or data
	end
end

function M.write()
	local f = io.open(USERDIR .. '/.miq-store', 'w+')
	if not f then return end -- TODO?
	f:write('return ' .. common.serialize(data))

	f:close()
end

function M.addPlugin(spec)
	data.plugins[spec.plugin] = spec
	M.write()
end

function M.getPlugin(id)
	local plug = data.plugins[id]
	if plug then
		return plug
	end
end

function M.addRepo(repo, manifest)
	if not data.repos then data.repos = {} end

	data.repos[repo] = true
	manifests[repo] = json.decode(manifest)
end

function M.manifests()
	return manifests
end

return M
