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

-- Run a short system command with a deadline. A stalled FUSE volume (for
-- example a disconnected SSHFS mount) can block mount/umount/diskutil in the
-- kernel; the plugin must regain control even if the child cannot be killed.
local function run(command, seconds)
	local child, err = command:stdin(Command.NULL):stdout(Command.PIPED):stderr(Command.PIPED):spawn()
	if not child then return nil, tostring(err or "Cannot start command") end
	local deadline = ya.time() + seconds
	while true do
		local status, wait_err = child:try_wait()
		if status then return child:wait_with_output() end
		if wait_err or ya.time() >= deadline then
			child:start_kill()
			return nil, wait_err and tostring(wait_err) or ("timed out after " .. seconds .. "s")
		end
		ya.sleep(0.05)
	end
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

-- Returns true/false when known, or nil when `mount` failed or stalled.
local function is_mounted(root)
	local out = run(Command("mount"), 5)
	if not out or not out.status.success then return nil end
	return out.stdout:find(" on " .. escape_pattern(root) .. " %(") ~= nil
end

local function cached_sessions()
	local files = fs.read_dir(cache_root(), { resolve = true }) or {}
	local result = {}
	for _, file in ipairs(files) do
		if file.cha.is_dir and file.name:match("^session%.") then
			local dir = tostring(file.url)
			result[#result + 1] = { root = dir .. "/mount", dir = dir }
		end
	end
	return result
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
	-- macFUSE reports that as EBUSY, so retry for a few seconds before giving up.
	-- Each command is bounded so a stalled volume cannot hold close/quit forever.
	local deadline = ya.time() + 5
	repeat
		local out, err = run(Command("umount"):arg(session.root), 5)
		if out and out.status.success then
			finish()
			return
		end
		last = out and (out.stderr ~= "" and out.stderr or session.root) or err
		if out and not last:find("Resource busy", 1, true) then break end
		-- macFUSE on older macOS releases can reject `umount` even after the
		-- caller left the directory. Its own diagnostic recommends diskutil.
		local disk, disk_err = run(Command("diskutil"):arg({ "unmount", session.root }), 5)
		if disk and disk.status.success then
			finish()
			return
		end
		if disk and disk.stderr ~= "" then last = disk.stderr elseif not disk then last = disk_err end
		ya.sleep(0.1)
	until ya.time() >= deadline
	-- This is a generated, private, read-only mountpoint; forcing it cannot
	-- change the archive. It only releases macFUSE handles Yazi has retained.
	local forced, forced_err = run(Command("diskutil"):arg({ "unmount", "force", session.root }), 10)
	if forced and forced.status.success then
		finish()
		return
	end
	if forced and forced.stderr ~= "" then last = forced.stderr elseif not forced then last = forced_err end
	fail("Cannot unmount archive: " .. tostring(last))
end

local function cleanup_all()
	local ordered, seen = {}, {}
	local function add(session)
		if not seen[session.root] then
			seen[session.root], ordered[#ordered + 1] = true, session
		end
	end
	for _, session in pairs(sessions) do add(session) end
	for _, session in ipairs(cached_sessions()) do add(session) end
	-- A nested archive lives below its parent mount. Unmount deepest paths first.
	table.sort(ordered, function(a, b) return #a.root > #b.root end)
	local first_error
	for _, session in ipairs(ordered) do
		local ok, err = pcall(function()
			-- Unknown (nil) is treated as mounted: never dir_all an attached volume.
			if is_mounted(session.root) ~= false then
				remove_session(session)
			else
				fs.remove("dir_all", Url(session.dir))
				sessions[session.root] = nil
			end
		end)
		if not ok and not first_error then first_error = err end
	end
	if first_error then fail(first_error) end
end

local function session_count()
	local count = 0
	for _ in pairs(sessions) do count = count + 1 end
	return count
end

-- A remote archive (e.g. on a gs SFTP tab) has no local path for ratarmount,
-- which would read "sftp://..." as an fsspec URI. Yazi itself keeps remote
-- files as local copies in its cache: download that copy if it is missing or
-- outdated (vfs/absent, vfs/stale) and mount the copy instead.
local function local_copy(url, path, mime)
	local copy = Url(path)
	local before = fs.cha(copy)
	if before and mime ~= "vfs/absent" and mime ~= "vfs/stale" then return copy end

	local before_mtime = before and before.mtime
	ya.emit("download", { url })
	ya.notify {
		title = "Archive",
		content = "Downloading " .. tostring(url.name or url) .. " before browsing it (progress: w)",
		timeout = 5,
	}
	-- Yazi renames a finished download into place, so the copy appearing (or
	-- its mtime changing, for a stale one) means it is complete.
	local deadline = ya.time() + 1800
	repeat
		ya.sleep(0.5)
		local now = fs.cha(copy)
		if now and (not before or now.mtime ~= before_mtime) then return copy end
	until ya.time() >= deadline
	fail("Download of " .. tostring(url) .. " did not finish")
end

local function mount(source, path, mime)
	-- `origin` is where h/Left returns to: the remote directory for a remote
	-- archive. `archive` is what ratarmount reads: always a local file.
	local archive = source
	if path and path ~= tostring(source.path) then
		archive = local_copy(source, path, mime)
	end
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
	task:log("ratarmount " .. tostring(archive) .. " -> " .. tostring(point))

	-- Do not pass --foreground: ratarmount daemonizes only after the FUSE mount
	-- is usable. Its SQLite indexes stay inside this disposable session.
	local out = Command(binary):arg({
		"--index-folders", tostring(indexes), tostring(archive), tostring(point),
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
	-- Local file behind the hovered entry (Yazi's cached copy for a remote
	-- file) and its MIME type, which says whether that copy is missing/stale.
	local hovered_path = current and tostring(current.path)
	local ok_mime, hovered_mime = pcall(function() return current and current:mime() end)
	hovered_mime = ok_mime and hovered_mime or nil
	local action = job.args[1]
	local other_cwds = {}
	for i = 1, #cx.tabs do
		if i ~= cx.tabs.idx then other_cwds[#other_cwds + 1] = tostring(cx.tabs[i].current.cwd.path) end
	end
	if action == "close" and #cx.tabs == 1 then action = "quit" end
	ya.dbg("archive-browser entry", "action=", tostring(action), "cwd=", tostring(cwd), "hovered=", tostring(hovered))
	ya.async(function()
		if action == "close" or action == "quit" then
			-- Plugin modules may be reloaded between keypresses. Recover the
			-- current session from origin.txt instead of relying only on `sessions`.
			local current_session = session_for(cwd, false)
			if current_session and action == "close" then
				for _, path in ipairs(other_cwds) do
					if path == current_session.root or path:sub(1, #current_session.root + 1) == current_session.root .. "/" then
						return ya.emit("close", {})
					end
				end
			end
			ya.dbg("archive-browser cleanup", "sessions=", tostring(session_count()),
				"current=", tostring(current_session and current_session.root))
			local ok, err = pcall(function()
				if current_session then
					-- Leave the FUSE CWD before unmounting it.
					ya.emit("reveal", { Url(current_session.origin), raw = true })
					ya.sleep(0.15)
					remove_session(current_session)
				end
				-- Closing one tab must not break archive tabs that remain open. A full
				-- scan is reserved for an actual Yazi exit.
				if action == "quit" then cleanup_all() end
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
			local ok, err = pcall(mount, hovered, hovered_path, hovered_mime)
			if not ok then error(err, 0) end
		end
	end)
end

return M
