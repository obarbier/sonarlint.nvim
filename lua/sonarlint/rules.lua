local M = {}

function M.show_rule_handler(err, result, context)
   local buf = vim.api.nvim_create_buf(false, true)
   vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
   vim.api.nvim_buf_set_option(buf, "readonly", true)

   local htmlDescription = result.htmlDescription

   if htmlDescription == nil or htmlDescription == "" then
      local htmlDescriptionTab = result.htmlDescriptionTabs[1]
      local ruleDescriptionTabHtmlContent = htmlDescriptionTab.ruleDescriptionTabContextual.htmlContent
         or htmlDescriptionTab.ruleDescriptionTabNonContextual.htmlContent
      htmlDescription = ruleDescriptionTabHtmlContent
   end

   local markdown_lines = vim.lsp.util.convert_input_to_markdown_lines(htmlDescription)
   vim.api.nvim_buf_set_lines(buf, -1, -1, false, markdown_lines)

   vim.cmd("vsplit")
   local win = vim.api.nvim_get_current_win()
   vim.api.nvim_win_set_buf(win, buf)
end

function M.list_all_rules()
   local client = require("sonarlint.utils").get_sonarlint_client()
   client.request("sonarlint/listAllRules", {}, function(err, result)
      if err then
         vim.notify("Cannot request the list of rules: " .. err, vim.log.levels.ERROR)
         return
      end
      local buf = vim.api.nvim_create_buf(false, true)

      for language, rules in pairs(result) do
         vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "# " .. language, "" })

         for _, rule in ipairs(rules) do
            local line = { " - ", rule.key, ": ", rule.name }

            if rule.activeByDefault then
               line[#line + 1] = " (active by default)"
            end
            vim.api.nvim_buf_set_lines(buf, -1, -1, false, { table.concat(line, "") })
         end
         vim.api.nvim_buf_set_lines(buf, -1, -1, false, { "" })
      end

      vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
      vim.api.nvim_buf_set_option(buf, "readonly", true)
      vim.api.nvim_buf_set_option(buf, "modifiable", false)
      vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf, silent = true })

      vim.cmd("vsplit")
      local win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(win, buf)
   end)
end

vim.api.nvim_create_user_command("SonarlintListRules", M.list_all_rules, {})

return M
