local dlog = require("integrations.dlog")
local log = dlog.logger("windows")

local M = {}

-- This will find all open windows and persist their positioning
-- and buffer contents into a file which will be used for rehydration.
M.closeAll = function()
	-- TODO: close all open windows
end

-- This will close all open windows.
M.saveAll = function()
	-- TODO: save current open windows
end

M.hydrate = function()
	-- TODO: load saved windows
end

return M
