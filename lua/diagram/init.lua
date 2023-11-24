local M = {}

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function padTableStrings(tbl)
    local maxLength = 0

    -- Find the length of the longest string after trimming
    for _, item in ipairs(tbl) do
        local trimmedItem = trim(item)
        if #trimmedItem > maxLength then
            maxLength = #trimmedItem
        end
    end

    -- Pad each string with spaces to make their lengths equal to maxLength
    for i, item in ipairs(tbl) do
        local trimmedItem = trim(item)
        while #trimmedItem < maxLength do
            trimmedItem = trimmedItem .. " "
        end
        tbl[i] = trimmedItem  -- Update the table with the padded string
    end
end

local function open_floating(lines)
	local width = vim.api.nvim_get_option("columns")
	local height = vim.api.nvim_get_option("lines")
	local win_height = math.ceil(height * 0.98 - 4)
	local win_width = math.ceil(width * 0.9)
	local row = math.ceil((height - win_height) / 2 - 1)
	local col = math.ceil((width - win_width) / 2)
	local buf = vim.api.nvim_create_buf(false, true)

	vim.o.wrap = false
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	local _ = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = row,
		col = col,
		width = win_width,
		height = win_height,
		border = "rounded",
	})
	vim.w.is_floating_scratch = true
end

function SelectCodeFence()
	local parser = vim.treesitter.get_parser(0)
	local tree = parser:parse()[1]
	local root = tree:root()
	local cursor_row, _ = unpack(vim.api.nvim_win_get_cursor(0))

	cursor_row = cursor_row - 1 -- Lua is 1-indexed, Treesitter is 0-indexed

	local function node_contains_cursor(node)
		local start_row, _, end_row, _ = node:range()
		return start_row <= cursor_row and cursor_row <= end_row
	end

	local block_name = "block"
	if vim.bo.filetype == "markdown" then
		block_name = "fenced_code_block"
	end

	local function find_fenced_code_block(node)
		if node:type() == block_name and node_contains_cursor(node) then
			return node
		end

		for child in node:iter_children() do
			local found = find_fenced_code_block(child)
			if found then
				return found
			end
		end
	end

	local code_block = find_fenced_code_block(root)
	if code_block then
		local start_row, _, end_row, _ = code_block:range()

		-- vim.api.nvim_win_set_cursor(0, { start_row + 2, 0 })
		-- vim.cmd("normal! V")
		-- vim.api.nvim_win_set_cursor(0, { end_row-1 , 0 })
		-- vim.cmd("normal! $")
		local diagram = vim.api.nvim_buf_get_lines(0, start_row + 2, end_row - 1, false)
		local tempfile = vim.fn.tempname()
		vim.fn.writefile(diagram, tempfile)
		local lines = {}
		vim.fn.jobstart("graph-easy " .. tempfile .. " --boxart", {
			on_stdout = function(_, data, _)
				for idx, line in ipairs(data) do
					if #lines > 0 and idx == 1 and line ~= nil then
						lines[#lines] = lines[#lines] .. line
					else
						table.insert(lines, line)
					end
				end
			end,
			on_exit = function(_, _, _)
        -- padTableStrings(lines)
				open_floating(lines)
				vim.fn.delete(tempfile)
			end,
		})
	end
end

M.get_codeblock = function()
	SelectCodeFence()
end

return M
