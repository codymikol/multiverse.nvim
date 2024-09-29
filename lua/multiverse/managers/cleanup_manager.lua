local dlog = require("integrations.dlog")
local log = dlog.logger("cleanup_manager")
local buffer_manager = require("multiverse.managers.buffer_manager")

local M = {}

function close_terminal_buffer(buffer)
	local status, err = pcall(vim.api.nvim_buf_delete, buffer, { force = true })
	if status then
		log("successfully deleted terminal buffer " .. buffer)
	else
		log("error deleting buffer " .. buffer .. ", error: " .. err)
	end
end

function close_editable_buffer(buffer)
	local status, err = pcall(vim.api.nvim_buf_delete, buffer, {})
	if status then
		log("successfully closed buffer " .. buffer)
	else
		log("error deleting buffer " .. buffer .. ", error: " .. err)
	end
end

M.cleanup = function()
	-- the default behavior is to close windows when they have no buffer anymore...
	buffer_manager.closeAllBuffers()
end

return M
