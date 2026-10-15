--- @since 26.9.1
-- MIME types for SSHFS mounts guessed from the file name only.  The built-in
-- `mime.local` runs `file` on every entry, which reads each file over the
-- network: slow directory listings and fetcher tasks that are still running
-- when the tab is closed ("There are unfinished tasks, quit anyway?").
local M = {}

-- stylua: ignore
local EXT = {
	-- text and code
	txt = "text/plain", md = "text/markdown", log = "text/plain", csv = "text/csv",
	conf = "text/plain", cfg = "text/plain", ini = "text/plain", env = "text/plain",
	toml = "text/plain", yaml = "text/yaml", yml = "text/yaml", xml = "text/xml",
	html = "text/html", htm = "text/html", css = "text/css", sql = "text/plain",
	sh = "text/x-shellscript", bash = "text/x-shellscript", fish = "text/x-shellscript",
	py = "text/x-python", rb = "text/x-ruby", pl = "text/x-perl", php = "text/x-php",
	lua = "text/x-lua", go = "text/x-go", rs = "text/x-rust", java = "text/x-java",
	c = "text/x-c", h = "text/x-c", cpp = "text/x-c++", hpp = "text/x-c++",
	ts = "text/plain", tsx = "text/plain", jsx = "text/plain", vue = "text/plain",
	tex = "text/x-tex", service = "text/plain", timer = "text/plain", tmpl = "text/plain",
	js = "application/javascript", json = "application/json", ndjson = "application/ndjson",
	-- documents
	pdf = "application/pdf",
	-- images
	png = "image/png", jpg = "image/jpeg", jpeg = "image/jpeg", gif = "image/gif",
	webp = "image/webp", bmp = "image/bmp", tif = "image/tiff", tiff = "image/tiff",
	svg = "image/svg+xml", ico = "image/vnd.microsoft.icon", heic = "image/heic",
	-- audio and video
	mp3 = "audio/mpeg", flac = "audio/flac", wav = "audio/wav", ogg = "audio/ogg",
	m4a = "audio/mp4", mp4 = "video/mp4", mkv = "video/x-matroska", webm = "video/webm",
	mov = "video/quicktime", avi = "video/x-msvideo",
	-- archives
	zip = "application/zip", tar = "application/x-tar", gz = "application/gzip",
	tgz = "application/gzip", xz = "application/x-xz", bz2 = "application/x-bzip2",
	zst = "application/zstd", ["7z"] = "application/x-7z-compressed",
	rar = "application/x-rar", deb = "application/vnd.debian.binary-package",
	-- binaries
	so = "application/x-sharedlib", o = "application/x-object", bin = "application/octet-stream",
	iso = "application/x-iso9660-image", img = "application/octet-stream",
	db = "application/octet-stream", sqlite = "application/vnd.sqlite3",
}

local function guess(file)
	if file.cha.len == 0 then return "inode/empty" end
	local ext = file.name:match("%.([^.]+)$")
	if not ext then
		-- Extensionless files on servers are mostly configs and scripts.
		return "text/plain"
	end
	return EXT[ext:lower()] or "application/octet-stream"
end

function M:fetch(job)
	return ya.co(function()
		local updates = {}
		for _, file in ipairs(job.files) do
			local mime = guess(file)
			if coroutine.yield(file, { mime }) then
				updates[file.url] = mime
			end
		end
		require("mime.dir").commit(updates)
	end)
end

return M
