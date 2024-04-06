local core = require 'core'
local common = require 'core.common'
local util = require 'plugins.miq.util'
local Promise = require 'plugins.miq.promise'

local M = {}

function M.req(url)
	local promise = Promise:new()

	core.add_thread(function()
		local out = util.exec {'curl', '--fail', '-s', url}
		if not out then promise:reject() end

		if out.exitCode ~= 0 then
			promise:reject {
				success = false,
				out = out
			}
			return
		end

		promise:resolve {
			success = true,
			out = out
		}
	end)
	return promise
end

function M.download(url, dest)
	local destDir = util.dir(dest)
	local fname = common.basename(dest)

	local promise = Promise:new()
	core.add_thread(function()
		local out, exitCode = util.exec {'curl', '-L', '--create-dirs', '--output-dir', destDir, '--fail', url, '-o', fname}
		if not out then promise:reject() end

		if exitCode ~= 0 then
			return promise:reject(out)
		else
			return promise:resolve(out)
		end
	end)
	return promise
end

return M
