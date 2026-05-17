local M = {
	config = {},
}

function M.setup(opts)
	local api_key = vim.env.NOTION_API_KEY

	M.config = vim.tbl_deep_extend("force", {}, opts or {})

	if not api_key then
		vim.notify("[notion.nvim] Missing api key in config", vim.log.levels.ERROR)
		return
	end

	require("notion.commands").setup()
end

return M
