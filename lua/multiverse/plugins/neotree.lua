
local plugin = require("multiverse.data.plugin.Plugin")

return plugin:new({

	name = "Neotree",

	beforeDehydrate = function(beforeDehydrateContext)
    local neotree = require("neo-tree")
    if neotree then
      neotree.close()
    end
	end,

  afterHydrate = function(afterHydrateContext)
    local neotree = require("neo-tree")
    if neotree then
      neotree.open()
    end
  end,

})
