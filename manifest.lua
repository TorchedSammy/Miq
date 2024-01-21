local db = require 'plugins.miq.db'
local util = require 'plugins.miq.util'

local M = {}

local repoDir = USERDIR .. '/miq-repos/'
local function updateManifestCache(repo)
	local f = io.open(repoDir .. util.repoDir(repo) .. '/manifest.json')
	local content = f:read '*a'
	db.addRepo(util.repoDir(repo), content)
end

-- repo is a string with the following format:
-- url:tag
-- example https://github.com/lite-xl/lite-xl-plugins.git:2.1
function M.downloadRepo(repo, dir)
	local url = util.repoURL(repo)
	local tag = util.repoTag(repo)
	local dir = dir or repoDir .. util.repoDir(repo)

	if not util.fileExists(repoDir .. util.repoDir(repo)) then
		local out, code = util.exec {'git', 'clone', url, dir}
		if code ~= 0 then
			return out, code
		end
	end

	local out, code = util.exec {'sh', '-c', string.format('cd %s && git checkout %s', dir, tag)}
	if code == 0 then
		updateManifestCache(repo)
	end

	return out, code
end

return M
