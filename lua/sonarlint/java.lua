local M = {}

M.classpaths_result = nil

local utils = require("sonarlint.utils")

function M.handle_progress(err, msg, info)
   local client = vim.lsp.get_client_by_id(info.client_id)

   if client.name ~= "jdtls" then
      return
   end
   if msg.value.kind ~= "end" then
      return
   end

   -- TODO: checking the message text seems a little bit brittle. Is there a better way to
   -- determine if jdtls has classpath information ready
   if msg.value.message ~= "Synchronizing projects" then
      return
   end

   require("jdtls.util").with_classpaths(function(result)
      M.classpaths_result = result

      local sonarlint = utils.get_sonarlint_client()
      sonarlint.notify("sonarlint/didClasspathUpdate", {
         projectUri = result.projectRoot,
      })
   end)
end

function M.get_java_config_handler(err, uri)
   local is_test_file = false
   if M.classpaths_result then
      local err, is_test_file_result = require("jdtls.util").execute_command({
         command = "java.project.isTestFile",
         arguments = { uri },
      })
      is_test_file = is_test_file_result
   end

   local classpaths_result = M.classpaths_result or {}

   local config = (utils.get_sonarlint_client() or {}).config or {}

   return {
      projectRoot = classpaths_result.projectRoot or "file:" .. config.root_dir,
      -- TODO: how to get source level from jdtls?
      sourceLevel = "11",
      classpath = classpaths_result.classpaths or {},
      isTest = is_test_file,
      vmLocation = get_jdtls_runtime(),
   }
end

function get_jdtls_runtime()
   local clients = vim.lsp.get_active_clients({ name = "jdtls" })
   local jdtls = clients[1]
   if not jdtls then
      return nil
   end

   local runtimes = (jdtls.config.settings.java.configuration or {}).runtimes or {}

   for i, runtime in ipairs(runtimes) do
      if runtime.default == true then
         return runtime.path
      end
   end

   return runtimes[1].path
end

return M
