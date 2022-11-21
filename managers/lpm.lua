local core = require 'core'
local config = require 'core.config'
local util = require 'plugins.miq.util'
local Promise = require 'plugins.miq.promise'

local M = {}

local function join(joiner, t) local s = '' for i,v in ipairs(t) do if i > 1 then s = s .. joiner end s = s .. v end return s end

local running_processes = {}
local function run(cmd)
	table.insert(cmd, 1, config.plugins.miq.lpm_prefix .. 'lpm')
	table.insert(cmd, '--json')
	table.insert(cmd, '--mod-version=' .. MOD_VERSION)
	--table.insert(cmd, '--quiet')
	table.insert(cmd, '--userdir=' .. USERDIR)
	table.insert(cmd, '--datadir=' .. DATADIR)
	table.insert(cmd, '--binary=' .. EXEFILE)
	table.insert(cmd, '--assume-yes')
	local proc = process.start(cmd)
	local promise = Promise.new()
	table.insert(running_processes, { proc, promise, '' })
	if #running_processes == 1 then
		core.add_thread(function()
			while #running_processes > 0 do
				local still_running_processes = {}
				local has_chunk = false
				local i = 1
				while i < #running_processes + 1 do
					local v = running_processes[i]
					local still_running = true
					while true do
						local chunk = v[1]:read_stdout(2048)
						if config.plugins.miq.debug and chunk ~= nil then io.stdout:write(chunk) io.stdout:flush() end
						if chunk and v[1]:running() and #chunk == 0 then break end
						if chunk ~= nil and #chunk > 0 then
							v[3] = v[3] .. chunk
							has_chunk = true
						else
							still_running = false
							if v[1]:returncode() == 0 then
								v[2]:resolve(v[3])
							else
								local err = v[1]:read_stderr(2048)
								v[2]:reject(v[3], join(' ', cmd))
							end
							break
						end
					end
					if still_running then
						table.insert(still_running_processes, v)
					end
					i = i + 1
				end
				running_processes = still_running_processes
				coroutine.yield(has_chunk and 0.001 or 0.1)
			end
		end)
	end
	return promise
end

function M.addRepo(url)
	-- TODO: dont attempt to add if already present (not sure what this would 
	-- save but it definitely prevents an extra log??)
	run {'add', url}:done(function()
		core.log_quiet(string.format('[Miq] Added LPM respository %s.', url))
	end)
end

function M.installPlugin(urlOrName)
	if util.isURL(urlOrName) then
		M.addRepo(urlOrName)
		urlOrName = util.slugify(urlOrName)
	end

	local plugin = util.plugName(urlOrName)
	return run {'plugin', 'install', plugin}
end

return M
