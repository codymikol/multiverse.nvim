local workspace_factory = require("multiverse.factory.workspace_factory")

local test_workspace_json = [[
{
  "workspaceName": "Test Workspace",
  "workingDirectory": "/home/mikol/Projects/multiverse",
  "tabpages": [
    {
      "id": 1,
      "windows": [
        {
          "id": 1,
          "buffer": {
            "id": 1
          }
        }
      ]
    }
  ]
}
]]

describe("workspace_factory", function()
  describe("building a workspace from a json string successfully", function()
    it("should return a workspace", function()
      local workspace = workspace_factory.make(test_workspace_json)
      assert.are.same(workspace.workspaceName, "Test Workspace")
      assert.are.same(workspace.workingDirectory, "/home/mikol/Projects/multiverse")
      assert.are.same(workspace.tabpages[1].id, 1)
      assert.are.same(workspace.tabpages[1].windows[1].id, 1)
      assert.are.same(workspace.tabpages[1].windows[1].buffer.id, 1)
    end)
  end)
end)
