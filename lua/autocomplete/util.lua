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
            cancel = nil,
        }
        debounce_cache[name] = entry
    end

    entry.timer:start(
        ms,
        0,
        vim.schedule_wrap(function()
            entry.cancel = func()
        end)
    )
end

function M.debounce_stop(name)
    local entry = debounce_cache[name]
    if entry then
        stop_entry(entry)
    end
end

function M.request(client, method, params, handler, bufnr)
    local ok, cancel_id = client.request(method, params, function(err, result, ctx)
        if
            err
            or not result
            or not vim.api.nvim_buf_is_valid(ctx.bufnr)
            or not vim.fn.mode() == 'i'
        then
            return
        end

        vim.schedule(function()
            handler(result)
        end)
    end, bufnr)
    if not ok then
        return
    end
    return function()
        client.cancel_request(cancel_id)
    end
end

function M.with_client(callback, method)
    return function(args)
        local bufnr = args.buf
        local clients = vim.lsp.get_clients({ bufnr = bufnr, method = method })
        if vim.tbl_isempty(clients) then
            return
        end

        local client = clients[1]
        if client then
            callback(client, bufnr)
        end
    end
end

return M
