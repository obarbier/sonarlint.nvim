local M = {}

M._init = false
M._server_ready = false
M._co = {}
M._classpath_change_listener = false

-- https://github.com/redhat-developer/vscode-java/blob/38c8b582b40db9644696924f899c73a3251563f4/src/protocol.ts#L59
M.EventType = {
   classpathUpdated = 100,
   projectsImported = 200,
   projectsDeleted = 210,
   incompatibleGradleJdkIssue = 300,
   upgradeGradleWrapper = 400,
   sourceInvalidated = 500,
}

local utils = require("sonarlint.utils")

-- https://github.com/redhat-developer/vscode-java/blob/38c8b582b40db9644696924f899c73a3251563f4/src/standardLanguageClient.ts#L192
function M.handle_event_notify(_, msg)
   if msg.eventType == M.EventType.classpathUpdated then
      local sonarlint = utils.get_sonarlint_client()
      sonarlint.notify("sonarlint/didClasspathUpdate", {
         projectUri = msg.data,
      })
   end
end

function M.install_classpath_listener()
   if M._classpath_change_listener then
      return
   end
   M._classpath_change_listener = true

   local client = utils.get_jdtls_client()
   -- JdtUpdateConfig
   if client.config.handlers["language/eventNotification"] then
      local old_handler = client.config.handlers["language/eventNotification"]
      client.config.handlers["language/eventNotification"] = function(...)
         old_handler(...)
         M.handle_event_notify(...)
      end
   else
      client.config.handlers["language/eventNotification"] = M.handle_event_notify
   end
end

function M.handle_service_ready(err, msg)
   if "ServiceReady" == msg.type then
      M._server_ready = true
      for _, co in ipairs(M._co) do
         coroutine.resume(co)
      end
      M._co = {}
   end
end

function M.get_java_config_handler(err, file_uri)
   local uri = type(file_uri) == "table" and file_uri[1] or file_uri

   if M._server_ready then
      M.install_classpath_listener()
      return request_settings(uri)
   else
      local pco = coroutine.running()
      local co = coroutine.create(function()
         M.install_classpath_listener()
         local resp = request_settings(uri)
         coroutine.resume(pco, resp)
         return resp
      end)

      table.insert(M._co, co)

      return coroutine.yield()
   end
end

function request_settings(uri)
   local bufnr = vim.uri_to_bufnr(uri)

   local e, settings = require("sonarlint.utils.jdtls").execute_command({
      command = "java.project.getSettings",
      arguments = {
         uri,
         {
            "org.eclipse.jdt.core.compiler.source",
            "org.eclipse.jdt.ls.core.vm.location",
         },
      },
   }, nil, bufnr)

   local vm_location = nil
   local source_level = nil

   if settings then
      vm_location = settings["org.eclipse.jdt.ls.core.vm.location"]
      source_level = settings["org.eclipse.jdt.core.compiler.source"]
   end

   local is_test_file_cmd = {
      command = "java.project.isTestFile",
      arguments = { uri },
   }
   local options
   local is_test
   if vim.startswith(uri, "jdt://") then
      is_test = false
      options = vim.fn.json_encode({ scope = "runtime" })
   else
      local err, is_test_file = require("sonarlint.utils.jdtls").execute_command(is_test_file_cmd, nil, bufnr)
      is_test = is_test_file
      assert(not err, vim.inspect(err))
      options = vim.fn.json_encode({
         scope = is_test_file and "test" or "runtime",
      })
   end
   local cmd = {
      command = "java.project.getClasspaths",
      arguments = { uri, options },
   }
   local err1, resp = require("sonarlint.utils.jdtls").execute_command(cmd, nil, bufnr)
   if err1 then
      print("Error executing java.project.getClasspaths: " .. err1.message)
   end

   return {
      projectRoot = resp.projectRoot,
      sourceLevel = source_level,
      classpath = resp.classpaths,
      isTest = is_test,
      vmLocation = vm_location,
   }
end

local function defer_init(ms)
   vim.defer_fn(function()
      M.init_config()
   end, ms)
end
function M.init_config()
   if M._init then
      return
   end
   local client = utils.get_jdtls_client()
   if client == nil then
      defer_init(100)
      return
   end
   M._init = true
   if client.config.handlers["language/status"] then
      local old_handler = client.config.handlers["language/status"]
      client.config.handlers["language/status"] = function(...)
         old_handler(...)
         M.handle_service_ready(...)
      end
   else
      client.config.handlers["language/status"] = M.handle_service_ready
   end
end

return M
