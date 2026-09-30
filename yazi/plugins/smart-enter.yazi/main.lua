--- @since 26.9.1
--- @sync entry

local function setup(self, opts)
	self.open_multi = opts.open_multi
end

-- This file is a synchronous plugin. Do not `require("archive-browser")` here:
-- the VFS plugin registers ya.sync() handlers and therefore may only load in
-- its own asynchronous plugin runtime.
local function is_archive(file)
	local name = tostring(file.name or file.url):lower()
	local ext = name:match("%.([^.]+)$") or ""
	local extensions = " zip rar 7z tar gz gzip tgz bz2 tbz tbz2 xz txz zst tzst lzma cab cpio arj xar deb rpm iso dmg apk jar war "
	if extensions:find(" " .. ext .. " ", 1, true) or name:match("%.tar%.[^.]+$") then
		return true, "extension"
	end

	local ok, mime = pcall(function() return file:mime() end)
	local typ = ok and (mime or ""):gsub("^application/", ""):gsub("^x%-", ""):gsub("^vnd%.", "") or ""
	return typ:find("zip", 1, true) ~= nil or typ == "tar" or typ == "rar"
		or typ == "7z-compressed" or typ == "xz" or typ == "zstd", "mime=" .. typ
end

-- Ranger-like right motion: enter a directory.  For files, preserve Yazi's
-- natural multi-selection behaviour when enabled in init.lua.
local function entry(self)
	local hovered = cx.active.current.hovered
	if hovered and not hovered.cha.is_dir then
		local archive, reason = is_archive(hovered)
		ya.dbg("smart-enter", "url=", tostring(hovered.url), "name=", tostring(hovered.name),
			"archive=", archive, reason, "selected=", #cx.active.selected)
		-- An old Space selection must not send an archive to Yazi's default
		-- extractor. `l` on the hovered archive always means browse it.
		if archive then
			return ya.emit("plugin", { "archive-browser" })
		elseif hovered.url.spec.scheme == "archive" then
			return ya.emit("plugin", { "archive-browser", "open" })
		end
	end
	ya.emit(hovered and hovered.cha.is_dir and "enter" or "open", {
		hovered = not self.open_multi,
	})
end

return { entry = entry, setup = setup }
