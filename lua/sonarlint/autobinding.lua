local M = {}

function M.list_autobinding_files_in_folder(err, params)
   local folder = vim.uri_to_fname(params.folderUri)
   local files = vim.fs.dir(folder)

   local result = {
      foundFiles = {},
   }
   for path, t in files do
      if t == "file" then
         table.insert(result.foundFiles, {
            fileName = path,
            filePath = folder,
         })
      end
   end

   return result
end

return M
