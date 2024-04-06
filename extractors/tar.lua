local core = require 'core'
local util = require 'plugins.miq.util'
local Promise = require 'plugins.miq.promise'

local M = {}

function M.extract(file, cwd)
	local dir = cwd or util.dir(file)
	system.mkdir(dir)

	local promise = Promise:new()
	core.add_thread(function()
		local out, exitCode = util.exec {'tar', 'xvf' .. (util.ext(file) == 'gz' and 'z' or ''), file, '-C', dir}
		if exitCode ~= 0 then
			return promise:reject(out)
		end

		return promise:resolve()
	end)
	return promise
end

return M
