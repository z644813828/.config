--- @since 26.9.1

-- Ranger's `move_parent`: switch the current directory to its sibling.
-- If /base/2 has f hovered, `]` enters /base/3 (with its first item hovered).

local current_cwd = ya.sync(function()
	return cx.active.current.cwd
end)

local function entry(_, job)
	local step = job.args[1] == "prev" and -1 or 1
	local cwd = current_cwd()
	local branch = cwd
	local container = cwd and cwd.parent
	if not container then
		return
	end

	local files = fs.read_dir(container, { resolve = true })
	if not files then
		return
	end

	local dirs = {}
	for _, file in ipairs(files) do
		if file.cha.is_dir then
			dirs[#dirs + 1] = file
		end
	end

	-- Approximate Yazi's natural sorting for directory names such as 1, 2, 10.
	local function natural_key(name)
		return (name:lower():gsub("%d+", function(n)
			return string.format("%020d", tonumber(n))
		end))
	end

	table.sort(dirs, function(a, b)
		return natural_key(a.name) < natural_key(b.name)
	end)

	for i, dir in ipairs(dirs) do
		if dir.url == branch then
			local sibling = dirs[i + step]
			if sibling then
				ya.emit("cd", { sibling.url })
			end
			return
		end
	end
end

return { entry = entry }
