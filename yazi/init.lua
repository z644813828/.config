-- Yazi increments this before init.lua: 1 is the outermost instance.
local yazi_level = tonumber(os.getenv("YAZI_LEVEL")) or 0
if yazi_level > 1 then
    ya.notify {
        title = "Nested Yazi",
        content = "Yazi is already running in the parent session. This is a nested instance (level "
            .. yazi_level .. "). Press Q to close it.",
        level = "warn",
        timeout = 10,
    }

    -- A second Yazi inside a ratarmount directory holds FUSE/preview handles.
    -- The outer Yazi then cannot unmount the archive and both sessions may
    -- appear frozen. A normal Fish shell is fine; only nested Yazi is refused.
    local cwd = os.getenv("PWD") or ""
    if cwd:match("/%.cache/yazi/ratarmount%-v1/session%.[^/]+/mount/?$") then
        ya.notify {
            title = "Nested Yazi blocked",
            content = "Close the archive view first; nested Yazi would keep its FUSE mount busy.",
            level = "warn",
            timeout = 8,
        }
        ya.emit("quit", { no_cwd_file = true })
    end
end

require("hybrid-relative-numbers"):setup({
    min_width = 2,
    separator = " ",
    fg = "#81A1C1",
    hovered_fg = "#2E3440",
})

require("smart-enter"):setup({
    -- With selected files, l/Enter/Right opens the whole selection.  Without
    -- one, it opens only the hovered item.
    open_multi = true,
})

-- Keep the original glyphs, but use one icon colour across all panes.
function Entity:icon()
    local hovered = self._file.is_hovered
    local icon = th.icon:match(self._file, { hovered = hovered })
    if not icon then
        return ""
    end
    return ui.Span(icon.text .. " "):fg(hovered and "#2E3440" or "#81A1C1")
end

-- Yazi normally reserves separate rows for Header and Tabs.  On 26.9.1 put
-- both on the Tabs row: path first, then the actual clickable tab labels.
Tabs.height = function() return 1 end

function Root:layout()
    local ratio = rt.mgr.ratio
    self._chunks = ui.Layout()
        :direction(ui.Layout.VERTICAL)
        :constraints({
            ui.Constraint.Length(0),
            ui.Constraint.Length(Tabs.height()),
            ui.Constraint.Fill(1),
            ui.Constraint.Length(1),
        })
        :split(self._area)
end

function Tabs:redraw()
	-- During Yazi's very first frame the tab snapshot may still be empty.
	-- Do not divide by zero here: an exception aborts redraw of all three panes
	-- until the first navigation event forces another repaint.
	if #cx.tabs == 0 then
		return ui.Line(""):area(self._area)
	end

    local style = self:style()
    local si, so = th.tabs.sep_inner, th.tabs.sep_outer
    local reserved = ui.Line({ si.open, si.close, so.open, so.close }):width()
    -- Give the tab group up to 45% of the row, then dock that group right.
    local max = math.max(0, math.floor((self._area.w * 0.45 - reserved) / #cx.tabs))
    local names, tabs_width = {}, reserved
    for i = 1, #cx.tabs do
        names[i] = ui.truncate(string.format(" %d %s ", i, cx.tabs[i].name), { max = max })
        tabs_width = tabs_width + ui.Line(names[i]):width()
    end

    -- Keep the first frame independent of functional plugins.  Loading the
    -- archive VFS from a UI renderer can race Yazi's initial pane snapshot.
    local cwd = tostring(cx.active.current.cwd)
    -- Archive sessions use an internal VFS URL; it is useful for the engine
    -- but not as a human-facing path in the one-line header.
    if cwd:match("^archive://") then
        cwd = "Archive [read-only]"
    else
        -- `archive-browser` mounts archives as normal local folders for macOS
        -- Yazi. Recover the source label from its tiny session sidecar rather
        -- than showing the implementation cache path.
        local home = os.getenv("HOME")
        local cache = os.getenv("XDG_CACHE_HOME") or (home and home .. "/.cache")
        if cache then
            local prefix = cache .. "/yazi/ratarmount-v1/"
            local id = cwd:match("^" .. prefix:gsub("([^%w])", "%%%1") .. "(session%.[^/]+)/mount")
            if id then
                local file = io.open(prefix .. id .. "/.origin", "r")
                if file then
                    local origin = file:read("*l")
                    file:close()
                    if origin and origin ~= "" then cwd = "Archive: " .. origin end
                end
            end
        end
    end
    local path = ui.truncate(cwd, {
        max = math.max(0, self._area.w - tabs_width - 1),
        rtl = true,
    })
    local path_line = ui.Line(ui.Span(" " .. path):fg("#D8DEE9"))
    local gap = math.max(0, self._area.w - path_line:width() - tabs_width)
    local lines = { path_line, ui.Line(string.rep(" ", gap)) }
    local pos = path_line:width() + gap

    lines[#lines + 1] = ui.Line(so.open):fg(style.inactive:bg())
    pos = pos + lines[#lines]:width()
    for i = 1, #cx.tabs do
        local name = names[i]
        if i == cx.tabs.idx then
            lines[#lines + 1] = ui.Line {
                ui.Span(si.open):fg(style.active:bg()):bg(style.inactive:bg()),
                ui.Span(name):style(style.active),
                ui.Span(si.close):fg(style.active:bg()):bg(style.inactive:bg()),
            }
        else
            lines[#lines + 1] = ui.Line(name):style(style.inactive)
        end
        self._offsets[i], pos = pos, pos + lines[#lines]:width()
    end
    lines[#lines + 1] = ui.Line(so.close):fg(style.inactive:bg())
    return ui.Line(lines):area(self._area)
end

-- Render names with their ordinary file style, without search highlighting.
function Entity:highlights()
    return ui.printable(self._file.name)
end

-- Keep search positions out of file names; show them once in the status bar.
function Entity:found() return "" end

Status:children_add(function(self)
    local h = self._current.hovered
    local found = h and h:found()
    if not found then
        return ""
    end
    return ui.Line {
        ui.Span(string.format("[%d/%d]", found[1] + 1, found[2])):fg("#81A1C1"),
        "  ",
    }
end, 400, Status.RIGHT)

-- Creation time is unavailable on some remote filesystems, so omit it there.
Status:children_add(function()
    local h = cx.active.current.hovered
    local btime = h and h.cha and tonumber(tostring(h.cha.btime))
    if not btime or btime <= 0 then
        return ""
    end

    return ui.Line {
        ui.Span(os.date("%Y-%m-%d %H:%M", math.floor(btime))):fg("#D8DEE9"),
        "  ",
    }
end, 500, Status.RIGHT)
