local M = {}

function M.setup()
	local notion_apis = require("notion.notion_apis")
	local api_key = vim.env.NOTION_API_KEY

	vim.api.nvim_create_user_command("Notion", function(opts)
		local subcommand = opts.fargs[1]

		if subcommand == "list" then
			notion_apis.list(api_key)
		else
			vim.notify(("Unknown subcommand: %s"):format(subcommand), vim.log.levels.ERROR)
		end
	end, {
		nargs = 1,
		complete = function(_, CmdLine, CursorPos)
			local args = vim.split(CmdLine:sub(1, CursorPos), "%s+")
			local n = #args

			if n <= 2 then
				return { "list" }
			end

			return {}
		end,
	})
end

return M
