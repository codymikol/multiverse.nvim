local sanitize_statusline = require("multiverse.util.sanitize_statusline")

describe("sanitize_statusline.sanitize", function()
	it("strips C0 control bytes and DEL", function()
		assert.are.equal("ab", sanitize_statusline.sanitize("a\027b"))
		assert.are.equal("foobar", sanitize_statusline.sanitize("foo\0bar"))
		assert.are.equal("ab", sanitize_statusline.sanitize("a\127b"))
	end)

	it("leaves bytes >= 0x80 (UTF-8 continuation bytes) untouched", function()
		assert.are.equal("héllo wörld", sanitize_statusline.sanitize("héllo wörld"))
	end)

	it("doubles '%' so the result is safe to embed in a statusline %{...} expression", function()
		assert.are.equal("50%% done", sanitize_statusline.sanitize("50% done"))
	end)

	it("strips control bytes and doubles '%' together", function()
		assert.are.equal("100%% café", sanitize_statusline.sanitize("100%\027 café"))
	end)
end)
