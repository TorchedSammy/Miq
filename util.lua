local M = {}

function M.exec(cmd, opts)
	local proc = process.start(cmd, opts or {})
	if proc then
		while proc:running() do
			coroutine.yield(0.1)
		end
		return proc:read_stdout() or proc:read_stderr() or '<none>', proc:returncode()
	end

	return nil
end

function M.isURL(url)
	return url:match '%w+://'
end

function M.slugify(url)
	return url:match '[^/]/[^/]+$'
end

--- Returns a proper plugin name based on a provided URL
--- It will remove the `.lxl` suffix or the `lite-xl-` prefix
function M.plugName(url)
	local name = string.lower(url:match '[^/]+$')
	return name:gsub('.lxl$', ''):gsub('^lite%-xl%-', '')
end

function M.fileExists(path)
	local f <close> = io.open(path)
	return f ~= nil
end

function M.gitCmd(args, dir)
	return M.exec {'git', '-C', dir, table.unpack(args)}
end

return M
