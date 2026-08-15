local buffer_manager = require("multiverse.managers.buffer_manager")

local M = {}

M.cleanup = function()
	buffer_manager.closeAllBuffers()
end

return M
