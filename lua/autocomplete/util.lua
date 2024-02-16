local M = {}
local debounce_cache = {}

local function stop_entry(entry)
    entry.timer:stop()
    if entry.cancel then
        entry.cancel()
        entry.cancel = nil
    end
end

function M.debounce(name, ms, func)
    local entry = debounce_cache[name]
    if entry then
        stop_entry(entry)
    else
        entry = {
            timer = vim.uv.new_timer(),
            cancel = nil
        }
        debounce_cache[name] = entry
    end

    entry.timer:start(ms, 0, vim.schedule_wrap(function()
        entry.cancel = func()
    end))
end

function M.debounce_stop(name)
    local entry = debounce_cache[name]
    if entry then
        stop_entry(entry)
        debounce_cache[name] = nil
    end
end

return M
