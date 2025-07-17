local M = {}

local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local persistence = require("multiverse.repositories.persistance")

M.run = function(name)

  local multiverse = multiverse_repository.getMultiverse()

  local universe = multiverse:getUniverseByName(name)

  if universe == nil then
    vim.notify("Universe not found: " .. name, vim.log.levels.ERROR)
    return
  end

  -- remove the catalog entry for the universe
  for i, v in ipairs(multiverse.universes) do
    if v.name == name then

      local universe_file = persistence.getDir() .. "/universe-" .. v.uuid .. ".json"

      local success, err = os.remove(universe_file)
      if not success then
        vim.notify("Failed to remove universe file: " .. err, vim.log.levels.ERROR)
        return
      end
      table.remove(multiverse.universes, i)
      break
    end
  end

  multiverse_repository.save_multiverse(multiverse)

  vim.notify(name)
end

return M
