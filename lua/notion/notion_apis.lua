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
		body = vim.json.encode({ filter = { property = "object", value = "page" } }),
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

local function fetch_blocks(api_key, block_id, callback)
	request({
		method = "GET",
		url = "https://api.notion.com/v1/blocks/" .. block_id .. "/children",
		api_key = api_key,
	}, function(data)
		if not data then
			return callback(nil)
		end

		local ok, decoded = pcall(vim.json.decode, data)
		if not ok then
			return callback(nil)
		end

		callback(decoded.results or {})
	end)
end

local function extract_text(rich_text)
	local parts = {}

	for _, rt in ipairs(rich_text or {}) do
		parts[#parts + 1] = rt.plain_text or ""
	end

	return table.concat(parts)
end

local function split_lines(text, prefix)
	local result = {}

	for _, line in ipairs(vim.split(text, "\n", { plain = true })) do
		result[#result + 1] = prefix .. line
	end

	if #result == 0 then
		result[#result + 1] = prefix
	end

	return result
end

local function block_to_lines(block, prefix)
	local t = block.type

	if t == "paragraph" then
		return split_lines(extract_text(block.paragraph.rich_text), prefix)
	elseif t == "heading_1" then
		return split_lines("# " .. extract_text(block.heading_1.rich_text), prefix)
	elseif t == "heading_2" then
		return split_lines("## " .. extract_text(block.heading_2.rich_text), prefix)
	elseif t == "heading_3" then
		return split_lines("### " .. extract_text(block.heading_3.rich_text), prefix)
	elseif t == "bulleted_list_item" then
		return split_lines("- " .. extract_text(block.bulleted_list_item.rich_text), prefix)
	elseif t == "numbered_list_item" then
		return split_lines("1. " .. extract_text(block.numbered_list_item.rich_text), prefix)
	elseif t == "to_do" then
		local check = block.to_do.checked and "[x]" or "[ ]"
		return split_lines("- " .. check .. " " .. extract_text(block.to_do.rich_text), prefix)
	elseif t == "quote" then
		return split_lines("> " .. extract_text(block.quote.rich_text), prefix)
	elseif t == "divider" then
		return { prefix .. "---" }
	elseif t == "code" then
		local lang = block.code.language or ""
		local result = { prefix .. "```" .. lang }

		for _, line in ipairs(vim.split(extract_text(block.code.rich_text), "\n", { plain = true })) do
			result[#result + 1] = prefix .. line
		end

		result[#result + 1] = prefix .. "```"

		return result
	elseif t == "callout" then
		local icon = ""

		if block.callout.icon then
			if block.callout.icon.type == "emoji" then
				icon = (block.callout.icon.emoji or "") .. " "
			end
		end

		return split_lines(icon .. extract_text(block.callout.rich_text), prefix)
	elseif t == "toggle" then
		return split_lines(extract_text(block.toggle.rich_text), prefix)
	elseif t == "table_row" then
		local cells = {}

		for _, cell in ipairs(block.table_row.cells or {}) do
			cells[#cells + 1] = extract_text(cell)
		end

		return { prefix .. "| " .. table.concat(cells, " | ") .. " |" }
	elseif t == "image" then
		local url = ""

		if block.image.type == "external" then
			url = block.image.external.url or ""
		elseif block.image.type == "file" then
			url = block.image.file.url or ""
		end

		local caption = extract_text(block.image.caption or {})
		local label = caption ~= "" and caption or "image"

		return { prefix .. "![" .. label .. "](" .. url .. ")" }
	elseif t == "bookmark" then
		local url = block.bookmark.url or ""
		local caption = extract_text(block.bookmark.caption or {})
		local label = caption ~= "" and caption or url

		return { prefix .. "[" .. label .. "](" .. url .. ")" }
	elseif t == "link_preview" then
		return { prefix .. block.link_preview.url }
	elseif t == "equation" then
		return { prefix .. "$$" .. (block.equation.expression or "") .. "$$" }
	end
	return {}
end

local function sanitize_lines(lines)
	local result = {}

	for _, line in ipairs(lines) do
		if line:find("\n", 1, true) then
			for _, l in ipairs(vim.split(line, "\n", { plain = true })) do
				result[#result + 1] = l
			end
		else
			result[#result + 1] = line
		end
	end

	return result
end

local function render_blocks(api_key, block_id, depth, callback)
	fetch_blocks(api_key, block_id, function(blocks)
		if not blocks or #blocks == 0 then
			return callback({})
		end

		local prefix = string.rep("  ", depth)
		local total = #blocks
		local pending = 0
		local segment_map = {}

		for i, block in ipairs(blocks) do
			if block.type == "child_page" then
				pending = pending + 1
			else
				segment_map[i] = block_to_lines(block, prefix)
			end
		end

		local function try_finish()
			if pending > 0 then
				return
			end

			local result = {}

			for j = 1, total do
				for _, l in ipairs(segment_map[j] or {}) do
					result[#result + 1] = l
				end
			end

			callback(result)
		end

		for i, block in ipairs(blocks) do
			if block.type == "child_page" then
				local idx = i
				local title = block.child_page.title or "(untitled)"

				render_blocks(api_key, block.id, depth + 1, function(child_lines)
					local section = { prefix .. "--- " .. title }

					for _, l in ipairs(child_lines) do
						section[#section + 1] = l
					end

					segment_map[idx] = section
					pending = pending - 1

					try_finish()
				end)
			end
		end

		try_finish()
	end)
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

				render_blocks(api_key, selected.id, 0, function(lines)
					vim.schedule(function()
						local safe_lines = sanitize_lines(lines)
						local buf = vim.api.nvim_create_buf(false, true)

						vim.api.nvim_buf_set_name(buf, "notion://" .. selected.id)
						vim.api.nvim_buf_set_lines(buf, 0, -1, false, safe_lines)
						vim.bo[buf].filetype = "markdown"
						vim.bo[buf].buftype = "nofile"
						vim.bo[buf].modifiable = false
						vim.bo[buf].buflisted = true
						vim.api.nvim_set_current_buf(buf)
					end)
				end)
			end)
		end)
	end)
end

return M
