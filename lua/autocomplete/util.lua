local M = {}

function M.entry()
    return { timer = nil, cancel = nil }
end

function M.debounce(entry, ms, func)
    if not entry then
        return
    end

    M.stop(entry)
    entry.timer = vim.uv.new_timer()
    entry.timer:start(
        ms,
        0,
        vim.schedule_wrap(function()
            entry.cancel = func()
        end)
    )
end

function M.stop(entry)
    if not entry then
        return
    end

    if entry.timer then
        entry.timer:close()
        entry.timer:stop()
        entry.timer = nil
    end

    if entry.cancel then
        entry.cancel()
        entry.cancel = nil
    end
end

function M.request(client, method, params, handler, bufnr)
    local ok, cancel_id = client.request(method, params, function(err, result, ctx)
        if err or not result then
            return
        end

        vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(ctx.bufnr) or not vim.fn.mode() == 'i' then
                return
            end

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

function M.get_client(bufnr, method)
    local clients = vim.lsp.get_clients({ bufnr = bufnr, method = method })
    if vim.tbl_isempty(clients) then
        return
    end

    return clients[1]
end

return M
