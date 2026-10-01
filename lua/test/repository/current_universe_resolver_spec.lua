local stub = require("luassert.stub")
local multiverse_repository = require("multiverse.repositories.multiverse_repository")
local current_universe_resolver = require("multiverse.repositories.current_universe_resolver")
local Multiverse = require("multiverse.data.Multiverse")
local UniverseSummary = require("multiverse.data.UniverseSummary")

describe("current_universe_resolver.resolve_current_universe_summary", function()
  local getMultiverse_stub

  after_each(function()
    if getMultiverse_stub then
      getMultiverse_stub:revert()
      getMultiverse_stub = nil
    end
  end)

  it("returns the universe summary matching the given cwd exactly", function()
    local cwd = "/tmp/multiverse-resolver-spec/exact"
    local universe_summary = UniverseSummary:new({ directory = cwd, uuid = "exact-uuid", name = "exact-universe" })
    local multiverse = Multiverse:new({ universe_summary })

    getMultiverse_stub = stub(multiverse_repository, "getMultiverse")
    getMultiverse_stub.returns(multiverse)

    assert.are.equal(universe_summary, current_universe_resolver.resolve_current_universe_summary(cwd))
  end)

  it("falls back to a trailing-slash lookup when the exact cwd doesn't match", function()
    local cwd = "/tmp/multiverse-resolver-spec/trailing-slash"
    local universe_summary =
      UniverseSummary:new({ directory = cwd .. "/", uuid = "trailing-uuid", name = "trailing-universe" })
    local multiverse = Multiverse:new({ universe_summary })

    getMultiverse_stub = stub(multiverse_repository, "getMultiverse")
    getMultiverse_stub.returns(multiverse)

    assert.are.equal(universe_summary, current_universe_resolver.resolve_current_universe_summary(cwd))
  end)

  it("returns nil when the given cwd does not match any known universe", function()
    local universe_summary = UniverseSummary:new({
      directory = "/tmp/multiverse-resolver-spec/other",
      uuid = "other-uuid",
      name = "other-universe",
    })
    local multiverse = Multiverse:new({ universe_summary })

    getMultiverse_stub = stub(multiverse_repository, "getMultiverse")
    getMultiverse_stub.returns(multiverse)

    assert.is_nil(current_universe_resolver.resolve_current_universe_summary("/tmp/multiverse-resolver-spec/unmatched"))
  end)

  it("returns nil when no multiverse is loaded", function()
    getMultiverse_stub = stub(multiverse_repository, "getMultiverse")
    getMultiverse_stub.returns(nil)

    assert.is_nil(current_universe_resolver.resolve_current_universe_summary("/tmp/multiverse-resolver-spec/any"))
  end)
end)
