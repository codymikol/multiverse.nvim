describe("window_layout_factory make", function()
	local window_layout_factory = require("multiverse.factory.window_layout_factory")
	local Universe = require("multiverse.data.Universe")
	local Window = require("multiverse.data.Window")
	local Tabpage = require("multiverse.data.Tabpage")

	local universe = Universe:new("", "example", "/home/foo")

	local tabpage = Tabpage:new()

	local uuid1 = "258ca574-a7f2-47ad-a843-250a617ba634"
	local uuid2 = "beb59ba6-b646-4a03-9a84-a53adaaaf4b0"
	local uuid3 = "2eeb7904-9216-4ec4-abd0-b3d40d125b9e"
	local uuid4 = "61551161-55df-4f73-87a4-94956a313446"

	local windowOne = Window:new(uuid1, 1)
	local windowTwo = Window:new(uuid2, 2)
	local windowThree = Window:new(uuid3, 3)
	local windowFour = Window:new(uuid4, 4)

	tabpage:addAllWindows({ windowOne, windowTwo, windowThree, windowFour })

	universe:addTabpage(tabpage)

	local nvimLayout = {
		"row",
		{
			{ "leaf", 1 },
			{ "leaf", 2 },
			{
				"col",
				{
					{ "leaf", 3 },
					{
						"row",
						{
							{ "leaf", 4 },
							{ "leaf", 1 }, -- Because a buffer can be on multiple windows...
						},
					},
				},
			},
		},
	}

	local window_layout = window_layout_factory.make(nvimLayout, universe)

	it("should return a window layout", function()
		assert.is_not.Nil(window_layout)
	end)

	it("should contain a children list", function()
		assert.is_not.Nil(window_layout.children)
	end)

	it("should have one item at the fist node", function()
		assert.are.equal(1, #window_layout.children)
	end)

	local firstRow = window_layout.children[1]

	it("should be a row as the first child", function()
		assert.are.equal("row", firstRow.type)
	end)

	it("should have three children on the first row", function()
		assert.are.equal(3, #firstRow.children)
	end)

	local firstRowChild = firstRow.children[1]
	local secondRowChild = firstRow.children[2]
	local thirdRowChild = firstRow.children[3]

	it("should have the correct types for the first row child", function()
		assert.are.equal("leaf", firstRowChild.type)
	end)

	it("should have the correct windowUuid for the first row child", function()
		assert.are.equal(uuid1, firstRowChild.windowUuid)
	end)

	it("should have the correct types for the second row child", function()
		assert.are.equal("leaf", secondRowChild.type)
	end)

	it("should have the correct windowUuid for the second row child", function()
		assert.are.equal(uuid2, secondRowChild.windowUuid)
	end)

	it("should have the correct types for the third row child", function()
		assert.are.equal("column", thirdRowChild.type)
	end)

	local thirdRowColumnChildren = thirdRowChild.children

	it("should have the correct number of children on the column", function()
		assert.are.equal(2, #thirdRowColumnChildren)
	end)

	local thirdRowColumnFirstChild = thirdRowColumnChildren[1]
	local thirdRowColumnSecondChild = thirdRowColumnChildren[2]

	it("should have the correct types for the first column child", function()
		assert.are.equal("leaf", thirdRowColumnFirstChild.type)
	end)

	it("should have the correct window uuid for the first column child", function()
		assert.are.equal(uuid3, thirdRowColumnFirstChild.windowUuid)
	end)

	it("should have the correct types for the second column child", function()
		assert.are.equal("row", thirdRowColumnSecondChild.type)
	end)

	it("should have the correct number of children on the second row", function()
		assert.are.equal(2, #thirdRowColumnSecondChild.children)
	end)

	local thirdRowColumnSecondChildFirstRowChild = thirdRowColumnSecondChild.children[1]

	it("should have the correct types for the first row child", function()
		assert.are.equal("leaf", thirdRowColumnSecondChildFirstRowChild.type)
	end)

	it("should have the correct window uuid for the first row child", function()
		assert.are.equal(uuid4, thirdRowColumnSecondChildFirstRowChild.windowUuid)
	end)

	it("should have the correct types for the second row child", function()
		assert.are.equal("leaf", thirdRowColumnSecondChild.children[2].type)
	end)

	it("should have the correct window uuid for the second row child", function()
		assert.are.equal(uuid1, thirdRowColumnSecondChild.children[2].windowUuid)
	end)
end)

describe("window_layout_factory makeFromJson", function()
	local window_layout_factory = require("multiverse.factory.window_layout_factory")

	local json = [[
      {
        "children": [
          {
            "children": [
              {
                "type": "leaf",
                "windowUuid": "87b7e150-f9bf-4928-9982-f36744d7cc5f",
              },
              {
                "type": "column",
                "children": [
                  {
                    "type": "leaf",
                    "windowUuid": "b4835583-7192-4a0a-a637-f10ad7a79faa",
                  },
                  {
                    "children": [
                      {
                        "type": "leaf",
                        "windowUuid": "d217cf15-5d8f-411e-b8ef-9776d70e69f6",
                      },
                      {
                        "type": "leaf",
                        "windowUuid": "7ca91b10-a88f-4454-84a5-0adb8a1dcf38",
                      }
                    ],
                    "type": "row"
                  }
                ]
              }
            ],
            "type": "row"
          }
        ],
        "type": "window_layout"
      }
  ]]

	local result = window_layout_factory.makeFromJson(json)

	it("should return a non-nil result", function()
		assert.is_not.Nil(result)
	end)

	it("should have a children list", function()
		assert.is_not.Nil(result.children)
	end)

	it("should have one child", function()
		assert.are.equal(1, #result.children)
	end)
end)
