local M = {}

function M.schedule_notify(message, level)
	vim.schedule(function()
		vim.notify(message, level)
	end)
end

return M
