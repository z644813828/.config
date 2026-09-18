--- @since 26.9.1
--- @sync entry

local function setup(self, opts)
	self.open_multi = opts.open_multi
end

-- Ranger-like right motion: enter a directory.  For files, preserve Yazi's
-- natural multi-selection behaviour when enabled in init.lua.
local function entry(self)
	local hovered = cx.active.current.hovered
	ya.emit(hovered and hovered.cha.is_dir and "enter" or "open", {
		hovered = not self.open_multi,
	})
end

return { entry = entry, setup = setup }
