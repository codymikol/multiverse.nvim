describe("universe_summary_factory make", function()
  local factory = require("multiverse.factory.universe_summary_factory")
  local json = require("multiverse.repositories.json")
  local log = require("multiverse.log")
  local stub = require("luassert.stub")

  before_each(function()
    stub(log, "warn")
    stub(log, "error")
  end)

  after_each(function()
    log.warn:revert()
    log.error:revert()
  end)

  it("preserves all summary fields", function()
    local summary = factory.make(json.encode({
      directory = "/projects/example", uuid = "uuid-1", name = "Example", lastExplored = 123456,
    }))
    assert.are.equal("/projects/example", summary.directory)
    assert.are.equal("uuid-1", summary.uuid)
    assert.are.equal("Example", summary.name)
    assert.are.equal(123456, summary.lastExplored)
  end)

  it("allows a summary that has not been explored", function()
    local summary = factory.make(json.encode({ directory = "/p", uuid = "uuid-1", name = "Example" }))
    assert.is_nil(summary.lastExplored)
  end)

  it("returns nil rather than throwing for malformed JSON", function()
    assert.is_nil(factory.make("{broken"))
    assert.stub(log.error).was_called()
  end)

  it("rejects decoded scalar values", function()
    for _, value in ipairs({ "42", "true", '"name"' }) do
      assert.is_nil(factory.make(value))
    end
  end)

  it("rejects missing or invalid required fields", function()
    for _, field in ipairs({ "directory", "uuid", "name" }) do
      for _, invalid in ipairs({ false, "", 42 }) do
        local value = { directory = "/p", uuid = "uuid-1", name = "Example" }
        value[field] = invalid
        assert.is_nil(factory.make(json.encode(value)))
      end
      local value = { directory = "/p", uuid = "uuid-1", name = "Example" }
      value[field] = nil
      assert.is_nil(factory.make(json.encode(value)))
    end
  end)
end)
