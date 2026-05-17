local M = {}

function M.setup()
	local utils = require("notion.utils")
	local api_key = vim.env.NOTION_API_KEY

	vim.api.nvim_create_user_command("Notion", function(opts)
		local subcommand = opts.fargs[1]

		if subcommand == "list" then
			utils.list(api_key)
		elseif subcommand == "open" then
			print("open selected")
		elseif subcommand == "append" then
			print("append selected")
		else
			vim.notify(("Unknown subcommand: %s"):format(subcommand), vim.log.levels.ERROR)
		end
	end, {
		nargs = 1,
		complete = function(ArgLead, CmdLine, CursorPos)
			local args = vim.split(CmdLine:sub(1, CursorPos), "%s+")
			local n = #args

			if n <= 2 then
				return { "list", "open", "append" }
			end

			return {}
		end,
	})
end

return M
