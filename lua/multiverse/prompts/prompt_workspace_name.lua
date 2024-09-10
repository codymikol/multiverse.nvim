local function show_input_prompt()
  vim.ui.input({ prompt = 'New workspace name: ' }, function(workspaceName)
    if workspaceName then
      local cwd = vim.fn.getcwd()

      local newWorkspace = buildWorkspace(workspaceName, cwd)

      local newWorkspaceJson = newWorkspace:toJsonString()

      print("you built", newWorkspaceJson)
    else
      print('No input provided.')
    end
  end)
end

-- Call the function to display the prompt
show_input_prompt()
