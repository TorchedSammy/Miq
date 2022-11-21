-- mod-version:3
local core = require 'core'
local common = require 'core.common'
local command = require 'core.command'
local config = require 'core.config'

config.plugins.miq = common.merge({
	lpm_prefix = '',
	fallback = true,
	plugins = {}
}, config.plugins.miq)

local Promise = {}
function Promise:__index(idx) return rawget(self, idx) or Promise[idx] end
function Promise.new(result) return setmetatable({ result = result, success = nil, _done = { }, _fail = { } }, Promise) end
function Promise:done(done) if self.success == true then done(self.result) else table.insert(self._done, done) end return self end
function Promise:fail(fail) if self.success == false then fail(self.result) else table.insert(self._fail, fail) end return self end
function Promise:resolve(result) self.result = result self.success = true for i,v in ipairs(self._done) do v(result) end return self end
function Promise:reject(result) self.result = result self.success = false for i,v in ipairs(self._fail) do v(result) end return self end
function Promise:forward(promise) self:done(function(data) promise:resolve(data) end) self:fail(function(data) promise:reject(data) end) return self end

local function join(joiner, t) local s = '' for i,v in ipairs(t) do if i > 1 then s = s .. joiner end s = s .. v end return s end

local function exec(cmd, opts)
	local proc = process.start(cmd, opts or {})
	if proc then
		while proc:running() do
			coroutine.yield(0.1)
		end
		return proc:returncode()
	end

	return nil
end
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

local function isRepoUrl(url)
	return url:match '%w+/%w+$'-- or url:match '%w+://'
end

local function fullLinkify(name)
	return 'https://github.com/' .. name
end

local function plugName(slug)
	local name = string.lower(slug:match '[^/]+$')
	return name:gsub('.lxl$', ''):gsub('^lite-xl-', '')
end

-- lpm methods
local function lpmAddRepo(url)
	-- TODO: dont attempt to add if already present (not sure what this would 
	-- save but it definitely prevents an extra log??)
	run {'add', url}:done(function(res)
		core.log_quiet(string.format('[Miq] Added LPM respository %s.', url))
	end)
end

local function lpmInstall(plugin)
	return run {'plugin', 'install', plugin}
end

-- miq methods
local function miqInstall(slug)
	local url = fullLinkify(slug)

	exec {'git', 'clone', url, USERDIR .. '/plugins/' .. plugName(slug)}
end

local M = {}

function M.install()
	for _, _p in ipairs(config.plugins.miq.plugins) do
		local p = type(_p) == 'string' and {_p} or _p
		local name = p[1]

		if isRepoUrl(name) then
			lpmAddRepo(fullLinkify(name))
		end

		local realName = plugName(name)
		lpmInstall(realName):done(function()
			core.log(string.format('[Miq] Installed %s!', realName))
		end):fail(function(log)
			if not config.plugins.miq.fallback then
				print(log)
				core.log(string.format('[Miq] Could not install %s.', realName))
				return
			end
			miqInstall(name)
		end)
	end
end

command.add(nil, {
	['miq:install'] = function()
		M.install()
	end
})
return M
