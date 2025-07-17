local M = {}

local addNewUniverseUsecase = require("multiverse.usecases.addNewUniverseUsecase")
local promptSelectUniverseUsecase = require("multiverse.usecases.promptSelectUniverseUsecase")
local removeUniverseUsecase = require("multiverse.usecases.removeUniverseUsecase")

M.registerCommands = function ()

  vim.api.nvim_create_user_command(
    "MultiverseAdd",
    function (opts)
      addNewUniverseUsecase.run(opts.fargs[1], opts.fargs[2])
    end,
    {
      nargs = '*',
      complete = 'file'
    }
  )

  vim.api.nvim_create_user_command(
    "MultiverseRemove",
    function (opts)
      removeUniverseUsecase.run(opts.fargs[1])
    end,
    { nargs = '*' }
  )

  vim.api.nvim_create_user_command(
    "MultiverseList",
    function ()
      promptSelectUniverseUsecase.run()
    end,
    { nargs = 0 }
  )

end

return M
