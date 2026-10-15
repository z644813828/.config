--- @since 26.9.1
--- @sync entry
-- Populate the size linemode for directories without delaying navigation.
-- A single depth-two `find` counts every direct child directory at once. This
-- avoids serial read_dir calls, which can stall indefinitely on one slow FUSE
-- or network directory and leave all rows below it without a count.

local M = {}

local snapshot = ya.sync(function()
	local current = cx.active.current
	local dirs = {}
	for _, file in ipairs(current.files or {}) do
		if file.cha.is_dir then dirs[tostring(file.url)] = 0 end
	end
	return { cwd = tostring(current.cwd), dirs = dirs }
end)

local publish = ya.sync(function(state, counts)
	state.counts = state.counts or {}
	for path, count in pairs(counts) do state.counts[path] = count end
	-- `ui.render()` must run on Yazi's synchronous UI runtime. Calling it after
	-- this `ya.sync` block merely queues it from a worker and 26.9.1 only paints
	-- it on the next input event.
	ui.render()
end)

local cached = ya.sync(function(state, path)
	return state.counts and state.counts[path]
end)

function M:setup()
	local builtin_size = Linemode.size
	function Linemode:size()
		if self._file.cha.is_dir then
			local count = cached(tostring(self._file.url))
			if count ~= nil then return tostring(count) end
		end
		return builtin_size(self)
	end

	-- `cd` happens before the directory listing exists.  In particular, an
	-- immediate `g/` or `g.` could snapshot an empty list and never retry.
	-- `load` is published whenever Yazi has completed the folder listing.
	ps.sub("load", function(event)
		if event.stage() and tostring(event.url) == tostring(cx.active.current.cwd) then
			ya.async(function() ya.exec("plugin", { "dir-count" }) end)
		end
	end)

	-- A folder restored from Yazi's tab history is already loaded and therefore
	-- emits no `load` event.  Count it after `cd` as well.  The short delay lets
	-- the manager swap the active folder first; for an uncached slow directory
	-- the `load` handler above performs the definitive later pass.
	ps.sub("cd", function()
		ya.async(function()
			ya.sleep(0.08)
			ya.exec("plugin", { "dir-count" })
		end)
	end)
end

function M:entry()
	-- The entry itself completes immediately, so a long listing never turns into
	-- an unfinished task that blocks `q`. The work remains asynchronous.
	ya.async(function()
		local data = snapshot()
		if next(data.dirs) == nil then return end

		local out = Command("find")
			:arg({ data.cwd, "-mindepth", "2", "-maxdepth", "2", "-print0" })
			:output()
		if not out or not out.status.success then return end

		for entry in out.stdout:gmatch("[^\0]+") do
			local parent = entry:match("^(.*)/[^/]+$")
			if parent and data.dirs[parent] ~= nil then
				data.dirs[parent] = data.dirs[parent] + 1
			end
		end
		publish(data.dirs)
	end)
end

return M
