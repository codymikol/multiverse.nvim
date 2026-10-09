local stub = require("luassert.stub")

local spec_path = debug.getinfo(1, "S").source:sub(2)
local source_path = spec_path:gsub("test/plugins/neotree_plugin_spec%.lua$", "plugins/neotree_plugin.lua")

local function read_source()
	local file = io.open(source_path, "r")
	assert.is_not_nil(file, "expected to find " .. source_path)

	local contents = file:read("*a")
	file:close()

	return contents
end

describe("plugins.neotree_plugin", function()
	describe("source file contents", function()
		it("does not contain the stale '30% of the total columns' comment", function()
			assert.is_nil(read_source():find("Calculate 30% of the total columns", 1, true))
		end)

		it("notes that the reveal/close/show sequence is unverified before simplifying", function()
			assert.is_not_nil(read_source():find("left as-is", 1, true))
		end)
	end)

	describe("context.beforeDehydrate", function()
		local neotree_plugin
		local json
		local persistance
		local get_dir_stub
		local tmp_dir
		local vim_cmd_stub
		local ctx

		-- Builds a fake `neo-tree.sources.manager` module exposing one
		-- expanded root ("/root"), one expanded child ("/root/a"), one
		-- collapsed child ("/root/b"), with the cursor parked on "/root/a".
		local function make_fake_manager()
			local function make_node(id, expanded, children)
				return {
					get_id = function()
						return id
					end,
					is_expanded = function()
						return expanded
					end,
					get_child_ids = function()
						return children
					end,
				}
			end

			local nodes_by_id = {
				["/root"] = make_node("/root", true, { "/root/a", "/root/b" }),
				["/root/a"] = make_node("/root/a", true, {}),
				["/root/b"] = make_node("/root/b", false, {}),
			}

			local fake_tree = {
				get_nodes = function()
					return { nodes_by_id["/root"] }
				end,
				get_node = function(_, id)
					if id == nil then
						return nodes_by_id["/root/a"]
					end
					return nodes_by_id[id]
				end,
			}

			return {
				get_state = function(source_name)
					assert.equals("filesystem", source_name)
					return { tree = fake_tree }
				end,
			}
		end

		-- The written state file's name is derived from a cwd hash that
		-- isn't part of the public surface, so tests locate it by globbing
		-- the isolated tmp_dir rather than recomputing that hash here.
		local function written_state()
			local files = vim.fn.glob(tmp_dir .. "/*.json", false, true)
			if #files == 0 then
				return nil
			end

			local file = io.open(files[1], "r")
			local contents = file:read("*a")
			file:close()

			return json.decode(contents)
		end

		before_each(function()
			package.loaded["plugins.neotree_plugin"] = nil
			package.loaded["neo-tree.sources.manager"] = nil

			json = require("multiverse.repositories.json")
			persistance = require("multiverse.repositories.persistance")

			tmp_dir = vim.fn.stdpath("data") .. "/multiverse-test-tmp-neotree-state"
			get_dir_stub = stub(persistance, "getDir", function()
				return tmp_dir
			end)

			neotree_plugin = require("plugins.neotree_plugin")
			vim_cmd_stub = stub(vim, "cmd")

			ctx = { universe = { workingDirectory = "/home/test/project" } }
		end)

		after_each(function()
			vim_cmd_stub:revert()
			get_dir_stub:revert()
			vim.fn.delete(tmp_dir, "rf")
			package.loaded["plugins.neotree_plugin"] = nil
			package.loaded["neo-tree.sources.manager"] = nil
		end)

		it("closes Neotree", function()
			neotree_plugin.context.beforeDehydrate(ctx)

			assert.stub(vim_cmd_stub).was.called(1)
			assert.stub(vim_cmd_stub).was.called_with("Neotree close")
		end)

		it("closes Neotree and does not error when ctx has no universe", function()
			neotree_plugin.context.beforeDehydrate({})

			assert.stub(vim_cmd_stub).was.called_with("Neotree close")
			assert.is_nil(written_state())
		end)

		it("persists captured expanded dirs and highlighted path when neo-tree's state API is available", function()
			package.loaded["neo-tree.sources.manager"] = make_fake_manager()

			neotree_plugin.context.beforeDehydrate(ctx)

			assert.same({
				expanded_dirs = { "/root", "/root/a" },
				highlighted_path = "/root/a",
			}, written_state())
			assert.stub(vim_cmd_stub).was.called_with("Neotree close")
		end)

		it("does not write state when neo-tree's module isn't available", function()
			neotree_plugin.context.beforeDehydrate(ctx)

			assert.is_nil(written_state())
			assert.stub(vim_cmd_stub).was.called_with("Neotree close")
		end)

		it("does not write state when get_state returns malformed data", function()
			package.loaded["neo-tree.sources.manager"] = {
				get_state = function()
					return {}
				end,
			}

			neotree_plugin.context.beforeDehydrate(ctx)

			assert.is_nil(written_state())
			assert.stub(vim_cmd_stub).was.called_with("Neotree close")
		end)

		it("does not write state and does not crash when get_state throws", function()
			package.loaded["neo-tree.sources.manager"] = {
				get_state = function()
					error("boom")
				end,
			}

			neotree_plugin.context.beforeDehydrate(ctx)

			assert.is_nil(written_state())
			assert.stub(vim_cmd_stub).was.called_with("Neotree close")
		end)
	end)

	describe("context.afterHydrate", function()
		local neotree_plugin
		local persistance
		local tmp_dir
		local get_dir_stub
		-- shared log so call order across vim.cmd and nvim_win_set_width can be asserted together
		local call_log
		local vim_cmd_stub
		local nvim_win_set_width_stub
		local getcwd_stub
		local nvim_get_current_win_stub

		local pinned_prefix = {
			{ name = "cmd", arg = "wincmd H" },
			{ name = "cmd", arg = "vsplit" },
			{ name = "cmd", arg = "wincmd h" },
			{ name = "nvim_win_set_width", win_id = 4242, width = 36 },
			{ name = "cmd", arg = "Neotree reveal current /home/test/project" },
			{ name = "cmd", arg = "Neotree close" },
			{ name = "cmd", arg = "Neotree show" },
		}

		local function assert_pinned_prefix(log)
			assert.same(pinned_prefix, { log[1], log[2], log[3], log[4], log[5], log[6], log[7] })
		end

		-- Fake `neo-tree.sources.manager` used only to seed a real state file
		-- via the plugin's own `beforeDehydrate`, so the written file's path
		-- always matches what `afterHydrate` will look up (that path's exact
		-- naming isn't part of the public surface).
		local function make_seed_manager()
			local nodes_by_id = {
				["/root"] = {
					get_id = function()
						return "/root"
					end,
					is_expanded = function()
						return true
					end,
					get_child_ids = function()
						return { "/root/a" }
					end,
				},
				["/root/a"] = {
					get_id = function()
						return "/root/a"
					end,
					is_expanded = function()
						return true
					end,
					get_child_ids = function()
						return {}
					end,
				},
			}

			local fake_tree = {
				get_nodes = function()
					return { nodes_by_id["/root"] }
				end,
				get_node = function(_, id)
					if id == nil then
						return nodes_by_id["/root/a"]
					end
					return nodes_by_id[id]
				end,
			}

			return {
				get_state = function()
					return { tree = fake_tree }
				end,
			}
		end

		-- Fake manager used as the *restore target*: `nodes_spec` maps node
		-- id -> initial expanded state, mirroring the mutable is_expanded /
		-- expand pair a real NuiTree.Node exposes. Omitting an id simulates
		-- a node that no longer exists after hydrate.
		local function make_restore_manager(nodes_spec)
			local nodes_by_id = {}
			for id, expanded in pairs(nodes_spec) do
				local is_expanded = expanded
				nodes_by_id[id] = {
					get_id = function()
						return id
					end,
					is_expanded = function()
						return is_expanded
					end,
					expand = function()
						is_expanded = true
					end,
				}
			end

			local fake_tree = {
				get_node = function(_, id)
					return nodes_by_id[id]
				end,
			}

			return {
				get_state = function()
					return { tree = fake_tree }
				end,
			}
		end

		-- Seeds a state file for `cwd` (expanded_dirs = {"/root", "/root/a"},
		-- highlighted_path = "/root/a") and clears whatever this seeding
		-- itself logged, so tests only see afterHydrate's own calls.
		local function seed_state(cwd)
			package.loaded["neo-tree.sources.manager"] = make_seed_manager()
			neotree_plugin.context.beforeDehydrate({ universe = { workingDirectory = cwd } })
			package.loaded["neo-tree.sources.manager"] = nil
			while #call_log > 0 do
				table.remove(call_log)
			end
		end

		before_each(function()
			package.loaded["plugins.neotree_plugin"] = nil
			package.loaded["neo-tree.sources.manager"] = nil

			persistance = require("multiverse.repositories.persistance")
			tmp_dir = vim.fn.stdpath("data") .. "/multiverse-test-tmp-neotree-state-afterhydrate"
			get_dir_stub = stub(persistance, "getDir", function()
				return tmp_dir
			end)

			neotree_plugin = require("plugins.neotree_plugin")

			call_log = {}

			vim_cmd_stub = stub(vim, "cmd", function(command)
				table.insert(call_log, { name = "cmd", arg = command })
			end)

			nvim_win_set_width_stub = stub(vim.api, "nvim_win_set_width", function(win_id, width)
				table.insert(call_log, { name = "nvim_win_set_width", win_id = win_id, width = width })
			end)

			getcwd_stub = stub(vim.fn, "getcwd")
			getcwd_stub.returns("/home/test/project")

			nvim_get_current_win_stub = stub(vim.api, "nvim_get_current_win")
			nvim_get_current_win_stub.returns(4242)
		end)

		after_each(function()
			vim_cmd_stub:revert()
			nvim_win_set_width_stub:revert()
			getcwd_stub:revert()
			nvim_get_current_win_stub:revert()
			get_dir_stub:revert()
			vim.fn.delete(tmp_dir, "rf")
			package.loaded["plugins.neotree_plugin"] = nil
			package.loaded["neo-tree.sources.manager"] = nil
		end)

		it("pins the exact call sequence used to work around Neotree hijacking the multiverse window", function()
			neotree_plugin.context.afterHydrate({})

			assert.same(pinned_prefix, call_log)
		end)

		it("only runs the pinned sequence when no state was captured for this cwd", function()
			neotree_plugin.context.afterHydrate({})

			assert.same(pinned_prefix, call_log)
		end)

		it("re-expands captured dirs and reveals the highlighted path when neo-tree's module is available", function()
			seed_state("/home/test/project")
			package.loaded["neo-tree.sources.manager"] = make_restore_manager({
				["/root"] = false,
				["/root/a"] = false,
			})

			neotree_plugin.context.afterHydrate({})

			assert_pinned_prefix(call_log)
			assert.same({ name = "cmd", arg = "Neotree reveal_file=/root/a" }, call_log[#call_log])

			local manager = package.loaded["neo-tree.sources.manager"]
			local tree = manager.get_state("filesystem").tree
			assert.is_true(tree:get_node("/root"):is_expanded())
			assert.is_true(tree:get_node("/root/a"):is_expanded())
		end)

		it("does not crash and still runs the pinned sequence when neo-tree's module isn't available", function()
			seed_state("/home/test/project")
			package.loaded["neo-tree.sources.manager"] = nil

			neotree_plugin.context.afterHydrate({})

			assert_pinned_prefix(call_log)
		end)

		it("skips dirs that no longer exist but still restores the rest and does not crash", function()
			seed_state("/home/test/project")
			package.loaded["neo-tree.sources.manager"] = make_restore_manager({
				["/root"] = false,
			})

			neotree_plugin.context.afterHydrate({})

			assert_pinned_prefix(call_log)

			local manager = package.loaded["neo-tree.sources.manager"]
			local tree = manager.get_state("filesystem").tree
			assert.is_true(tree:get_node("/root"):is_expanded())
			assert.same({ name = "cmd", arg = "Neotree reveal_file=/root/a" }, call_log[#call_log])
		end)
	end)
end)
