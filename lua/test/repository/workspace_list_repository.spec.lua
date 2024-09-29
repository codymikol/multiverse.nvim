
local workspace_list_repostiory = require("multiverse.repositories.multiverse_repository")

local io = require("io")
local stub = require("luassert.stub")

local fake_workspace = '[{"name": "Test Workspace", "workingDirectory": "/home/mikol/Projects/multiverse", lastOpened: 123456789}]'
-- make a mock file object

local mock_file = {
  read = function()
    return fake_workspace
  end,
  close = function()
    return true
  end
}

describe("workspace_list_repostiory", function()

  describe("getting a workspace when no file exists", function()
    stub(io, "open", function() return nil end)

    it("should return an empty list", function()
      local workspaces = workspace_list_repostiory.getAllWorkspaces()
      assert.are.same({}, workspaces)
    end)

  end)

  describe("getting a workspace when a file exists", function()
    stub(io, "open", function() return mock_file, nil end)

    it("should return a list of workspaces", function()
      local workspaces = workspace_list_repostiory.getAllWorkspaces()
      assert.are.same({}, workspaces)
    end)

  end)

end)
