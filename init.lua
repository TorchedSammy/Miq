-- mod-version:3
local core = require 'core'
local common = require 'core.common'
local command = require 'core.command'
local config = require 'core.config'
local db = require 'plugins.miq.db'
local managers = require 'plugins.miq.managers'
local util = require 'plugins.miq.util'
local Promise = require 'plugins.miq.promise'

db.init()

config.plugins.miq = common.merge({
	lpm_prefix = '',
	installMethod = 'miq',
	fallback = true,
	debug = false,
	plugins = {}
}, config.plugins.miq)

local function log(msg)
	if config.plugins.miq.debug then
		core.log_quiet(tostring(msg))
	end
end

local function pluginIterate(fun)
	for _, _p in ipairs(config.plugins.miq.plugins) do
		local p = type(_p) == 'string' and {plugin = _p} or _p
		p.plugin = p[1] or p.plugin
		fun(p)
	end
end

local function pluginExists(name)
	return util.fileExists(USERDIR .. '/plugins/' .. name) or util.fileExists(USERDIR .. '/plugins/' .. name .. '.lua')
end

local function postInstall(spec)
	local promise = Promise.new()
	core.add_thread(function()
		local folder = USERDIR .. '/plugins/' .. util.plugName(spec.plugin)
		local logs, exit = util.exec {'sh', '-c', string.format('cd %s && %s', folder, spec.run)}
		if exit ~= 0 then
			promise:reject(logs)
			return
		end
		promise:resolve()
	end)
	return promise
end

local function isFilePath(path)
	local prefixes = {
		'~/',
		'/',
		'../',
		'./'
	}
	for _, pref in ipairs(prefixes) do
		if path:find(pref, 1, true) == 1 then
			return true
		end
	end

	return false
end

local M = {}

function M.installSingle(spec)
	spec.installMethod = spec.installMethod or (isFilePath(spec.plugin) and 'local') or config.plugins.miq.installMethod
	local mg = managers[spec.installMethod]
	local name = util.plugName(spec.plugin)

	log(string.format('[Miq] (Debug) Using %s install method for %s', spec.installMethod, name))

	local didpost
	local fail
	local function done()
		if not spec.run or didpost then
			core.log(string.format('[Miq] Installed %s!', name))
			db.addPlugin(spec)
			return
		end
		didpost = true
		postInstall(spec):done(done):fail(fail)
	end
	fail = function(err)
		if not config.plugins.miq.fallback or spec.installMethod == 'miq' then
			core.error(string.format('[Miq] Could not install %s.\n%s', name, err))
			return
		end
		if config.plugins.miq.fallback and spec.installMethod ~= 'miq' then
			spec.installMethod = 'miq'
			managers.miq.installPlugin(spec.plugin):done(done):fail(fail)
			return
		end
	end
	mg.installPlugin(spec.plugin):done(done):fail(fail)
end

function M.reinstallSingle(spec)
	M.remove(spec)
	M.installSingle(spec)
end

function M.remove(spec)
	local slug = util.slugify(spec.plugin)
	local name = util.plugName(spec.plugin)
	-- a name that cannot be slugified is a singleton,
	-- and we want to cover the edge case of someone having a singleton
	-- and non singleton with the same name (its the correct thing to do anyway)
	if slug then
		os.remove(USERDIR .. '/plugins/' .. name)
	else
		os.remove(USERDIR .. '/plugins/' .. name .. '.lua')
	end
	-- TODO: remove from db
end

function M.install()
	pluginIterate(function(p)
		-- TODO: check if name or url can be slugified early,
		-- and block if it cant
		-- unless the user has specified a repo url
		-- (this is in the case of single files NOT managed by lpm, like bigclock)
		local name = util.plugName(p.plugin)

		if pluginExists(name) then
			core.log(string.format('[Miq] %s is already installed.', name))
			return
		end
		M.installSingle(p)
	end)
end

function M.reinstall()
	pluginIterate(function(p)
		local name = util.plugName(p.plugin)

		if pluginExists(name) then
			M.reinstallSingle(p)
		end
	end)
end

function M.update()
	pluginIterate(function(p)
		local realName = util.plugName(p.plugin)

		if not pluginExists(realName) then
			M.installSingle(p)
			return
		end
		local dbPlug = db.getPlugin(p.plugin)
		if not dbPlug then
			M.reinstallSingle(p)
			return
		end
		local installMethod = dbPlug.installMethod
		local mg = managers[installMethod]

		mg.updatePlugin(realName):done(function(already)
			if already then
				core.log(string.format('[Miq] %s has already been updated.', realName))
				return
			end
			core.log(string.format('[Miq] Updated %s!', realName))
		end):fail(function()
			core.log(string.format('[Miq] Could not update %s.', realName))
		end)
	end)
end

command.add(nil, {
	['miq:install'] = function()
		M.install()
	end,
	['miq:reinstall'] = function()
		M.reinstall()
	end,
	['miq:update'] = function()
		M.update()
	end,
})
return M
