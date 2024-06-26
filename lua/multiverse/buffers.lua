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
	-- vim.cmd("silent! %bd")

	local buffers = vim.api.nvim_list_bufs()

	for _, buffer in ipairs(buffers) do
		local is_terminal = vim.api.nvim_get_option_value("buftype", { buf = buffer }) == "terminal"
		if is_terminal then
			local status, err = pcall(vim.api.nvim_buf_delete, buffer, { force = true })
			if status then
				log("successfully deleted buffer " .. buffer)
			else
				log("error deleting buffer " .. buffer .. ", error: " .. err)
			end
		else
			local status, err = pcall(vim.api.nvim_buf_delete, buffer, {})
			if status then
				log("successfully closed terminal buffer " .. buffer)
			else
				log("error deleting terminal buffer " .. buffer .. ", error: " .. err)
			end
		end
	end
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
		if
			vim.api.nvim_buf_is_loaded(buffer)
			and vim.api.nvim_buf_is_valid(buffer)
			and vim.api.nvim_buf_get_option(buffer, "modifiable")
		then
			local filename = vim.api.nvim_buf_get_name(buffer)
			log("workspace: " .. currentWorkspace .. ", saving buffer: " .. vim.inspect(filename))
			if vim.fn.filereadable(filename) == 1 then
				bufferFile:write(filename .. "\n")
			end
		end
	end
	io.close(bufferFile)
end

M.hydrate = function()
	local currentBufferFileLocation = getCurrentBufferFileLocation()

	log("hydrating from location: " .. currentBufferFileLocation)

	local buffer = io.open(currentBufferFileLocation)

	if buffer ~= nil then
		for bufferFileLocation in buffer:lines() do
			log("hydrating buffer from" .. bufferFileLocation)
			vim.api.nvim_command("edit " .. bufferFileLocation)
		end
		buffer:close()
	else
		log("Found no lines when trying to hdrate windows")
	end
end

return M
