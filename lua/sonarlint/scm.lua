local M = {}
M.last_heads_by_lsp_client = {}

function M.check_git_branch_and_notify_lsp(args)
   local bufnr = args.buf
   local ok, gitsigns_status = pcall(function()
      return vim.api.nvim_buf_get_var(bufnr, "gitsigns_status_dict")
   end)

   if not ok then
      return
   end

   local clients = vim.lsp.get_active_clients({ name = "sonarlint.nvim", bufnr = bufnr })
   for _, client in ipairs(clients) do
      -- ensure that client.workspace_folders is not nil
      if not client.workspace_folders then
         goto continue
      end
      if M.last_heads_by_lsp_client[client.id] ~= gitsigns_status.head then
         client.notify("sonarlint/didLocalBranchNameChange", {
            folderUri = client.workspace_folders[1].uri,
            branchName = gitsigns_status.head,
         })

         M.last_heads_by_lsp_client[client.id] = gitsigns_status.head
      end
      ::continue::
   end
end

function M.is_ignored_by_scm(_, file_uri)
   local uri = type(file_uri) == "table" and file_uri[1] or file_uri
   local bufnr = vim.uri_to_bufnr(uri)
   local ok, gitsigns_status = pcall(function()
      return vim.api.nvim_buf_get_var(bufnr, "gitsigns_status_dict")
   end)

   if not ok then
      -- Assuming that there is no SCM because gitsigns is not available
      return false
   end

   return not gitsigns_status.added
end

return M
