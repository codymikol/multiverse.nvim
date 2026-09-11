local M = {}

-- math.random's default seed is fixed, so every fresh nvim process would
-- otherwise reproduce the same "random" sequence.
math.randomseed(vim.loop.hrtime())

M.create = function()
    local random = math.random
    local template = 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function(c)
        local v = (c == 'x') and random(0, 15) or random(8, 11)
        return string.format('%x', v)
    end)
end

return M


