-- mod-version:3
local core = require 'core'
local common = require 'core.common'
local command = require 'core.command'
local config = require 'core.config'
local db = require 'plugins.miq.db'
local managers = require 'plugins.miq.managers'
local util = require 'plugins.miq.util'
local json = require 'plugins.miq.json'
local Promise = require 'plugins.miq.promise'

db.init()

config.plugins.miq = common.merge({
	installMethod = 'miq',
	fallback = true,
	debug = false,
	plugins = {},
	storeDir = string.format('%s/.local/share/miq', HOME),
	repos = {
		'https://github.com/lite-xl/lite-xl-plugins.git:2.2'
	}
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
		p.name = p.name or util.plugName(p.plugin)
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
	spec.installMethod = spec.installMethod
	or (isFilePath(spec.plugin) and 'local')
	or config.plugins.miq.installMethod

	local slug = util.slugify(spec.plugin)
	if not slug or spec.repo then
		-- assume this is a plugin from a multi-plugin repo
		spec.installMethod = 'repo'
	end

	local name = spec.name or util.plugName(spec.plugin)
	local mg = managers[spec.installMethod]

	log(string.format('[Miq] (Debug) Using %s install method for %s', spec.installMethod, name))

	local didpost
	local fail
	local function done()
		if not spec.run or didpost then
			core.log(string.format('[Miq] Installed %s', name))
			spec.fullyInstalled = true
			db.addPlugin(spec)
			return
		end
		didpost = true
		postInstall(spec):done(done):fail(fail)
	end
	fail = function(err)
		core.error(string.format('[Miq] Could not install %s\n%s', name, err))
		spec.fullyInstalled = false
		db.addPlugin(spec)
	end
	mg.installPlugin(spec)
	:done(done)
	:fail(fail)
end

function M.reinstallSingle(spec)
	M.remove(spec)
	M.installSingle(spec)
end

function M.remove(spec)
	local slug = util.slugify(spec.plugin)
	local name = spec.name
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

local repoDir = USERDIR .. '/miq-repos/'
-- repo is a string with the following format:
-- url:tag
-- example https://github.com/lite-xl/lite-xl-plugins.git:2.1
function M.downloadRepo(url, tag, dir)
	local out, code = util.exec {'git', 'clone', url, dir}
	if code ~= 0 then
		return out, code
	end

	local out, code = util.exec {'sh', '-c', string.format('cd %s && git checkout %s', dir, tag)}
	return out, code
end

local function updateManifestCache(repo)
	local f = io.open(repoDir .. util.repoDir(repo) .. '/manifest.json')
	local content = f:read '*a'
	db.addRepo(util.repoDir(repo), content)
end

function M.install()
	local p = Promise.new()
	core.add_thread(function()
		-- handle repos first (if supplied)
		for _, repo in ipairs(config.plugins.miq.repos) do
			local url = util.repoURL(repo)
			local tag = util.repoTag(repo)
			if not util.fileExists(repoDir .. util.repoDir(repo)) then
				local out, code = M.downloadRepo(url, tag, repoDir .. util.repoDir(repo))
				if code ~= 0 then
					--core.error(string.format('[Miq] Could not switch to tag of %s for plugin repo %s\n%s', tag, url, out))
					p:reject(out)
				else
					updateManifestCache(repo)
				end
			end
		end
		p:resolve()

		p:done(function()
			pluginIterate(function(p)
				-- TODO: check if name or url can be slugified early,
				-- and block if it cant
				-- unless the user has specified a repo url
				-- (this is in the case of single files like bigclock)
				local name = p.name
				local dbPlugin = db.getPlugin(p.plugin) or {}
				local fullyInstalled = dbPlugin.fullyInstalled

				if (pluginExists(name) and (p.run and fullyInstalled)) or (not p.run and pluginExists(name))then
					core.log(string.format('[Miq] %s is already installed', name))
					return
				end
				M.installSingle(p)
			end)
		end)
	end)
end

function M.reinstall()
	pluginIterate(function(p)
		local name = p.name

		if pluginExists(name) then
			M.reinstallSingle(p)
		end
	end)
end

function M.update()
	pluginIterate(function(p)
		local realName = p.name

		if not pluginExists(realName) then
			M.installSingle(p)
			return
		end
		log(string.format('[Miq] Attempting to update %s', realName))
		local dbPlug = db.getPlugin(p.plugin)
		if not dbPlug then
			M.reinstallSingle(p)
			return
		end
		local installMethod = dbPlug.installMethod or (isFilePath(dbPlug.plugin) and 'local') or config.plugins.miq.installMethod
		local mg = managers[installMethod]
		log(installMethod)

		local didpost
		local fail
		local function done(already)
			if already then
				core.log(string.format('[Miq] %s has already been updated', realName))
				return
			end

			if not p.run or didpost then
				core.log(string.format('[Miq] Updated %s', realName))
				-- set install method again to make it known.
				-- fixes an error after updating once
				p.installMethod = installMethod
				p.fullyInstalled = true
				db.addPlugin(p)
				return
			end
			didpost = true
			postInstall(p):done(done):fail(fail)
		end
		fail = function(err)
			core.log(string.format('[Miq] Could not update %s\n%s', realName, err))
			db.getPlugin(p.plugin).fullyInstalled = p.run and false or true
		end
		mg.updatePlugin(p):done(done):fail(fail)
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
