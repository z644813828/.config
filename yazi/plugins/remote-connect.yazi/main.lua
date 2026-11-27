--- @since 26.9.1
--- @sync entry
-- Interactive SFTP connections for Yazi without a filesystem mount. Native
-- Yazi SFTP services are static; this provides arbitrary host/user/password
-- connections through a local OpenSSH bridge instead (see `gs` below).
local M = {}

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

-- Run a short system command with a deadline, so a stalled network or process
-- cannot block the plugin. A child that cannot be killed is abandoned.
-- Output is collected only after exit, so use this for commands with small output.
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

-- `ctl` reuses an existing OpenSSH master (gs) instead of a new connection.
local function ssh_command(host, user, port, password, terminal, remote_command, ctl)
	local command = Command(password ~= "" and "sshpass" or "ssh")
	if password ~= "" then command:arg({ "-e", "ssh" }):env("SSHPASS", password) end
	command:env("SSH_ASKPASS_REQUIRE", "never")
	if terminal then command:arg("-t") end
	if ctl then command:arg({ "-S", ctl, "-o", "ControlMaster=no" }) end
	command:arg({ "-p", port })
	for option in auth_options(password):gmatch("[^,]+") do command:arg({ "-o", option }) end
	return command:arg({ user .. "@" .. host, remote_command })
end

local function authenticate(host, user, port, password, ctl)
	-- ConnectTimeout covers only TCP setup; bound the whole handshake too.
	local out, err = run(ssh_command(host, user, port, password, false, "true", ctl), 30)
	if not out then fail("SSH connection failed: " .. err) end
	if not out.status.success then
		fail("SSH connection failed: " .. (out.stderr ~= "" and out.stderr or "authentication rejected"))
	end
end

local function choose_host(title)
	local aliases = ssh_aliases()
	if #aliases == 0 then return ask(title) end

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
		title = title,
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

local function require_command(name)
	local status = Command("sh"):arg({ "-c", 'command -v "$1" >/dev/null 2>&1', "remote-connect", name }):status()
	if not status or not status.success then fail("Install " .. name .. " first") end
end

-- Connection prompts for gs. Returns nil when the user cancels any of them.
local function ask_connection(kind)
	local host = choose_host(kind .. " host or IP:")
	if not host or host == "" then return nil end
	-- These values become ssh arguments; refuse anything ssh could read as an option.
	if host:find("^%-") or host:find("[%s'\"]") then fail("Invalid host: " .. host) end
	local ssh_user, ssh_port = ssh_defaults(host)
	local user = ask("Login:", ssh_user or os.getenv("USER") or "")
	if not user or user == "" then return nil end
	if user:find("^%-") or user:find("[%s'\"]") then fail("Invalid login: " .. user) end
	local port = ask("SSH port:", ssh_port or "22")
	if not port or not port:match("^%d+$") then fail("Port must be a number") end
	local saved = credential(host, user, port)
	if saved == nil then saved = config_password(host) end
	local password = ask("Password (leave empty for SSH key):", saved or "", true)
	if password == nil then return nil end
	credential(host, user, port, password)
	local remote = ask("Remote path (/ or ~):", "~")
	if not remote then return nil end
	if remote:find("\n") then fail("Invalid remote path") end
	return host, user, port, password, remote
end

-- ---------------------------------------------------------------------------
-- gs: SFTP without a FUSE mount.
--
-- Yazi 26.9.1 reads SFTP services only from vfs.toml at startup, with a fixed
-- host, no ~/.ssh/config and no host-key check. Instead, vfs.toml gets a few
-- static "slots" (sftp://rc1 ... rcN) pointing at a private, loopback-only
-- sshd run as this user. Each slot's port runs a small bridge that forwards
-- Yazi's SFTP channel to the real server through an OpenSSH master connection:
--
--   Yazi sftp://rcN//path -> 127.0.0.1:port -> bridge -> ssh -S master -> server
--
-- Real OpenSSH therefore handles ~/.ssh/config, keys, the agent, ProxyJump and
-- StrictHostKeyChecking. A password is given once to sshpass for the master and
-- stays in Yazi's memory only. Nothing is mounted into the macOS filesystem.
-- ---------------------------------------------------------------------------
local SFTP_SLOTS, SFTP_PORT = 4, 22101
local SFTP_MARK = "# >>> remote-connect gS slots (generated) >>>"
local SFTP_END = "# <<< remote-connect gS slots <<<"
local SFTP_BRIDGE = [[#!/bin/sh
# Generated by remote-connect (gs). Started by the local sshd for one slot:
# forwards the SFTP channel to the real server through the slot's master.
slot=$1
{ IFS= read -r host && IFS= read -r user && IFS= read -r port; } < "$slot/target" || exit 1
# Without a live master this makes one direct, non-interactive attempt with
# keys/agent only; password hosts fail fast and need gs again.
exec /usr/bin/ssh -S "$slot/ctl" -o ControlMaster=no -o BatchMode=yes \
	-o StrictHostKeyChecking=yes -o ConnectTimeout=10 \
	-o ServerAliveInterval=10 -o ServerAliveCountMax=3 \
	-p "$port" -l "$user" -s -- "$host" sftp 2>>"$slot/bridge.log"
]]

local function sftp_domain(index) return "rc" .. index end
local function sftp_state() return yazi_cache("sftp-v1") end

-- Slot index of an `sftp://rcN//path` URL (string or Url), or nil.
local function sftp_slot_of(url)
	local domain = tostring(url):match("^sftp~?://([^/:]+)")
	local index = domain and tonumber(domain:match("^rc(%d+)$"))
	if index and index >= 1 and index <= SFTP_SLOTS then return index end
end

local function sftp_target(index)
	local dir = sftp_state():join(sftp_domain(index))
	local ok, text = pcall(read_all, dir:join("target"))
	if not ok then return nil end
	local host, user, port, root = text:match("^([^\n]*)\n([^\n]*)\n([^\n]*)\n([^\n]*)")
	if not host or host == "" then return nil end
	return {
		index = index, dir = tostring(dir), ctl = tostring(dir:join("ctl")),
		host = host, user = user, port = port, root = root,
		url = "sftp://" .. sftp_domain(index) .. "/" .. root,
	}
end

local function chmod(mode, url)
	local out, err = run(Command("chmod"):arg({ mode, tostring(url) }), 5)
	if not out or not out.status.success then fail("chmod failed: " .. tostring(out and out.stderr or err)) end
end

local function local_user()
	local user = os.getenv("USER")
	if user and user ~= "" then return user end
	local out = run(Command("id"):arg("-un"), 5)
	return check(out and out.status.success and out.stdout:gsub("%s+$", ""), "Cannot determine local user")
end

local function config_dir()
	local dir = os.getenv("YAZI_CONFIG_HOME")
	if dir and dir ~= "" then return dir end
	local xdg = os.getenv("XDG_CONFIG_HOME")
	if xdg and xdg ~= "" then return xdg .. "/yazi" end
	return check(os.getenv("HOME"), "Cannot determine the home directory") .. "/.config/yazi"
end

local function toml_string(s)
	return '"' .. s:gsub("\\", "\\\\"):gsub('"', '\\"') .. '"'
end

-- Yazi loads vfs.toml only at startup. Returns true when the slots are already
-- configured; otherwise appends them once and returns false (restart needed).
local function sftp_ensure_vfs(user, key)
	local path = Url(config_dir() .. "/vfs.toml")
	local ok, content = pcall(read_all, path)
	content = ok and content or ""
	local missing = false
	for i = 1, SFTP_SLOTS do
		if not content:find("[sftp." .. sftp_domain(i) .. "]", 1, true) then missing = true end
	end
	if not missing then return true end
	if content:find(SFTP_MARK, 1, true) then
		fail("vfs.toml contains an incomplete gs block; delete it and press gs again")
	end
	local block = { SFTP_MARK, "# Loopback bridge for gs; no passwords. See remote-connect README." }
	for i = 1, SFTP_SLOTS do
		block[#block + 1] = ("[sftp.%s]\nhost = \"127.0.0.1\"\nport = %d\nuser = %s\nkey_file = %s\n")
			:format(sftp_domain(i), SFTP_PORT + i - 1, toml_string(user), toml_string(key))
	end
	block[#block + 1] = SFTP_END
	local sep = (content == "" or content:sub(-1) == "\n") and "" or "\n"
	check(fs.write(path, content .. sep .. "\n" .. table.concat(block, "\n") .. "\n"))
	return false
end

local function pid_alive(pidfile)
	local ok, text = pcall(read_all, pidfile)
	local pid = ok and text:match("^%s*(%d+)")
	if not pid then return nil end
	local out = run(Command("kill"):arg({ "-0", pid }), 5)
	return out and out.status.success and pid or nil
end

-- Keys, bridge and the private sshd. Everything lives in a 0700 directory.
local function sftp_prepare()
	local state = sftp_state()
	check(fs.create("dir_all", state))
	chmod("700", state)
	if tostring(state):find("[%s'\"]") then fail("Cache path must not contain spaces or quotes: " .. tostring(state)) end
	-- Unix socket paths are limited to 104 bytes on macOS, and ssh appends a
	-- 17-character temporary suffix to the control socket while creating it.
	if #tostring(state) + #"/rc0/ctl" + 17 >= 104 then
		fail("Cache path too long for an SSH control socket: " .. tostring(state) .. " (shorten XDG_CACHE_HOME)")
	end
	local user = local_user()
	local key, host_key = state:join("client"), state:join("host_ed25519")
	for _, file in ipairs({ key, host_key }) do
		if not fs.cha(file) then
			local out, err = run(Command("ssh-keygen"):arg({
				"-q", "-t", "ed25519", "-N", "", "-C", "yazi-remote-connect", "-f", tostring(file),
			}), 15)
			if not out or not out.status.success then fail("ssh-keygen failed: " .. tostring(out and out.stderr or err)) end
		end
	end
	return state, user, key, host_key
end

-- Rewrite only on change: a running bridge must not see its script replaced.
local function write_if_changed(url, content, mode)
	local ok, current = pcall(read_all, url)
	if ok and current == content then return false end
	check(fs.write(url, content))
	chmod(mode, url)
	return true
end

local function sftp_ensure_sshd(state, user, key, host_key)
	local pidfile = state:join("sshd.pid")

	-- Only Yazi's slot key, only from loopback, nothing but the forced bridge.
	local pub = read_all(Url(tostring(key) .. ".pub")):gsub("%s+$", "")
	local authorized = state:join("authorized_keys")
	write_if_changed(authorized, 'restrict,from="127.0.0.1" ' .. pub .. "\n", "600")
	local bridge = state:join("bridge")
	write_if_changed(bridge, SFTP_BRIDGE, "700")

	local lines = { "# Generated by remote-connect (gs). Loopback-only SFTP bridge." }
	for i = 1, SFTP_SLOTS do lines[#lines + 1] = "ListenAddress 127.0.0.1:" .. (SFTP_PORT + i - 1) end
	for _, line in ipairs({
		"HostKey " .. tostring(host_key),
		"PidFile " .. tostring(pidfile),
		"AuthorizedKeysFile " .. tostring(authorized),
		"AllowUsers " .. user,
		"AuthenticationMethods publickey",
		"PubkeyAuthentication yes",
		"PasswordAuthentication no",
		"KbdInteractiveAuthentication no",
		"UsePAM no",
		"PermitRootLogin no",
		"DisableForwarding yes",
		"PermitTTY no",
		"PermitUserRC no",
		"PrintMotd no",
		"UseDNS no",
		-- INFO records why a connection was refused (sshd.log in the cache).
		"LogLevel INFO",
		"ClientAliveInterval 15",
		"ClientAliveCountMax 3",
		"MaxSessions 16",
		"MaxStartups 32:30:64",
		-- sshd refuses unknown subsystems before ForceCommand applies, so declare
		-- sftp; the per-port ForceCommand below replaces this command.
		"Subsystem sftp /usr/bin/false",
	}) do lines[#lines + 1] = line end
	-- sshd starts the bridge through your login shell with a minimal PATH
	-- (/usr/bin:/bin:...). Shell startup files that look for Homebrew tools
	-- (e.g. a fish plugin printing "You need to install grc!") then print into
	-- the SFTP channel and break it. Give the session the PATH Yazi runs with.
	local path = os.getenv("PATH")
	if path and path ~= "" and not path:find('["\n]') then
		lines[#lines + 1] = 'SetEnv "PATH=' .. path .. '"'
	end
	for i = 1, SFTP_SLOTS do
		local slot = state:join(sftp_domain(i))
		check(fs.create("dir_all", slot))
		lines[#lines + 1] = "Match LocalPort " .. (SFTP_PORT + i - 1)
		lines[#lines + 1] = "\tForceCommand '" .. tostring(bridge) .. "' '" .. tostring(slot) .. "'"
	end
	local config = state:join("sshd_config")
	local text = table.concat(lines, "\n") .. "\n"
	local running = pid_alive(pidfile)
	local ok_cur, current = pcall(read_all, config)
	if running and ok_cur and current == text then return end
	if running then
		-- Config changed (plugin update, new PATH): restart the listener.
		-- Established bridge sessions are separate processes and keep running.
		run(Command("kill"):arg(running), 5)
		local stop = ya.time() + 3
		while pid_alive(pidfile) and ya.time() < stop do ya.sleep(0.1) end
		if pid_alive(pidfile) then fail("Cannot restart local sshd (pid " .. running .. ")") end
	end
	check(fs.write(config, text))

	-- sshd must be started by absolute path; as a normal user it can only log
	-- in that same user, which is exactly what the bridge needs.
	local log = tostring(state:join("sshd.log"))
	local test, err = run(Command("/usr/sbin/sshd"):arg({ "-t", "-f", tostring(config) }), 10)
	if not test or not test.status.success then
		fail("sshd config rejected: " .. tostring(test and test.stderr or err))
	end
	local out
	out, err = run(Command("/usr/sbin/sshd"):arg({ "-f", tostring(config), "-E", log }), 10)
	if not out or not out.status.success then fail("Cannot start local sshd: " .. tostring(out and out.stderr or err)) end
	local deadline = ya.time() + 3
	repeat
		if pid_alive(pidfile) then return end
		ya.sleep(0.1)
	until ya.time() >= deadline
	local ok, message = pcall(read_all, Url(log))
	fail("Local sshd did not start: " .. (ok and message ~= "" and message or log))
end

local function sftp_master_alive(t)
	local out = run(Command("ssh"):arg({ "-S", t.ctl, "-O", "check", "-p", t.port, "-l", t.user, "--", t.host }), 5)
	return out and out.status.success
end

-- Yazi keeps local copies of downloaded remote files (previews, opened files)
-- in its temp dir, one directory per slot, and never deletes them. Slots are
-- reused for different servers, so a slot's copies go with its connection.
-- Layout (yazi 26.9.1): <root>/<parent hash>/<file hash>, stamps in
-- <root>/%stamp/<file hash>; unfinished downloads are ".<hex>.%tmp".
--
-- A copy is in sync with the server when either
--  * it is unchanged since download: the download gives the copy the server's
--    size and mtime, and the stamp holds the hash of exactly that (len, no
--    btime, mtime). Comparing hashes is immune to clock skew between the Mac
--    and the server, which a plain time comparison is not; or
--  * it was uploaded after its last edit: the stamp is rewritten after a
--    successful upload, both times then come from the Mac's clock.
-- Anything else may hold an edit that never reached the server (e.g. an
-- upload that failed offline): it is kept and reported.
local function stamp_sig(url)
	local fd = fs.access():read(true):open(url)
	if not fd then return nil end
	local sig = fd:read(26)
	ya.drop(fd)
	return sig
end

local function in_sync(entry, stamp)
	local sig = stamp_sig(stamp)
	if not sig or #sig < 26 then return false end
	local ok, cha = pcall(Cha, { mode = tonumber("100644", 8), len = entry.cha.len, mtime = entry.cha.mtime })
	if ok and cha:hash(true) == sig then return true end
	local stamped = fs.cha(stamp)
	local stamped_at, edited_at = stamped and tonumber(tostring(stamped.mtime)), tonumber(tostring(entry.cha.mtime))
	return stamped_at ~= nil and edited_at ~= nil and edited_at <= stamped_at
end

-- Returns the number of kept entries.
local function sftp_clear_cache(index)
	local ok, url = pcall(Url, "sftp://" .. sftp_domain(index) .. "//")
	local cache = ok and url.spec and url.spec.cache
	if not cache then return 0 end
	local root = Url(cache)
	if not fs.cha(root) then return 0 end
	local stamps = root:join("%stamp")

	local kept = 0
	for _, bucket in ipairs(fs.read_dir(root, { resolve = true }) or {}) do
		if bucket.name ~= "%stamp" and bucket.cha.is_dir then
			for _, entry in ipairs(fs.read_dir(bucket.url, { resolve = true }) or {}) do
				local stamp = stamps:join(entry.name)
				if entry.cha.is_dir then
					-- Directory skeletons hold no file contents.
				elseif entry.name:match("%.%%tmp$") or in_sync(entry, stamp) then
					fs.remove("file", entry.url)
					fs.remove("file", stamp)
				else
					kept = kept + 1
				end
			end
			fs.remove("dir", bucket.url)
		end
	end
	if kept == 0 then
		fs.remove("dir_all", root)
	else
		ya.notify {
			title = "SFTP",
			content = kept .. " locally edited remote file(s) may not be uploaded yet; kept in\n" .. tostring(root),
			level = "warn",
			timeout = 15,
		}
	end
	return kept
end

local function sftp_disconnect(t)
	if fs.cha(Url(t.ctl)) then
		run(Command("ssh"):arg({ "-S", t.ctl, "-O", "exit", "-p", t.port, "-l", t.user, "--", t.host }), 5)
		-- A master killed by a network loss leaves its socket behind.
		fs.remove("file", Url(t.ctl))
	end
	fs.remove("file", Url(t.dir):join("target"))
	sftp_clear_cache(t.index)
end

local function sftp_start_master(t, password)
	local log = Url(t.dir):join("master.log")
	fs.remove("file", log)
	local args = {
		"-M", "-S", t.ctl, "-f", "-N", "-o", "ControlPersist=no",
		"-o", "ServerAliveInterval=10", "-o", "ServerAliveCountMax=3", "-p", t.port,
	}
	for option in auth_options(password):gmatch("[^,]+") do
		args[#args + 1], args[#args + 2] = "-o", option
	end
	args[#args + 1], args[#args + 2], args[#args + 3] = "-l", t.user, "--"
	args[#args + 1] = t.host
	-- The backgrounded master must not hold our pipes open; send its output to
	-- a log. sshpass returns once ssh -f has authenticated and forked.
	local command = Command("sh")
		:env("SSH_ASKPASS_REQUIRE", "never")
		:env("YAZI_SFTP_LOG", tostring(log))
		:arg({ "-c", '"$@" </dev/null >/dev/null 2>>"$YAZI_SFTP_LOG"', "remote-connect" })
	if password ~= "" then command:arg({ "sshpass", "-e" }):env("SSHPASS", password) end
	command:arg("ssh"):arg(args)
	local out, err = run(command, 30)
	if out and out.status.success and sftp_master_alive(t) then return end
	local ok, message = pcall(read_all, log)
	fail("SSH connection failed: " .. (ok and message ~= "" and message or tostring(err or "authentication rejected")))
end

local function tail(url, count)
	local ok, text = pcall(read_all, url)
	if not ok or text == "" then return "" end
	local lines = {}
	for line in text:gmatch("[^\r\n]+") do lines[#lines + 1] = line end
	return table.concat(lines, "\n", math.max(1, #lines - count + 1))
end

-- Walk the exact path Yazi will use (local sshd -> bridge -> master -> server)
-- with a real SFTP handshake. Otherwise a broken link only shows up as a tab
-- stuck at "Loading..." until Yazi's 45 s timeout, without a reason.
local function sftp_probe(state, user, key, t)
	local port = SFTP_PORT + t.index - 1
	-- Pin the local sshd's own host key instead of trusting any key.
	local pub = read_all(state:join("host_ed25519.pub")):match("^(%S+%s+%S+)")
	local known = state:join("known_hosts")
	check(fs.write(known, "[127.0.0.1]:" .. port .. " " .. check(pub, "Cannot read local host key") .. "\n"))
	local out, err = run(Command("sftp"):arg({
		-- -F /dev/null: ~/.ssh/config (Host *, ControlMaster...) must not affect the probe.
		"-q", "-b", "/dev/null", "-F", "/dev/null", "-P", tostring(port),
		"-i", tostring(key), "-o", "IdentitiesOnly=yes", "-o", "IdentityAgent=none",
		"-o", "BatchMode=yes", "-o", "StrictHostKeyChecking=yes",
		"-o", "UserKnownHostsFile=" .. tostring(known), "-o", "ConnectTimeout=5",
		user .. "@127.0.0.1",
	}), 20)
	if out and out.status.success then return end
	local reason = out and out.stderr ~= "" and out.stderr or tostring(err or "SFTP handshake failed")
	-- "Received message too long N": something printed text into the channel.
	-- Start the login shell the way sshd does and show what it prints.
	local shell = os.getenv("SHELL")
	if shell and shell ~= "" then
		local env = { "-i", "HOME=" .. (os.getenv("HOME") or ""), "USER=" .. user, "LOGNAME=" .. user, "SHELL=" .. shell }
		local path = os.getenv("PATH")
		if path then env[#env + 1] = "PATH=" .. path end
		env[#env + 1], env[#env + 2], env[#env + 3] = shell, "-c", "true"
		local probe = run(Command("env"):arg(env), 10)
		if probe and probe.stdout ~= "" then
			fail("Your login shell (" .. shell .. ") prints text when started non-interactively, "
				.. "which breaks SFTP. Make it silent outside interactive sessions:\n"
				.. probe.stdout:sub(1, 300))
		end
	end
	local details = {}
	for _, log in ipairs({ { "bridge.log", Url(t.dir):join("bridge.log") }, { "sshd.log", state:join("sshd.log") } }) do
		local text = tail(log[2], 4)
		if text ~= "" then details[#details + 1] = log[1] .. ":\n" .. text end
	end
	fail("SFTP bridge check failed on 127.0.0.1:" .. port .. ": " .. reason
		.. (#details > 0 and ("\n" .. table.concat(details, "\n")) or ""))
end

local function sftp_remote_root(t, remote)
	if remote:match("^/") then
		local trimmed = remote:gsub("/+$", "")
		return trimmed ~= "" and trimmed or "/"
	end
	if remote ~= "~" and remote:sub(1, 2) ~= "~/" then fail("Remote path must start with / or ~") end
	-- SFTP does not expand ~; ask the server once through the master.
	local out, err = run(ssh_command(t.host, t.user, t.port, "", false, "pwd", t.ctl), 15)
	if not out or not out.status.success then fail("Cannot resolve remote home: " .. tostring(out and out.stderr or err)) end
	local home
	for line in out.stdout:gmatch("[^\r\n]+") do
		if line:match("^/") then home = line end
	end
	if not home then fail("Cannot resolve remote home directory") end
	local rest = remote:sub(3):gsub("/+$", "")
	return rest == "" and home or (home:gsub("/+$", "") .. "/" .. rest)
end

-- Whether this running Yazi has loaded every slot. vfs.toml is read only at
-- startup, so the file can already contain slots this process does not know;
-- building the URL raises "unknown VFS authority" in that case.
local function sftp_slots_loaded()
	for i = 1, SFTP_SLOTS do
		if not pcall(Url, "sftp://" .. sftp_domain(i) .. "//") then return false end
	end
	return true
end

local function sftp_connect(used)
	require_command("ssh")
	require_command("ssh-keygen")
	require_command("sftp")
	local state, luser, key, host_key = sftp_prepare()
	-- Check before any prompt or connection: nothing can work until Yazi has
	-- loaded the slots.
	if not sftp_slots_loaded() then
		local added = not sftp_ensure_vfs(luser, tostring(key))
		return ya.notify {
			title = "SFTP (gs)",
			content = (added and "Added rc1..rc" .. SFTP_SLOTS .. " to " or "Slots rc1..rc" .. SFTP_SLOTS .. " are in ")
				.. config_dir() .. "/vfs.toml, but this Yazi started before they existed.\n"
				.. "Quit and start Yazi again (every running instance), then press gs.",
			level = "warn",
			timeout = 15,
		}
	end

	local host, user, port, password, remote = ask_connection("SFTP")
	if not host then return end
	if password ~= "" then require_command("sshpass") end
	sftp_ensure_sshd(state, luser, key, host_key)

	local index
	for i = 1, SFTP_SLOTS do
		if not used[i] then index = i; break end
	end
	if not index then fail("All " .. SFTP_SLOTS .. " SFTP slots are in use; close an SFTP tab first") end
	local old = sftp_target(index)
	if old then sftp_disconnect(old) end
	-- Copies left by a crashed or killed Yazi belong to whatever server used
	-- this slot before; never show them for the new one.
	sftp_clear_cache(index)

	local dir = state:join(sftp_domain(index))
	check(fs.create("dir_all", dir))
	local t = {
		index = index, dir = tostring(dir), ctl = tostring(dir:join("ctl")),
		host = host, user = user, port = port,
	}
	sftp_start_master(t, password)
	local ok, root = pcall(sftp_remote_root, t, remote)
	if not ok then sftp_disconnect(t); fail(root) end
	t.root, t.url = root, "sftp://" .. sftp_domain(index) .. "/" .. root
	-- No password here: the bridge only needs the master's control socket.
	check(fs.write(dir:join("target"), table.concat({ host, user, port, root }, "\n") .. "\n"))
	local probe_ok, probe_err = pcall(sftp_probe, state, luser, key, t)
	if not probe_ok then sftp_disconnect(t); fail(probe_err) end

	local url_ok, url = pcall(Url, t.url)
	if not url_ok then sftp_disconnect(t); fail(url) end
	ya.exec("tab_create", { url, raw = true })
	bind_tab(t.url)
	ya.exec("tab_rename", { "sftp:" .. host })
end

local function sftp_cleanup_all()
	local state = sftp_state()
	if not fs.cha(state) then return end
	for i = 1, SFTP_SLOTS do
		local t = sftp_target(i)
		if t then sftp_disconnect(t) else sftp_clear_cache(i) end
	end
	local pid = pid_alive(state:join("sshd.pid"))
	if pid then run(Command("kill"):arg(pid), 5) end
end

local function shell_in_current_directory(cwd, interactive)
	local launch = 'if command -v fish >/dev/null 2>&1; then exec fish -l; else exec "${SHELL:-/bin/sh}" -l; fi'
	-- On an SFTP tab the URL path is already the remote path. Reuse the slot's
	-- master when alive; otherwise fall back to a fresh SSH connection.
	local slot = sftp_slot_of(cwd)
	local session = slot and sftp_target(slot)
	if not session then
		if interactive then return ya.emit("shell", { interactive = true }) end
		return ya.emit("shell", { "/bin/sh -lc " .. ya.quote(launch), block = true })
	end
	local ctl = sftp_master_alive(session) and session.ctl or nil
	local remote = tostring(Url(cwd).path)
	if remote == "" then remote = "/" end
	-- The login shell on the server can be fish, whose `cd` does not accept the
	-- POSIX `--` separator.  Run the setup in /bin/sh, then hand over to the
	-- Fish when available, otherwise the user's default login shell.
	local startup = "cd " .. ya.quote(remote) .. " && " .. launch
	local remote_command = "/bin/sh -lc " .. ya.quote(startup)
	local port = session.port or "22"
	local password = ""
	if not ctl then
		password = credential(session.host, session.user, port)
		if password == nil then password = config_password(session.host) or "" end
		if password ~= "" then require_command("sshpass") end
	end
	-- Check credentials while Yazi still owns the screen. Errors return to its
	-- task log instead of opening a password prompt behind the file manager.
	authenticate(session.host, session.user, port, password, ctl)
	local command = ssh_command(session.host, session.user, port, password, true, remote_command, ctl)
		:stdin(Command.INHERIT):stdout(Command.INHERIT):stderr(Command.INHERIT)
	local permit = ui.hide()
	local ok, status = pcall(function() return check(command:status()) end)
	permit:drop()
	if not ok then fail(status) end
	if not status.success then fail("SSH terminal exited unsuccessfully; check the password or connection") end
end

local function goto_root(cwd, home, root)
	local slot = sftp_slot_of(root or cwd)
	if slot then
		local t = sftp_target(slot)
		if t then return ya.emit("cd", { Url(t.url), raw = true }) end
	end
	local path = home and check(os.getenv("HOME")) or "/"
	return ya.emit("cd", { Url(path), raw = true })
end

local function g_menu(cwd, root)
	local choices
	if root then
		choices = {
			{ "g", "Top", "arrow", { "top" } },
			{ "h", "Connection root", "root" },
			{ "/", "Connection root", "root" },
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
			{ "s", "SFTP: connect", "plugin", { "remote-connect", "sftp" } },
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
	-- gs slots open in any tab, and in tabs other than the active one.
	local sftp_used, sftp_other = {}, {}
	for i = 1, #cx.tabs do
		local tab = cx.tabs[i]
		local id = tab.id.value
		live[id] = true
		local slot = sftp_slot_of(tab.current.cwd)
		if slot then
			sftp_used[slot] = true
			if i ~= cx.tabs.idx then sftp_other[slot] = true end
			-- goto_root resolves the real root from the slot's target file.
			if not sftp_slot_of(self.tab_roots[id] or "") then
				self.tab_roots[id] = "sftp://" .. sftp_domain(slot) .. "//"
			end
		else
			self.tab_roots[id] = nil
		end
	end
	for id in pairs(self.tab_roots) do
		if not live[id] then self.tab_roots[id] = nil end
	end
	local root = self.tab_roots[cx.active.id.value]
	-- Closing the final tab is an exit and must drop every connection.
	if action == "close" and #cx.tabs == 1 then action = "quit" end
	-- Let the synchronous plugin entry complete before prompts/connecting. This
	-- keeps the plugin worker available for q while an input is open.
	ya.async(function()
		if action == "g-menu" then
			return report_error(function() g_menu(cwd, root) end)
		end
		if action == "home" or action == "root" then
			return report_error(function() goto_root(cwd, action == "home", root) end)
		end
		if action == "sftp" then
			return report_error(function() sftp_connect(sftp_used) end)
		end
		if action == "new-tab" then
			-- --current follows the hovered entry in 26.9.1; an explicit CWD
			-- opens exactly the current directory, local or remote.
			ya.exec("tab_create", { Url(cwd), raw = true })
			local slot = sftp_slot_of(cwd)
			local t = slot and sftp_target(slot)
			if t then
				bind_tab(t.url)
				ya.exec("tab_rename", { "sftp:" .. t.host })
			end
			return
		end
		if action == "shell" or action == "shell-interactive" then
			return report_error(function() shell_in_current_directory(cwd, action == "shell-interactive") end)
		end
		if action == "close" then
			local slot = sftp_slot_of(cwd)
			if slot then
				-- Close the tab first; drop the connection only when no other tab
				-- still browses this slot. Nothing is mounted, so nothing can be busy.
				ya.emit("plugin", { "archive-browser", action })
				if sftp_other[slot] then return end
				return report_error(function()
					local t = sftp_target(slot)
					if t then sftp_disconnect(t) end
				end)
			end
		end
		if action == "close" or action == "quit" then
			-- SFTP connections hold no mount; dropping them cannot block exit.
			if action == "quit" then pcall(sftp_cleanup_all) end
			-- Archive browser owns its own FUSE sessions and performs the actual
			-- close/quit action.
			return ya.emit("plugin", { "archive-browser", action })
		end
		report_error(function() fail("Unknown remote-connect action: " .. tostring(action)) end)
	end)
end

return M
