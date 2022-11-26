local common = require 'core.common'
local util = require 'plugins.miq.util'

local data = {
	plugins = {}
}
local M = {}

function M.init()
	if util.fileExists(USERDIR .. '/.miq-store') then
		data = dofile(USERDIR .. '/.miq-store') or data
	end
end

function M.write()
	local f <close> = io.open(USERDIR .. '/.miq-store', 'w+')
	if not f then return end -- TODO?
	f:write('return ' .. common.serialize(data))
end

function M.addPlugin(spec)
	data.plugins[spec.plugin] = spec
	M.write()
end

function M.getPlugin(id)
	return data.plugins[id]
end

return M
