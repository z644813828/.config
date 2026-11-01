--- @since 26.9.1
--- @sync entry
-- Interactive SSHFS connections for Yazi. Native Yazi SFTP services are
-- static; this provides arbitrary host/user/password connections instead.
local M, sessions = {}, {}

local bind_tab = ya.sync(function(state, root)
	state.tab_roots = state.tab_roots or {}
	state.tab_roots[cx.active.id.value] = root
end)

-- Only the synchronous plugin state survives separate async invocations.
-- Passwords never enter .connection, shell command strings or task logs.
local credential = ya.sync(function(state, host, user, port, value)
	state.passwords = state.passwords or {}
	local key = table.concat({ host, user, port }, "\0")
	if value ~= nil then state.passwords[key] = value end
	return state.passwords[key]
end)

local function fail(message) error(message, 0) end

local function check(value, err)
	if not value then fail(tostring(err or "Remote connection failed")) end
	return value
end

local function report_error(fn)
	local ok, err = pcall(fn)
	if not ok then
		ya.notify { title = "SSH connection", content = tostring(err), level = "error", timeout = 8 }
	end
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

local function config_password(host)
	local home = os.getenv("HOME") or ""
	local ok, content = pcall(read_all, Url(home .. "/.ssh/config"))
	if not ok then return nil end
	local matches = false
	for line in content:gmatch("[^\r\n]+") do
		local key, value = line:match("^%s*([^%s=]+)%s*[=%s]%s*(.-)%s*$")
		if key and key:lower() == "host" then
			local positive, excluded = false, false
			for token in value:gmatch("%S+") do
				local pattern = token
				local negate = pattern:sub(1, 1) == "!"
				if negate then pattern = pattern:sub(2) end
				pattern = pattern:lower():gsub("([%^%$%(%)%%%.%[%]%+%-])", "%%%1")
					:gsub("%*", ".*"):gsub("%?", ".")
				if host:lower():match("^" .. pattern .. "$") then
					if negate then excluded = true else positive = true end
				end
			end
			matches = positive and not excluded
		elseif key and key:lower() == "match" then
			matches = false
		else
			local password = line:match("^%s*#[Pp][Aa][Ss][Ss][Ww][Oo][Rr][Dd]%s+(.+)%s*$")
			if matches and password then return password end
		end
	end
end

local function auth_options(password)
	-- Unknown/changed host keys and authentication failures must fail rather
	-- than read /dev/tty behind Yazi. Password mode is handled only by sshpass.
	local options = "StrictHostKeyChecking=yes,ConnectTimeout=10,ConnectionAttempts=1,NumberOfPasswordPrompts=1"
	if password ~= "" then
		return options .. ",BatchMode=no,PreferredAuthentications=password,PubkeyAuthentication=no,KbdInteractiveAuthentication=no"
	end
	return options .. ",BatchMode=yes"
end

local function ssh_command(host, user, port, password, terminal, remote_command)
	local command = Command(password ~= "" and "sshpass" or "ssh")
	if password ~= "" then command:arg({ "-e", "ssh" }):env("SSHPASS", password) end
	command:env("SSH_ASKPASS_REQUIRE", "never")
	if terminal then command:arg("-t") end
	command:arg({ "-p", port })
	for option in auth_options(password):gmatch("[^,]+") do command:arg({ "-o", option }) end
	return command:arg({ user .. "@" .. host, remote_command })
end

local function authenticate(host, user, port, password)
	local out = check(ssh_command(host, user, port, password, false, "true"):output())
	if not out.status.success then
		fail("SSH connection failed: " .. (out.stderr ~= "" and out.stderr or "authentication rejected"))
	end
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

local function cached_sessions()
	local root = cache_root()
	local files = fs.read_dir(root, { resolve = true }) or {}
	local result = {}
	for _, file in ipairs(files) do
		if file.cha.is_dir and file.name:match("^session%.") then
			local dir = tostring(file.url)
			result[#result + 1] = { root = dir .. "/mount", dir = dir }
		end
	end
	return result
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

local function cleanup_all()
	local all, seen = {}, {}
	local function add(session)
		if not seen[session.root] then
			seen[session.root], all[#all + 1] = true, session
		end
	end
	for _, session in pairs(sessions) do add(session) end
	for _, session in ipairs(cached_sessions()) do add(session) end

	local first_error
	for _, session in ipairs(all) do
		local ok, err = pcall(function()
			if is_mounted(session.root) then
				unmount(session)
			else
				-- A previous crash can leave only the private session directory.
				fs.remove("dir_all", Url(session.dir))
				sessions[session.root] = nil
			end
		end)
		if not ok and not first_error then first_error = err end
	end
	if first_error then fail(first_error) end
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
	local port = ask("SSH port:", ssh_port or "22")
	if not port or not port:match("^%d+$") then fail("Port must be a number") end
	local saved = credential(host, user, port)
	if saved == nil then saved = config_password(host) end
	local password = ask("Password (leave empty for SSH key):", saved or "", true)
	if password == nil then return end
	credential(host, user, port, password)
	local remote = ask("Remote path (/ or ~):", "~")
	if not remote then return end
	-- SSHFS interprets a relative path from the remote user's home directory.
	-- SFTP itself does not expand `~`, so translate the familiar shell spelling
	-- before building user@host:path.
	if remote == "~" then
		remote = "."
	elseif remote:sub(1, 2) == "~/" then
		remote = remote:sub(3)
		if remote == "" then remote = "." end
	elseif not remote:match("^/") then
		fail("Remote path must start with / or ~")
	end

	require_command("sshfs")
	if password ~= "" then require_command("sshpass") end
	authenticate(host, user, port, password)
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
	local options = "reconnect,follow_symlinks,ServerAliveInterval=15,ServerAliveCountMax=3,idmap=user,dev,suid,auto_xattr,defer_permissions,noappledouble,noapplexattr," .. auth_options(password)
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
		:env("SSH_ASKPASS_REQUIRE", "never")
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
	-- Pass the mount as the tab's explicit target and await creation before
	-- renaming it. No intermediate tab or queued cd can affect the old tab.
	ya.exec("tab_create", { point, raw = true })
	bind_tab(session.root)
	ya.exec("tab_rename", { "sshfs:" .. host })
end

local function shell_in_current_directory(cwd, interactive)
	local launch = 'if command -v fish >/dev/null 2>&1; then exec fish -l; else exec "${SHELL:-/bin/sh}" -l; fi'
	local session = session_for(Url(cwd))
	if not session or not session.host then
		if interactive then return ya.emit("shell", { interactive = true }) end
		return ya.emit("shell", { "/bin/sh -lc " .. ya.quote(launch), block = true })
	end

	local suffix = cwd:gsub("/+$", ""):sub(#session.root + 1)
	local base = (session.remote or "/"):gsub("/+$", "")
	local remote = base .. suffix
	if remote == "" then remote = "/" end
	-- The login shell on the server can be fish, whose `cd` does not accept the
	-- POSIX `--` separator.  Run the setup in /bin/sh, then hand over to the
	-- Fish when available, otherwise the user's default login shell.
	local startup = "cd " .. ya.quote(remote) .. " && " .. launch
	local remote_command = "/bin/sh -lc " .. ya.quote(startup)
	local port = session.port or "22"
	local password = credential(session.host, session.user, port)
	if password == nil then password = config_password(session.host) or "" end
	if password ~= "" then require_command("sshpass") end
	-- Check credentials while Yazi still owns the screen. Errors return to its
	-- task log instead of opening a password prompt behind the file manager.
	authenticate(session.host, session.user, port, password)
	local command = ssh_command(session.host, session.user, port, password, true, remote_command)
		:stdin(Command.INHERIT):stdout(Command.INHERIT):stderr(Command.INHERIT)
	local permit = ui.hide()
	local ok, status = pcall(function() return check(command:status()) end)
	permit:drop()
	if not ok then fail(status) end
	if not status.success then fail("SSH terminal exited unsuccessfully; check the password or connection") end
end

local function goto_root(cwd, home, root)
	local session = session_for(Url(root or cwd))
	local path = session and session.root or (home and check(os.getenv("HOME")) or "/")
	return ya.emit("cd", { Url(path), raw = true })
end

local function g_menu(cwd, root)
	local choices
	if root then
		choices = {
			{ "g", "Top", "arrow", { "top" } },
			{ "h", "Mount root", "root" },
			{ "/", "Mount root", "root" },
			{ "t", "Next tab", "tab_switch", { 1, relative = true } },
			{ "T", "Previous tab", "tab_switch", { -1, relative = true } },
		}
	else
		choices = {
			{ "g", "Top", "arrow", { "top" } },
			{ ".", "Config", "cd", { "~/.config" } },
			{ "c", "Config", "cd", { "~/.config" } },
			{ "h", "Home", "cd", { "~" } },
			{ "d", "Documents", "cd", { "~/Documents/Documents" } },
			{ "z", "Downloads", "cd", { "~/Downloads" } },
			{ "p", "Projects", "cd", { "~/Documents/Projects" } },
			{ "l", "Libs", "cd", { "~/Documents/Libs" } },
			{ "i", "iCloud Documents", "cd", { "~/Library/Mobile Documents/com~apple~CloudDocs/Documents" } },
			{ "s", "SFTP/SSHFS: connect", "plugin", { "remote-connect", "mount" } },
			{ "m", "/mnt", "cd", { "/mnt" } },
			{ "/", "Root", "cd", { "/" } },
			{ "o", "/opt", "cd", { "/opt" } },
			{ "t", "Next tab", "tab_switch", { 1, relative = true } },
			{ "T", "Previous tab", "tab_switch", { -1, relative = true } },
			{ "<Space>", "Jump interactively", "cd", { interactive = true } },
			{ "f", "Follow symlink", "follow", {} },
		}
	end
	local candidates = {}
	for _, choice in ipairs(choices) do
		candidates[#candidates + 1] = { on = choice[1], desc = choice[2] }
	end
	local index = ya.which { cands = candidates }
	if not index then return end
	local choice = choices[index]
	if choice[3] == "root" then return goto_root(cwd, false, root) end
	ya.emit(choice[3], choice[4])
end

function M:entry(job)
	local action = job.args[1]
	local cwd = tostring(cx.active.current.cwd)
	self.tab_roots = self.tab_roots or {}
	local live = {}
	local other_cwds = {}
	for i = 1, #cx.tabs do
		local tab = cx.tabs[i]
		local id = tab.id.value
		local path = tostring(tab.current.cwd.path)
		live[id] = true
		local prefix = tostring(cache_root().path) .. "/"
		local token = path:match("^" .. prefix:gsub("([^%w])", "%%%1") .. "(session%.[^/]+)/mount")
		if token then self.tab_roots[id] = prefix .. token .. "/mount" end
		if i ~= cx.tabs.idx then
			other_cwds[#other_cwds + 1] = path
			if self.tab_roots[id] then other_cwds[#other_cwds + 1] = self.tab_roots[id] end
		end
	end
	for id in pairs(self.tab_roots) do
		if not live[id] then self.tab_roots[id] = nil end
	end
	local root = self.tab_roots[cx.active.id.value]
	-- Closing the final tab is an exit and must clean every owned mount.
	if action == "close" and #cx.tabs == 1 then action = "quit" end
	-- Let the synchronous plugin entry complete before prompts/mounting. This
	-- keeps the plugin worker available for q while an input is open.
	ya.async(function()
		if action == "g-menu" then
			return report_error(function() g_menu(cwd, root) end)
		end
		if action == "home" or action == "root" then
			return report_error(function() goto_root(cwd, action == "home", root) end)
		end
		if action == "new-tab" then
			-- --current follows the hovered entry in 26.9.1, which can select an
			-- unready file in a new FUSE tab. An explicit CWD avoids that path.
			local session = session_for(Url(root or cwd))
			ya.exec("tab_create", { Url(cwd), raw = true })
			if session then bind_tab(session.root) end
			if session and session.host then ya.exec("tab_rename", { "sshfs:" .. session.host }) end
			return
		end
		if action == "shell" or action == "shell-interactive" then
			return report_error(function() shell_in_current_directory(cwd, action == "shell-interactive") end)
		end
		if action == "close" or action == "quit" then
			local session = session_for(Url(root or cwd))
			if session then
				if action == "close" then
					for _, path in ipairs(other_cwds) do
						if path == session.root or path:sub(1, #session.root + 1) == session.root .. "/" then
							-- Another tab still uses this mount. Close only the tab;
							-- its last user is responsible for unmounting it.
							return ya.emit("close", {})
						end
					end
				end
				-- Leave the mount before macOS FUSE unmounts it.
				ya.dbg("remote-connect cleanup", "mount=", session.root)
				-- Awaiting this is essential: otherwise macFUSE still sees Yazi in
				-- the mountpoint and rejects umount with Resource busy.
				ya.exec("reveal", { Url(os.getenv("HOME") or "/"), raw = true })
				ya.sleep(0.25)
				if action == "quit" then cleanup_all() else unmount(session) end
			elseif action == "quit" then
				-- Other tabs can own SSHFS mounts even when the current tab does not.
				cleanup_all()
			end
			-- Archive browser owns its own FUSE sessions and performs the actual
			-- close/quit action after optional SSHFS cleanup above.
			return ya.emit("plugin", { "archive-browser", action })
		end
		report_error(mount)
	end)
end

return M
