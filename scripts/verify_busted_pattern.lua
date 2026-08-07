-- Verifies that the busted `.busted` config at the repo root defines a
-- `_all.pattern` that matches every `*.spec.lua` file under lua/test/
-- (these are real busted specs) and excludes every `*.headless.lua` file
-- (these require a real nvim instance and call os.exit(), so they must
-- never be picked up by busted).
--
-- This is NOT a busted spec itself. It is a plain Lua script intended to
-- be run with:
--
--   nvim --headless -l scripts/verify_busted_pattern.lua
--
-- because this sandbox has no busted/luarocks/nix available to actually
-- execute busted.

local function fail(msg)
  print("FAIL: " .. msg)
  os.exit(1)
end

-- Discover all *.lua files under lua/test/ recursively using vim.fn.globpath.
local found = vim.fn.globpath("lua/test", "**/*.lua", false, true)

if #found == 0 then
  fail("no *.lua files discovered under lua/test/ -- did the working directory change?")
end

-- Load the busted config table from .busted at the repo root.
local ok, config = pcall(dofile, ".busted")
if not ok then
  fail("could not load .busted config: " .. tostring(config))
end

if type(config) ~= "table" or type(config._all) ~= "table" or type(config._all.pattern) ~= "string" then
  fail(".busted config does not define a string _all.pattern")
end

local pattern = config._all.pattern

local spec_files = {}
local headless_files = {}

for _, filename in ipairs(found) do
  if filename:match("%.spec%.lua$") then
    table.insert(spec_files, filename)
  elseif filename:match("%.headless%.lua$") then
    table.insert(headless_files, filename)
  end
end

if #spec_files == 0 then
  fail("no *.spec.lua files discovered under lua/test/ -- expected at least one")
end

if #headless_files == 0 then
  fail("no *.headless.lua files discovered under lua/test/ -- expected at least one")
end

local failures = {}

for _, filename in ipairs(spec_files) do
  if not string.find(filename, pattern) then
    table.insert(failures, "expected spec file to MATCH pattern but it did not: " .. filename)
  end
end

for _, filename in ipairs(headless_files) do
  if string.find(filename, pattern) then
    table.insert(failures, "expected headless file to NOT match pattern but it did: " .. filename)
  end
end

if #failures > 0 then
  for _, msg in ipairs(failures) do
    print("FAIL: " .. msg)
  end
  os.exit(1)
end

print(
  string.format(
    "PASS: pattern %q matched all %d spec file(s) and excluded all %d headless file(s)",
    pattern,
    #spec_files,
    #headless_files
  )
)
os.exit(0)
