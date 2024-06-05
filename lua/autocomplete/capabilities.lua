return {
    textDocument = {
        completion = {
            completionItem = {
                -- Fetch additional info for completion items
                resolveSupport = {
                    properties = {
                        'documentation',
                        'detail',
                    },
                },
            },
        },
    },
}
