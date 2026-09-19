local Tabpage = require("multiverse.data.Tabpage")
local Window = require("multiverse.data.Window")

describe("Tabpage", function()
	describe("resolveActiveWindowUuid", function()
		local tabpage
		local window

		before_each(function()
			tabpage = Tabpage:new("tabpage-uuid", 1, "window-uuid")
			window = Window:new({ uuid = "window-uuid", windowId = 42 })
		end)

		it("resolves activeWindowUuid from activeWindowId and clears the transient field", function()
			tabpage.activeWindowId = 42
			tabpage.activeWindowUuid = ""

			tabpage:resolveActiveWindowUuid({ window })

			assert.are.equal("window-uuid", tabpage.activeWindowUuid)
			assert.is_nil(tabpage.activeWindowId)
		end)

		it("leaves activeWindowUuid unchanged when activeWindowId matches no window", function()
			tabpage.activeWindowId = 999
			tabpage.activeWindowUuid = "pre-existing-uuid"

			tabpage:resolveActiveWindowUuid({ window })

			assert.are.equal("pre-existing-uuid", tabpage.activeWindowUuid)
			assert.is_nil(tabpage.activeWindowId)
		end)

		it("resolves activeWindowUuid to the matching window among several windows", function()
			local windowOne = Window:new({ uuid = "window-uuid-1", windowId = 41 })
			local windowTwo = Window:new({ uuid = "window-uuid-2", windowId = 42 })
			tabpage.activeWindowId = 42
			tabpage.activeWindowUuid = ""

			tabpage:resolveActiveWindowUuid({ windowOne, windowTwo })

			assert.are.equal("window-uuid-2", tabpage.activeWindowUuid)
			assert.is_nil(tabpage.activeWindowId)
		end)
	end)
end)
