local M = {}

local persistance = require("multiverse.repositories.persistance")

local function ensure_local_directory_exists()

  local uv = vim.loop

  local multiverse_path = persistance.getDir()

  local stat = uv.fs_stat(multiverse_path)
  if not stat then
    local ok, err = uv.fs_mkdir(multiverse_path, 493) -- 493 is octal 0755
    if not ok then
      vim.notify("Failed to create multiverse directory: " .. err, vim.log.levels.ERROR)
    end
  end
end

local function ensure_catalog_exists() 
end

M.run = function()
  ensure_local_directory_exists()
  ensure_catalog_exists()
end

return M
