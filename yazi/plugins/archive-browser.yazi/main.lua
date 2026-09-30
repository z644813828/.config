--- @since 26.9.1
--- @sync entry
-- Read-only archive browsing backed by macFUSE + ratarmount.
--
-- Yazi's Lua VFS provider is unreliable in the macOS 26.9.1 release: it can
-- successfully return ReadDir entries while the manager renders "No items".
-- A FUSE mount is a normal local directory to Yazi, so previews, opening,
-- selection and nested archives all use Yazi's ordinary, tested code paths.
local M, sessions = {}, {}

local function fail(message)
	error(message, 0)
end

local function check(value, err)
	if not value then fail(tostring(err or "Archive operation failed")) end
	return value
end

local function cache_root()
	local home = os.getenv("HOME")
	if not home or home == "" then fail("Cannot determine the home directory") end
	return Url((os.getenv("XDG_CACHE_HOME") or (home .. "/.cache")) .. "/yazi/ratarmount-v1")
end

local function read_all(url)
	local fd = check(fs.access():read(true):open(url))
	local parts = {}
	while true do
		local part = check(fd:read(65536))
		if part == "" then break end
		parts[#parts + 1] = part
	end
	ya.drop(fd)
	return table.concat(parts)
end

local function ratarmount()
	local home = os.getenv("HOME") or ""
	-- Fish need not export ~/.local/bin in PATH: try the installation locations
	-- documented for this configuration explicitly.
	for _, candidate in ipairs({
		"ratarmount",
		home .. "/.local/bin/ratarmount",
		home .. "/.local/share/ratarmount-venv/bin/ratarmount",
	}) do
		local status = Command(candidate):arg("--version"):status()
		if status and status.success then return candidate end
	end
	fail("ratarmount was not found. Install it in ~/.local/bin or add it to PATH.")
end

local function escape_pattern(s)
	return s:gsub("([^%w])", "%%%1")
end

local function session_for(url, exact)
	-- `Url:tostring()` is build-dependent on macOS (it may include `file://`).
	-- `.path` is always the filesystem path, including on a FUSE mount.
	local path = tostring(url.path)
	local prefix = tostring(cache_root().path) .. "/"
	local token = path:match("^" .. escape_pattern(prefix) .. "(session%.[^/]+)/mount")
	ya.dbg("archive-browser session lookup", "path=", path, "prefix=", prefix,
		"token=", tostring(token), "exact=", tostring(exact))
	if not token then return nil end
	local root = prefix .. token .. "/mount"
	if exact and path:gsub("/+$", "") ~= root then
		ya.dbg("archive-browser session is nested", "root=", root)
		return nil
	end
	return sessions[root] or {
		-- Keep only strings across plugin invocations. Url userdata is scoped to
		-- the coroutine in which it was created and macOS Yazi destroys it later.
		root = root,
		dir = prefix .. token,
		origin = read_all(Url(prefix .. token .. "/.origin")):gsub("[\r\n]+$", ""),
	}
end

local function remove_session(session)
	-- Do not remove the directory before unmounting: on macOS that would leave a
	-- hidden, still-running FUSE daemon behind.
	local last
	local function finish()
		check(fs.remove("dir_all", Url(session.dir)))
		sessions[session.root] = nil
	end
	-- Yazi may retain a preview file descriptor briefly after changing CWD.
	-- macFUSE reports that as EBUSY, so retry for two seconds before giving up.
	for _ = 1, 20 do
		local out = check(Command("umount"):arg(session.root):output())
		if out.status.success then
			finish()
			return
		end
		last = out.stderr ~= "" and out.stderr or session.root
		if not last:find("Resource busy", 1, true) then break end
		-- macFUSE on older macOS releases can reject `umount` even after the
		-- caller left the directory. Its own diagnostic recommends diskutil.
		local disk = Command("diskutil"):arg({ "unmount", session.root }):output()
		if disk and disk.status.success then
			finish()
			return
		end
		if disk and disk.stderr ~= "" then last = disk.stderr end
		ya.sleep(0.1)
	end
	-- This is a generated, private, read-only mountpoint; forcing it cannot
	-- change the archive. It only releases macFUSE handles Yazi has retained.
	local forced = Command("diskutil"):arg({ "unmount", "force", session.root }):output()
	if forced and forced.status.success then
		finish()
		return
	end
	if forced and forced.stderr ~= "" then last = forced.stderr end
	fail("Cannot unmount archive: " .. last)
end

local function cleanup_all()
	local ordered = {}
	for _, session in pairs(sessions) do ordered[#ordered + 1] = session end
	-- A nested archive lives below its parent mount. Unmount deepest paths first.
	table.sort(ordered, function(a, b) return #a.root > #b.root end)
	for _, session in ipairs(ordered) do remove_session(session) end
end

local function session_count()
	local count = 0
	for _ in pairs(sessions) do count = count + 1 end
	return count
end

local function mount(source)
	local binary = ratarmount()
	local root = cache_root()
	check(fs.create("dir_all", root))
	local chmod = Command("chmod"):arg({ "700", tostring(root) }):status()
	check(chmod and chmod.success)

	local made = check(Command("mktemp"):arg({ "-d", tostring(root:join("session.XXXXXXXX")) }):output())
	if not made.status.success then fail(made.stderr) end
	local dir = Url(made.stdout:gsub("[\r\n]+$", ""))
	local point, indexes = dir:join("mount"), dir:join(".indexes")
	check(fs.create("dir_all", point))
	check(fs.create("dir_all", indexes))
	check(fs.write(dir:join(".origin"), tostring(source)))

	-- Start immediately: a custom task in Yazi's plugin pool could otherwise
	-- wait behind the archive-browser invocation that scheduled it.
	local task = ya.task("custom", { pool = "none", scope = rt.scope() })
		:name("Mount " .. tostring(source.name or source)):spawn()
	if not task:acquire() then return end
	task:progress { total = 1, workload = 1, processed = 0 }
	task:log("ratarmount " .. tostring(source) .. " -> " .. tostring(point))

	-- Do not pass --foreground: ratarmount daemonizes only after the FUSE mount
	-- is usable. Its SQLite indexes stay inside this disposable session.
	local out = Command(binary):arg({
		"--index-folders", tostring(indexes), tostring(source), tostring(point),
	}):output()
	if not out.status.success then
		fs.remove("dir_all", dir)
		return task:fail(out.stderr ~= "" and out.stderr or "ratarmount failed")
	end

	local session = { root = tostring(point), dir = tostring(dir), origin = tostring(source) }
	sessions[session.root] = session
	task:log("Mounted; entering " .. tostring(point))
	ya.dbg("archive-browser mounted", "source=", tostring(source), "mount=", tostring(point))
	-- `raw` keeps Yazi from treating the temporary absolute path as typed input.
	-- Queue navigation before completing the task, whose success update may
	-- otherwise cancel the task's UI scope on older 26.9.1 builds.
	ya.emit("cd", { point, raw = true })
	task:progress { total = 1, success = 1, workload = 1, processed = 1 }
	-- 26.9.1 macOS builds disagree on the optional URL-list argument here.
	-- Navigation was already queued above, so a plain success is sufficient.
	task:succeed()
end

function M:entry(job)
	-- This is a synchronous entrypoint solely to detach the real work below.
	-- Otherwise `q` asks to quit with its own "Run plugin" task unfinished.
	local cwd = Url(tostring(cx.active.current.cwd))
	local current = cx.active.current.hovered
	local hovered = current and Url(tostring(current.url))
	local action = job.args[1]
	ya.dbg("archive-browser entry", "action=", tostring(action), "cwd=", tostring(cwd), "hovered=", tostring(hovered))
	ya.async(function()
		if action == "close" or action == "quit" then
			-- Plugin modules may be reloaded between keypresses. Recover the
			-- current session from origin.txt instead of relying only on `sessions`.
			local current_session = session_for(cwd, false)
			ya.dbg("archive-browser cleanup", "sessions=", tostring(session_count()),
				"current=", tostring(current_session and current_session.root))
			local ok, err = pcall(function()
				if current_session then
					-- Leave the FUSE CWD before unmounting it.
					ya.emit("reveal", { Url(current_session.origin), raw = true })
					ya.sleep(0.15)
					remove_session(current_session)
				end
				cleanup_all()
			end)
			if not ok then error(err, 0) end
			return ya.emit(action == "quit" and "quit" or "close", action == "quit" and { no_cwd_file = true } or {})
		elseif action == "leave" then
			local session = session_for(cwd, true)
			if session then
				-- `umount` fails while Yazi's CWD is the mountpoint. Queue the
				-- navigation first, then wait for Yazi to release it.
				ya.emit("reveal", { Url(session.origin), raw = true })
				ya.sleep(0.15)
				local ok, err = pcall(remove_session, session)
				if not ok then error(err, 0) end
				return
			end
			return ya.emit("leave", {})
		elseif action == "open-with" then
			return ya.emit("shell", { " %s", cursor = 0, block = true, interactive = true })
		elseif action == "choose" then
			return ya.emit("open", { interactive = true })
		elseif hovered then
			local ok, err = pcall(mount, hovered)
			if not ok then error(err, 0) end
		end
	end)
end

return M
