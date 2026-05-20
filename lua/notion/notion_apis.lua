local M = {}

local utils = require("notion.utils")

local function request(opts, callback)
	local args = {
		"curl",
		"-s",
		"-X",
		opts.method or "GET",
		opts.url,
		"-H",
		"Authorization: Bearer " .. opts.api_key,
		"-H",
		"Notion-Version: 2022-06-28",
		"-H",
		"Content-Type: application/json",
	}
	if opts.body then
		table.insert(args, "-d")
		table.insert(args, opts.body)
	end
	vim.system(args, { text = true }, function(obj)
		if obj.code ~= 0 then
			utils.schedule_notify("[notion.nvim] Request failed", vim.log.levels.ERROR)
			return callback(nil)
		end
		callback(obj.stdout)
	end)
end

local function fetch_pages(api_key, callback)
	request({
		method = "POST",
		url = "https://api.notion.com/v1/search",
		api_key = api_key,
		body = vim.json.encode({
			filter = { property = "object", value = "page" },
		}),
	}, function(data)
		if not data then
			return
		end
		local ok, decoded = pcall(vim.json.decode, data)
		if not ok then
			utils.schedule_notify("[notion.nvim] Invalid JSON response", vim.log.levels.ERROR)
			return
		end
		local pages = {}
		for _, page in ipairs(decoded.results or {}) do
			local title = vim.tbl_get(page, "properties", "title", "title", 1, "plain_text")
			if title then
				pages[#pages + 1] = { title = title, id = page.id }
			end
		end
		callback(pages)
	end)
end

local function fetch_page_markdown(api_key, page_id, callback)
	request({
		method = "GET",
		url = "https://api.notion.com/v1/pages/" .. page_id .. "/markdown",
		api_key = api_key,
	}, callback)
end

function M.list(api_key)
	if not api_key then
		utils.schedule_notify("[notion.nvim] Missing api key", vim.log.levels.ERROR)
		return
	end

	fetch_pages(api_key, function(pages)
		if not pages then
			return
		end
		vim.schedule(function()
			vim.ui.select(pages, {
				prompt = "Open Notion Page:",
				format_item = function(item)
					return item.title
				end,
			}, function(selected)
				if not selected then
					return
				end
				fetch_page_markdown(api_key, selected.id, function(response)
					local ok, markdown = pcall(vim.json.decode, response)
					if not ok then
						utils.schedule_notify("[notion.nvim] Invalid JSON response", vim.log.levels.ERROR)
						return
					end

					if not markdown.markdown then
						print("No markdown found")
						return
					end
					print(markdown.markdown)
				end)
			end)
		end)
	end)
end

return M
