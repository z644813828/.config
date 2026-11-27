--- @since 26.9.1
-- Previewer for remote files that have no local copy yet (MIME vfs/absent or
-- vfs/stale, e.g. on gs SFTP tabs). Yazi's built-in "vfs" previewer only says
-- "download to preview"; this one
--  * lists archives on the server over the existing gs SSH connection, without
--    downloading them (any size);
--  * downloads other small files automatically. Once the copy exists, Yazi
--    re-detects the MIME type and the regular previewer (code, image-fit, ...)
--    shows it.
local M = {}

-- Larger non-archive files are not fetched on hover; press Enter to download.
local LIMIT = 5 * 1024 * 1024
-- Hovering for this long counts as interest. Moving on cancels this peek
-- before anything is fetched, so scrolling through a listing costs nothing.
local DELAY = 0.3
local ARCHIVES = " zip rar 7z tar gz gzip tgz bz2 tbz tbz2 xz txz zst tzst lzma cab cpio arj xar deb rpm iso jar war apk "

-- One request per file version per session, even if the peek repeats or the
-- download fails (offline). A changed remote file gets a new key.
local first_request = ya.sync(function(state, key)
	state.requested = state.requested or {}
	if state.requested[key] then return false end
	state.requested[key] = true
	return true
end)

local function human(bytes)
	local units, i = { "B", "KB", "MB", "GB", "TB" }, 1
	while bytes >= 1024 and i < #units do
		bytes, i = bytes / 1024, i + 1
	end
	return i == 1 and string.format("%d %s", bytes, units[i]) or string.format("%.1f %s", bytes, units[i])
end

local function show(job, text)
	ya.preview_widget(job, ui.Text(ui.Line(text):reverse()):area(job.area):wrap(ui.Wrap.YES))
end

local function is_archive(name)
	name = name:lower()
	return ARCHIVES:find(" " .. (name:match("%.([^.]+)$") or "") .. " ", 1, true) ~= nil
end

-- Connection of a gs slot (written by remote-connect; no password inside).
local function slot_target(url)
	local index = tostring(url):match("^sftp~?://rc(%d+)/")
	local home = os.getenv("HOME") or ""
	if not index or home == "" then return nil end
	local dir = (os.getenv("XDG_CACHE_HOME") or (home .. "/.cache")) .. "/yazi/sftp-v1/rc" .. index
	local fd = fs.access():read(true):open(Url(dir .. "/target"))
	if not fd then return nil end
	local text = fd:read(4096) or ""
	ya.drop(fd)
	local host, user, port = text:match("^([^\n]*)\n([^\n]*)\n([^\n]*)\n")
	if not host or host == "" then return nil end
	return { host = host, user = user, port = port, ctl = dir .. "/ctl" }
end

-- Runs on the server: the first available lister prints the archive contents.
local LIST = [[
f=$1; n=$2
{ if command -v bsdtar >/dev/null 2>&1; then bsdtar -tvf "$f"
  elif command -v 7z >/dev/null 2>&1; then 7z l -ba "$f"
  elif command -v 7zz >/dev/null 2>&1; then 7zz l -ba "$f"
  else case "$f" in
    *.zip|*.ZIP|*.jar|*.war|*.apk) unzip -l "$f" ;;
    *) tar -tvf "$f" ;;
  esac; fi; } 2>&1 | head -n "$n"
]]

local function list_remote(job, t)
	local wanted = job.skip + job.area.h
	local remote = "/bin/sh -c " .. ya.quote(LIST) .. " sh " .. ya.quote(tostring(job.file.url.path)) .. " " .. wanted
	local child = Command("ssh")
		:arg({ "-S", t.ctl, "-o", "ControlMaster=no", "-o", "BatchMode=yes", "-o", "ConnectTimeout=10",
			"-p", t.port, "-l", t.user, "--", t.host, remote })
		:stdin(Command.NULL):stdout(Command.PIPED):stderr(Command.PIPED):spawn()
	if not child then return nil, "Cannot start ssh" end
	local deadline = ya.time() + 15
	while not child:try_wait() do
		if ya.time() >= deadline then
			child:start_kill()
			return nil, "Listing timed out"
		end
		ya.sleep(0.05)
	end
	local out = child:wait_with_output()
	if not out then return nil, "Listing failed" end
	if not out.status.success and out.stdout == "" then
		return nil, out.stderr ~= "" and out.stderr or "Listing failed"
	end
	local lines = {}
	for line in out.stdout:gmatch("[^\r\n]+") do lines[#lines + 1] = line end
	return lines
end

local function peek_archive(job, t)
	local lines, err = list_remote(job, t)
	if not lines then return show(job, "Cannot list remote archive: " .. tostring(err)) end
	if job.skip > 0 and #lines <= job.skip then
		return ya.emit("peek", { math.max(0, #lines - job.area.h), only_if = job.file.url, upper_bound = true })
	end
	local view = {}
	for i = job.skip + 1, math.min(#lines, job.skip + job.area.h) do
		view[#view + 1] = ui.Line(lines[i])
	end
	if #view == 0 then view[1] = ui.Line("(empty archive)") end
	ya.preview_widget(job, ui.Text(view):area(job.area))
end

function M:peek(job)
	local file = job.file
	local size = file.cha.len or 0
	if file.cha.is_dir then return end

	local target = is_archive(tostring(file.name or file.url)) and slot_target(file.url)
	if target then
		if job.skip == 0 then show(job, "Listing archive on the server...") end
		ya.sleep(DELAY)
		return peek_archive(job, target)
	end

	if size > LIMIT then
		return show(job, "Remote file, " .. human(size) .. " - press Enter to download and preview")
	end
	show(job, "Downloading for preview...")
	ya.sleep(DELAY)
	local key = table.concat({ tostring(file.url), tostring(file.cha.mtime), tostring(size) }, "\0")
	if first_request(key) then
		ya.emit("download", { file.url })
	end
end

-- Scrolling (J/K in the preview) as for text files.
function M:seek(job) require("code"):seek(job) end

return M
