--- @since 26.9.1

local function setup(_, opts)
	opts = opts or {}

	local min_width = opts.min_width or 2
	local separator = opts.separator or " "

	Entity:children_add(function(self)
		-- Номера только в current pane.
		if not self._file.in_current then
			return ""
		end

		local folder = cx.active.current
		if not folder then
			return ""
		end

		-- Находим реальный абсолютный индекс именно этого файла.
		local index = nil
		for i, file in ipairs(folder.files) do
			if file.url == self._file.url then
				index = i
				break
			end
		end

		if not index then
			return ""
		end

		-- cursor в Yazi 0-based, Lua-массив files — 1-based.
		local cursor = folder.cursor + 1

		-- Hybrid numbers:
		-- текущий файл = абсолютный номер,
		-- остальные = расстояние до текущего.
		local number
		if index == cursor then
			number = index
		else
			number = math.abs(index - cursor)
		end

		local width = math.max(min_width, #tostring(#folder.files))

		local text = string.format("%" .. width .. "d%s", number, separator)
		local fg = self._file.is_hovered and opts.hovered_fg or opts.fg
		return fg and ui.Span(text):fg(fg) or text
	end, 1500)
end

return {
	setup = setup,
}
