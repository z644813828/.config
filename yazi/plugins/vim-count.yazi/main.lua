--- @since 26.9.1

-- A silent, unbounded Vim/ranger-style count prefix for vertical motions.
-- `ya.which()` is deliberately used with `silent = true`: it captures one key
-- without displaying Yazi's key-indicator popup.

local M = {}

local candidates = {
	{ on = "0" }, { on = "1" }, { on = "2" }, { on = "3" }, { on = "4" },
	{ on = "5" }, { on = "6" }, { on = "7" }, { on = "8" }, { on = "9" },
	{ on = "j" }, { on = "k" },
}

function M:entry(job)
	local count = tonumber(job.args[1])
	if not count or count < 1 then
		return
	end

	while true do
		local choice = ya.which { cands = candidates, silent = true }
		if not choice then
			-- Esc (or cancellation) discards the pending count.
			return
		end

		local key = candidates[choice].on
		local digit = tonumber(key)
		if digit then
			count = count * 10 + digit
		elseif key == "j" then
			ya.emit("arrow", { count })
			return
		else -- key == "k"
			ya.emit("arrow", { -count })
			return
		end
	end
end

return M
