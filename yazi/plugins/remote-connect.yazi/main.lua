--- @since 26.9.1
--- @sync entry
-- Interactive SSHFS connections for Yazi. Native Yazi SFTP services are
-- static; this provides arbitrary host/user/password connections instead.
local M, sessions = {}, {}

local function fail(message) error(message, 0) end

local function check(value, err)
	if not value then fail(tostring(err or "Remote connection failed")) end
	return value
end

local function ask(title, value, obscure)
	local answer, event = ya.input {
		pos = { "top-center", y = 2, w = 56 },
		title = title,
		value = value or "",
		obscure = obscure or false,
	}
	if event ~= 1 then return nil end
	return answer
end

local function yazi_cache(name)
	local home = os.getenv("HOME") or ""
	if home == "" then fail("Cannot determine the home directory") end
	return Url((os.getenv("XDG_CACHE_HOME") or (home .. "/.cache")) .. "/yazi/" .. name)
end

local function cache_root() return yazi_cache("sshfs-v1") end

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

local function ssh_aliases()
	local home = os.getenv("HOME") or ""
	if home == "" then return {} end

	-- This is only a list for the picker. The actual effective configuration is
	-- resolved with `ssh -G` below, so Include and Host * are still respected.
	local ok, content = pcall(read_all, Url(home .. "/.ssh/config"))
	if not ok then return {} end

	local aliases, seen = {}, {}
	for line in content:gmatch("[^\r\n]+") do
		local text = line:gsub("%s+#.*$", "")
		local key, values = text:match("^%s*(%S+)%s+(.+)$")
		if key and key:lower() == "host" then
			for name in values:gmatch("%S+") do
				-- Configuration patterns are not directly connectable aliases.
				if not name:find("[%*%!%?]") and not seen[name] then
					seen[name], aliases[#aliases + 1] = true, name
				end
			end
		end
	end
	table.sort(aliases)
	return aliases
end

local function ssh_defaults(host)
	-- Expands the alias without opening a connection. This covers Include,
	-- Match, and Host * rules better than manually parsing ssh_config.
	local home = os.getenv("HOME") or ""
	local config = home ~= "" and Url(home .. "/.ssh/config") or nil
	local args = { "-G", host }
	-- OpenSSH obtains the user's home from the account database, not necessarily
	-- from $HOME. Passing -F makes the same ~/.ssh/config that fed the picker
	-- authoritative, including in Yazi launched from a nonstandard environment.
	if config and pcall(read_all, config) then args = { "-F", tostring(config), "-G", host } end
	local out = Command("ssh"):arg(args):output()
	if not out or not out.status.success then return nil, nil end
	local user = out.stdout:match("\nuser%s+([^\r\n]+)")
		or out.stdout:match("^user%s+([^\r\n]+)")
	local port = out.stdout:match("\nport%s+([^\r\n]+)")
		or out.stdout:match("^port%s+([^\r\n]+)")
	return user, port
end

local function choose_host()
	local aliases = ssh_aliases()
	if #aliases == 0 then return ask("SSHFS host or IP:") end

	-- Yazi 26.9.1 hard-codes `completion = false` for ya.input, but its
	-- completion popup (the one under `g<Space>`) can still be driven with
	-- `cmp:trigger`. It completes directory entries, so mirror the aliases as
	-- empty files: files, not directories, so no trailing "/" is inserted.
	local dir = yazi_cache("ssh-hosts")
	fs.remove("dir_all", dir)
	check(fs.create("dir_all", dir))
	for _, alias in ipairs(aliases) do
		check(fs.write(dir:join(alias), ""))
	end
	local known = {}
	for _, alias in ipairs(aliases) do known[alias] = true end
	local function suggest(word)
		-- A fully typed or completed alias needs no popup with itself in it.
		if known[word] then return ya.emit("cmp:close", {}) end
		ya.emit("cmp:trigger", { tostring(dir) .. "/" .. word })
	end

	local input = ya.input {
		pos = { "top-center", y = 2, w = 56 },
		title = "SSHFS host or IP:",
		realtime = true,
	}
	suggest("")
	-- Tab/Enter in the popup complete an alias; a host or IP that matches no
	-- alias is submitted as typed.
	while true do
		local value, event = input:recv()
		if event == 3 then
			suggest(value)
		else
			-- A trigger queued by the last keystroke must not reopen the popup
			-- under the next prompt.
			ya.emit("cmp:close", {})
			fs.remove("dir_all", dir)
			return event == 1 and value or nil
		end
	end
end

local function mounted_connection(root)
	-- Compatibility for mounts created by the previous plugin version, which did
	-- not have .connection yet. macFUSE exposes its source in `mount` output.
	local out = Command("mount"):output()
	if not out or not out.status.success then return nil end
	local escaped = root:gsub("([^%w])", "%%%1")
	local source = out.stdout:match("([^\n]+) on " .. escaped .. " %(%")
	if not source then return nil end
	local user, host, remote = source:match("^([^@]+)@([^:]+):(.+)$")
	if not user then return nil end
	return host, user, "22", remote
end

local function is_mounted(root)
	local out = Command("mount"):output()
	if not out or not out.status.success then return false end
	return out.stdout:find(" on " .. root:gsub("([^%w])", "%%%1") .. " %(") ~= nil
end

local function session_for(url)
	local path = tostring(url.path)
	local prefix = tostring(cache_root().path) .. "/"
	local token = path:match("^" .. prefix:gsub("([^%w])", "%%%1") .. "(session%.[^/]+)/mount")
	if not token then return nil end
	local root, dir = prefix .. token .. "/mount", prefix .. token
	local session = sessions[root]
	if session then return session end

	-- Do not save a password in the session directory.  The remaining data lets
	-- `S` recover an SSH terminal even if Yazi has reloaded this plugin.
	local ok, details = pcall(read_all, Url(dir .. "/.connection"))
	local host, user, port, remote
	if ok then host, user, port, remote = details:match("([^\n]*)\n([^\n]*)\n([^\n]*)\n(.*)") end
	if not host or host == "" then host, user, port, remote = mounted_connection(root) end
	return { root = root, dir = dir, host = host, user = user, port = port, remote = remote }
end

local function unmount(session)
	local function finish()
		check(fs.remove("dir_all", Url(session.dir)))
		sessions[session.root] = nil
	end

	local last = ""
	for _ = 1, 20 do
		local out = check(Command("umount"):arg(session.root):output())
		if out.status.success then finish(); return end
		last = out.stderr ~= "" and out.stderr or session.root
		local disk = Command("diskutil"):arg({ "unmount", session.root }):output()
		if disk and disk.status.success then finish(); return end
		if disk and disk.stderr ~= "" then last = disk.stderr end
		ya.sleep(0.1)
	end
	local forced = Command("diskutil"):arg({ "unmount", "force", session.root }):output()
	if forced and forced.status.success then finish(); return end
	fail("Cannot unmount SSHFS: " .. (forced and forced.stderr ~= "" and forced.stderr or last))
end

local function require_command(name)
	local status = Command("sh"):arg({ "-c", 'command -v "$1" >/dev/null 2>&1', "remote-connect", name }):status()
	if not status or not status.success then fail("Install " .. name .. " first") end
end

local function mount()
	local host = choose_host()
	if not host or host == "" then return end
	local ssh_user, ssh_port = ssh_defaults(host)
	local user = ask("Login:", ssh_user or os.getenv("USER") or "")
	if not user or user == "" then return end
	local password = ask("Password (leave empty for SSH key):", "", true)
	if password == nil then return end
	local port = ask("SSH port:", ssh_port or "22")
	if not port or not port:match("^%d+$") then fail("Port must be a number") end
	local remote = ask("Remote path:", "/")
	if not remote or not remote:match("^/") then fail("Remote path must start with /") end

	require_command("sshfs")
	if password ~= "" then require_command("sshpass") end
	local root = cache_root()
	check(fs.create("dir_all", root))
	local made = check(Command("mktemp"):arg({ "-d", tostring(root:join("session.XXXXXXXX")) }):output())
	if not made.status.success then fail(made.stderr) end
	local dir = Url(made.stdout:gsub("[\r\n]+$", ""))
	local point = dir:join("mount")
	check(fs.create("dir_all", point))
	-- Deliberately exclude the password: it belongs only to the sshpass process.
	check(fs.write(dir:join(".connection"), table.concat({ host, user, port, remote }, "\n")))

	local source = user .. "@" .. host .. ":" .. remote
	-- Absolute remote links otherwise point at the Mac's /… and look dangling.
	-- Ask SSHFS to resolve them on the server and expose their targets here.
	local options = "reconnect,follow_symlinks,ServerAliveInterval=15,ServerAliveCountMax=3,idmap=user,dev,suid,auto_xattr,defer_permissions,noappledouble,noapplexattr"
	local args
	if password == "" then
		args = { "sshfs", "-p", port, source, tostring(point), "-o", options }
	else
		args = { "sshpass", "-e", "sshfs", "-p", port, source, tostring(point), "-o", options }
	end
	-- macFUSE's sshfs does not daemonize on this macOS version.  Calling
	-- `output()` on it blocked the plugin until unmount, so the tab creation was
	-- delayed until the user manually ran `umount`. Start it detached instead.
	local log = dir:join(".sshfs.log")
	local command = Command("sh")
		:env("YAZI_SSHFS_LOG", tostring(log))
		:arg({ "-c", '"$@" </dev/null >> "$YAZI_SSHFS_LOG" 2>&1 &', "remote-connect" })
		:arg(args)
	if password ~= "" then command:env("SSHPASS", password) end
	local out, err = command:output()
	if not out or not out.status.success then
		fs.remove("dir_all", dir)
		fail(out and out.stderr ~= "" and out.stderr or tostring(err or "Cannot start sshfs"))
	end
	for _ = 1, 100 do
		if is_mounted(tostring(point)) then break end
		ya.sleep(0.1)
	end
	if not is_mounted(tostring(point)) then
		local ok, message = pcall(read_all, log)
		fs.remove("dir_all", dir)
		fail(ok and message ~= "" and message or "sshfs did not mount the remote directory")
	end

	local session = { root = tostring(point), dir = tostring(dir) }
	session.host, session.user, session.port, session.remote = host, user, port, remote
	sessions[session.root] = session
	-- `ya.emit()` only queues events; on 26.9.1 the following `cd` can reach the
	-- old tab before tab_create has run. `ya.exec()` waits for each action, so
	-- the mounted directory reliably becomes the current directory of new tab.
	ya.exec("tab_create", { current = true })
	ya.exec("cd", { point, raw = true })
	ya.exec("tab_rename", { "sshfs:" .. host })
end

local function shell_in_current_directory(cwd)
	local session = session_for(Url(cwd))
	if not session or not session.host then
		return ya.emit("shell", { "fish", block = true })
	end

	local suffix = cwd:gsub("/+$", ""):sub(#session.root + 1)
	local base = (session.remote or "/"):gsub("/+$", "")
	local remote = base .. suffix
	if remote == "" then remote = "/" end
	-- The login shell on the server can be fish, whose `cd` does not accept the
	-- POSIX `--` separator.  Run the setup in /bin/sh, then hand over to the
	-- user's preferred interactive shell.
	local startup = "cd " .. ya.quote(remote) .. " && exec ${SHELL:-/bin/sh} -l"
	local remote_command = "/bin/sh -lc " .. ya.quote(startup)
	local command = "ssh -t -p " .. ya.quote(session.port or "22")
		.. " " .. ya.quote(session.user .. "@" .. session.host)
		.. " " .. ya.quote(remote_command)
	ya.emit("shell", { command, block = true })
end

function M:entry(job)
	local action = job.args[1]
	local cwd = tostring(cx.active.current.cwd)
	-- This path has no prompts or filesystem work. Keeping it synchronous makes
	-- `S` behave like Yazi's normal blocking shell binding, without a lingering
	-- "Run plugin" task after the terminal exits.
	if action == "shell" then return shell_in_current_directory(cwd) end
	-- Let the synchronous plugin entry complete before prompts/mounting. This
	-- keeps the plugin worker available for q while an input is open.
	ya.async(function()
		if action == "close" or action == "quit" then
			local session = session_for(Url(cwd))
			if session then
				-- Leave the mount before macOS FUSE unmounts it.
				ya.dbg("remote-connect cleanup", "mount=", session.root)
				-- Awaiting this is essential: otherwise macFUSE still sees Yazi in
				-- the mountpoint and rejects umount with Resource busy.
				ya.exec("reveal", { Url(os.getenv("HOME") or "/"), raw = true })
				ya.sleep(0.25)
				unmount(session)
			end
			-- Archive browser owns its own FUSE sessions and performs the actual
			-- close/quit action after optional SSHFS cleanup above.
			return ya.emit("plugin", { "archive-browser", action })
		end
		mount()
	end)
end

return M
