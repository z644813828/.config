--- @since 26.9.1
local M = {}

function M:peek(job)
    local builtin = require("image")
    if ya.target_os() ~= "macos" then
        return builtin:peek(job)
    end

    local base = ya.file_cache(job)
    if not base then
        return builtin:peek(job)
    end

    local w, h = rt.preview.max_width, rt.preview.max_height
    -- Separate cache from Yazi's normal thumbnails; include resize limits.
    local cache = Url(tostring(base) .. string.format("-fit-v1-%dx%d.png", w, h))
    ya.sleep(rt.preview.image_delay / 1000)
    if not fs.cha(cache) then
        -- Normalize EXIF orientation before asking sips to resize the image.
        local source = Url(tostring(cache) .. ".source.png")
        local ok = ya.image_precache(Url(job.file.path), source)
        if not ok then
            return builtin:peek(job)
        end
        local info = ya.image_info(source)
        if not info or info.w <= 0 or info.h <= 0 then
            fs.remove("file", source)
            return builtin:peek(job)
        end
        local scale = math.min(w / info.w, h / info.h)
        local width = math.max(1, math.floor(info.w * scale))
        local height = math.max(1, math.floor(info.h * scale))
        -- Only publish a finished image, so interrupted previews aren't reused.
        local partial = Url(tostring(cache) .. ".partial.png")
        local status = Command("/usr/bin/sips")
            :arg({ "--setProperty", "format", "png",
                "--resampleHeightWidth", tostring(height), tostring(width),
                tostring(source), "--out", tostring(partial) })
            :stdout(Command.NULL):stderr(Command.NULL):status()
        fs.remove("file", source)
        if not status or not status.success then
            fs.remove("file", partial)
            return builtin:peek(job)
        end
        if not fs.rename(partial, cache) then
            fs.remove("file", partial)
            return builtin:peek(job)
        end
    end

    -- Yazi now has enough pixels to fit the pane, preserving aspect ratio.
    local _, err = ya.image_show(cache, job.area)
    if err then
        return builtin:peek(job)
    end
    ya.preview_widget(job, nil)
end

function M:seek() end

return M
