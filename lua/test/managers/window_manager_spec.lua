local window_manager = require("multiverse.managers.window_manager")

describe("window_manager", function()
	it("should not expose a closeAll function", function()
		assert.is_nil(window_manager.closeAll)
	end)

	it("should not expose a saveAll function", function()
		assert.is_nil(window_manager.saveAll)
	end)

	it("should not expose a hydrate function", function()
		assert.is_nil(window_manager.hydrate)
	end)

	it("should not expose a hydrateWindowsForUniverse function", function()
		assert.is_nil(window_manager.hydrateWindowsForUniverse)
	end)

	it("should still expose getAllVisibleWindowsForTabpage as a function", function()
		assert.are.equal("function", type(window_manager.getAllVisibleWindowsForTabpage))
	end)
end)
