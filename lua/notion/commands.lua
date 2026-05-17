local M = {}

function M.setup()
	vim.api.nvim_create_user_command("Notion", function()
		print("Notion loaded")
	end, {})
end

return M
