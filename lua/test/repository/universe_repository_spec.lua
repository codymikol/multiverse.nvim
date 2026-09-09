local io = require("io")
local os = require("os")
local stub = require("luassert.stub")

local universe_repository = require("multiverse.repositories.universe_repository")
local persistance = require("multiverse.repositories.persistance")
local json = require("multiverse.repositories.json")

local universe = {
  uuid = "8d1f9c2a-1111-4a2b-9c3d-000000000001",
  name = "example",
  workingDirectory = "/home/foo",
}

local targetFile = persistance.getDir() .. "/universe-" .. universe.uuid .. ".json"
local tmpFile = targetFile .. ".tmp"
local jsonString = json.encode(universe)

describe("universe_repository save_universe", function()

  describe("when writing the temp file and renaming both succeed", function()
    local mock_file
    local calls

    local io_open_stub
    local os_rename_stub
    local write_stub
    local close_stub

    before_each(function()
      calls = {}
      mock_file = {}

      write_stub = stub(mock_file, "write", function()
        table.insert(calls, "write")
        return true
      end)

      close_stub = stub(mock_file, "close", function()
        table.insert(calls, "close")
        return true
      end)

      io_open_stub = stub(io, "open", function() return mock_file, nil end)
      os_rename_stub = stub(os, "rename", function()
        table.insert(calls, "rename")
        return true, nil
      end)
    end)

    after_each(function()
      io_open_stub:revert()
      os_rename_stub:revert()
      write_stub:revert()
      close_stub:revert()
    end)

    it("should open the temp file for writing", function()
      universe_repository.save_universe(universe)

      assert.stub(io_open_stub).was_called_with(tmpFile, "w")
    end)

    it("should write the encoded universe json to the temp file", function()
      universe_repository.save_universe(universe)

      assert.stub(write_stub).was_called_with(mock_file, jsonString)
    end)

    it("should close the temp file before renaming", function()
      universe_repository.save_universe(universe)

      assert.are.same({ "write", "close", "rename" }, calls)
    end)

    it("should rename the temp file to the target file", function()
      universe_repository.save_universe(universe)

      assert.stub(os_rename_stub).was_called_with(tmpFile, targetFile)
    end)

    it("should return the universe and no error", function()
      local returnedUniverse, err = universe_repository.save_universe(universe)

      assert.are.equal(universe, returnedUniverse)
      assert.is_nil(err)
    end)
  end)

  describe("when writing to the temp file fails", function()
    local mock_file
    local io_open_stub
    local os_rename_stub
    local os_remove_stub
    local close_stub

    before_each(function()
      mock_file = {
        write = function() return nil, "some os error" end,
      }

      close_stub = stub(mock_file, "close", function() return true end)

      io_open_stub = stub(io, "open", function() return mock_file, nil end)
      os_rename_stub = stub(os, "rename", function() return true, nil end)
      os_remove_stub = stub(os, "remove", function() return true, nil end)
    end)

    after_each(function()
      io_open_stub:revert()
      os_rename_stub:revert()
      os_remove_stub:revert()
      close_stub:revert()
    end)

    it("should close the temp file handle", function()
      universe_repository.save_universe(universe)

      assert.stub(close_stub).was_called()
    end)

    it("should remove the temp file", function()
      universe_repository.save_universe(universe)

      assert.stub(os_remove_stub).was_called_with(tmpFile)
    end)

    it("should not attempt to rename", function()
      universe_repository.save_universe(universe)

      assert.stub(os_rename_stub).was_not_called()
    end)

    it("should return the universe and an error", function()
      local returnedUniverse, err = universe_repository.save_universe(universe)

      assert.are.equal(universe, returnedUniverse)
      assert.is_not.Nil(err)
    end)
  end)

  describe("when closing the temp file fails", function()
    local mock_file
    local io_open_stub
    local os_rename_stub
    local os_remove_stub

    before_each(function()
      mock_file = {
        write = function() return true end,
        close = function() return nil, "some os error" end,
      }

      io_open_stub = stub(io, "open", function() return mock_file, nil end)
      os_rename_stub = stub(os, "rename", function() return true, nil end)
      os_remove_stub = stub(os, "remove", function() return true, nil end)
    end)

    after_each(function()
      io_open_stub:revert()
      os_rename_stub:revert()
      os_remove_stub:revert()
    end)

    it("should remove the temp file", function()
      universe_repository.save_universe(universe)

      assert.stub(os_remove_stub).was_called_with(tmpFile)
    end)

    it("should not attempt to rename", function()
      universe_repository.save_universe(universe)

      assert.stub(os_rename_stub).was_not_called()
    end)

    it("should return the universe and an error", function()
      local returnedUniverse, err = universe_repository.save_universe(universe)

      assert.are.equal(universe, returnedUniverse)
      assert.is_not.Nil(err)
    end)
  end)

  describe("when opening the temp file fails", function()
    local io_open_stub
    local os_rename_stub

    before_each(function()
      io_open_stub = stub(io, "open", function() return nil, "some os error" end)
      os_rename_stub = stub(os, "rename", function() return true, nil end)
    end)

    after_each(function()
      io_open_stub:revert()
      os_rename_stub:revert()
    end)

    it("should not attempt to rename", function()
      universe_repository.save_universe(universe)

      assert.stub(os_rename_stub).was_not_called()
    end)

    it("should return the universe and an error", function()
      local returnedUniverse, err = universe_repository.save_universe(universe)

      assert.are.equal(universe, returnedUniverse)
      assert.is_not.Nil(err)
    end)
  end)

  describe("when renaming the temp file fails", function()
    local mock_file
    local io_open_stub
    local os_rename_stub
    local os_remove_stub

    before_each(function()
      mock_file = {
        write = function() return true end,
        close = function() return true end,
      }

      io_open_stub = stub(io, "open", function() return mock_file, nil end)
      os_rename_stub = stub(os, "rename", function() return nil, "some os error" end)
      os_remove_stub = stub(os, "remove", function() return true, nil end)
    end)

    after_each(function()
      io_open_stub:revert()
      os_rename_stub:revert()
      os_remove_stub:revert()
    end)

    it("should remove the temp file", function()
      universe_repository.save_universe(universe)

      assert.stub(os_remove_stub).was_called_with(tmpFile)
    end)

    it("should return the universe and an error", function()
      local returnedUniverse, err = universe_repository.save_universe(universe)

      assert.are.equal(universe, returnedUniverse)
      assert.is_not.Nil(err)
    end)
  end)

end)
