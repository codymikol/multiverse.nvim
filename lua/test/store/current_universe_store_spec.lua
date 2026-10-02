local current_universe_store = require("multiverse.store.current_universe_store")

describe("current_universe_store", function()
  before_each(function()
    vim.g.multiverse_previous_universe = nil
  end)

  after_each(function()
    vim.g.multiverse_previous_universe = nil
  end)

  describe("get_previous_universe/set_previous_universe", function()
    it("returns nil when unset", function()
      assert.are.same(nil, current_universe_store.get_previous_universe())
    end)

    it("round-trips a value through vim.g.multiverse_previous_universe", function()
      current_universe_store.set_previous_universe("universe-a")

      assert.are.same("universe-a", vim.g.multiverse_previous_universe)
      assert.are.same("universe-a", current_universe_store.get_previous_universe())
    end)
  end)
end)
