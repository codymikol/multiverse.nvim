local M = {}

local Persistance = require("multiverse.persistance")
local dlog = require("integrations.dlog")
local log = dlog.logger("buffer")

local function getCurrentBufferDirLocation()
	return Persistance.getDir() .. "/" .. vim.fn.sha256(require("workspaces").name())
end

local function getCurrentBufferFileLocation()
	return getCurrentBufferDirLocation() .. "/buffer.txt"
end

-- This will close all open buffers.
M.closeAll = function()
	vim.cmd("%bd")
end

-- This will find all buffers that are currently open and persist
-- them into a file which will be used for rehydration.
M.saveAll = function()
	local workspaces = require("workspaces")

	local currentWorkspace = workspaces.name()

	local bufferDirLocation = getCurrentBufferDirLocation()

	vim.fn.mkdir(bufferDirLocation, "p")

	local bufferFileLocation = getCurrentBufferFileLocation()

	local bufferFile = io.open(bufferFileLocation, "w")

	if nil == bufferFile then
		log(
			"Error hydrating workspace state for: "
				.. currentWorkspace
				.. ", buffer file could not be opened at: "
				.. bufferFileLocation
		)
		return
	end

	local buffers = vim.api.nvim_list_bufs()

	for _, buffer in ipairs(buffers) do
		if vim.api.nvim_buf_is_loaded(buffer) then
			local filename = vim.api.nvim_buf_get_name(buffer)
			log("workspace: " .. currentWorkspace .. ", saving buffer: " .. filename)
			if vim.fn.filereadable(filename) == 1 then
				bufferFile:write(filename .. "\n")
			end
		end
	end
	io.close(bufferFile)
end

M.hydrate = function()
	log("hydrating from location: " .. getCurrentBufferFileLocation())

	local lines = io.lines(getCurrentBufferFileLocation())

	if lines ~= nil then
		for bufferFileLocation in lines do
			log("hydrating buffer from" .. bufferFileLocation)
			vim.api.nvim_command("edit " .. bufferFileLocation)
		end
	else
		log("Found no lines when trying to hdrate windows")
	end
end

return M
