local plugin = require("multiverse.data.plugin.Plugin")

return plugin:new({

	name = "CopilotChat",

	beforeDehydrate = function(beforeDehydrateContext)
		local chat = require("CopilotChat")
		if chat then
      chat.save(beforeDehydrateContext.universe.name)
      chat.close()
      chat.stop(true)
		end
	end,

  afterHydrate = function(afterHydrateContext)
    local chat = require("CopilotChat")
    if chat then
      chat.start()
      chat.load(afterHydrateContext.universe.name)
      -- todo(mikol): Load the chat history for this plugin.
    end
  end,

})
