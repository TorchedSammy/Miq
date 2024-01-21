local M = {}

function M.exec(cmd, opts)
	local proc = process.start(cmd, opts or {})
	if proc then
		while proc:running() do
			coroutine.yield(0.1)
		end
		return (proc:read_stdout() or '<no stdout>') .. (proc:read_stderr() or '<no stderr>'), proc:returncode()
	end

	return nil
end

function M.isURL(url)
	return url:match '^%w+://'
end

function M.slugify(url)
	return url:match '[^/]+/[^/]+$'
end

--- Returns a proper plugin name based on a provided URL
--- It will remove the `.lxl` suffix or the `lite-xl-` prefix
function M.plugName(url)
	local name = string.lower(url:match '[^/]+$')
	return name:gsub('.lxl$', ''):gsub('^lite%-xl%-', '')
end

function M.fileExists(path)
	local f = io.open(path)
	if f then
		f:close()
		return true
	end

	return false
end

function M.gitCmd(args, dir)
	return M.exec {'git', '-C', dir, table.unpack(args)}
end

function M.dehexify(hex)
   return (hex:gsub('%x%x', function(digits) return string.char(tonumber(digits, 16)) end))
end

function M.hexify(str)
   return (str:gsub('.', function(char) return string.format('%02x', char:byte()) end))
end

function M.repoURL(repo)
	return repo:match('^%w+://[^:]+')
end

function M.repoTag(repo)
	return repo:match('^%w+://.+:(.+)')
end

function M.repoDir(repo)
	return M.hexify(M.repoURL(repo))
end

function M.join(parts)
	local str = ''
	local sepPattern = string.format('%s$', '%' .. PATHSEP)
	for i, part in ipairs(parts) do
		local sepMatch = part:match(sepPattern)
		str = str .. part .. (sepMatch or i == #parts and '' or PATHSEP)
	end
	str = str:gsub(string.format('%s$', '%' .. PATHSEP), '')

	return str
end

return M
