local dlog = require("dlog")
local log = dlog("windows")

local M = {}

-- This will find all open windows and persist their positioning
-- and buffer contents into a file which will be used for rehydration.
M.closeAll = function()
	log("TODO: close all open windows")
end

-- This will close all open windows.
M.saveAll = function()
	log("TODO: save current open windows")
end

M.hydrate = function()
	log("TODO: load saved windows")
end

return M
