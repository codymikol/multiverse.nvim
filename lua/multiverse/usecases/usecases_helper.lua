local log = require("multiverse.log")

local M = {}

---Runs fn, catching any error, notifying the user and logging on failure.
---@param notify_action string base-form action (e.g. "add new universe") used in the user-facing notify message
---@param log_action string gerund-form action used in the log message
---@param fn function the function to run
---@return nil
M.run_safely = function(notify_action, log_action, fn)
	local success, err = pcall(fn)
	if not success then
		vim.notify("Failed to " .. notify_action .. ", check MultiverseLog for more information", vim.log.levels.ERROR)
		log.error("Error " .. log_action .. ": %s", err)
	end
end

return M
