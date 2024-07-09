local M = {}
local u = require("tinygit.shared.utils")
--------------------------------------------------------------------------------

---@class (exact) Hunk
---@field path string
---@field lnum number
---@field displayLong string
---@field displayShort string
---@field patch string

--------------------------------------------------------------------------------

---@nodiscard
---@return boolean
local function hasNoUnstagedChanges()
	local noChanges = vim.system({ "git", "diff", "--quiet" }):wait().code == 0
	if noChanges then u.notify("There are no unstaged changes.", "warn") end
	return noChanges
end

---@nodiscard
---@return Hunk[]?
local function getHunks()
	-- CAVEAT for some reason, context=0 results in patches that are not valid.
	-- Using context=1 seems to work, but has the downside of merging hunks that
	-- are only two line apart. Test it: here 0 fails, but 1 works:
	-- `git -c diff.context=0 diff . | git apply --cached --verbose -`
	local contextSize = require("tinygit.config").config.staging.contextSize
	if contextSize < 1 then contextSize = 0 end

	local out =
		vim.system({ "git", "-c", "diff.context=" .. contextSize, "diff", "--diff-filter=M" }):wait()
	if u.nonZeroExit(out) then return end

	local gitroot = u.syncShellCmd { "git", "rev-parse", "--show-toplevel" }

	local changesPerFile = vim.split(out.stdout, "diff --git a/", { plain = true })
	table.remove(changesPerFile, 1) -- first item is always an empty string

	-- Loop through each file, and then through each hunk of that file. Construct
	-- flattened list of hunks, each with their own diff header, so they work as
	-- independent patches. Those patches in turn are needed for `git apply`
	-- stage only part of a file.
	---@type Hunk[]
	local hunks = {}
	for _, file in ipairs(changesPerFile) do
		-- severe diff header
		file = "diff --git a/" .. file -- re-add, since needed to make patches valid
		local diffLines = vim.split(file, "\n")
		local relPath = diffLines[3]:sub(7)
		local absPath = gitroot .. "/" .. relPath
		local diffHeader = table.concat(vim.list_slice(diffLines, 1, 4), "\n")

		-- split output into hunks
		local changesInFile = vim.list_slice(diffLines, 5)
		local hunksInFile = {}
		for _, line in ipairs(changesInFile) do
			if vim.startswith(line, "@@") then
				table.insert(hunksInFile, line)
			else
				hunksInFile[#hunksInFile] = hunksInFile[#hunksInFile] .. "\n" .. line
			end
		end

		-- loop hunks
		for _, hunk in ipairs(hunksInFile) do
			-- meaning of @@-line: https://www.gnu.org/software/diffutils/manual/html_node/Detailed-Unified.html
			local _, removed, newLnum, added = hunk:match("^@@ %-(%d+),?(%d*) %+(%d+),?(%d*) @@")
			removed = removed == "" and 1 or tonumber(removed) - 2 * contextSize
			added = added == "" and 1 or tonumber(added) - 2 * contextSize
			local stat = ("(+%s -%s)"):format(added, removed)
			if removed == 0 then stat = ("(+%s)"):format(added) end
			if added == 0 then stat = ("(-%s)"):format(removed) end

			local patch = diffHeader .. "\n" .. hunk .. "\n" -- needs trailing newline for valid patch
			local name = vim.fs.basename(relPath)

			---@type Hunk
			local hunkObj = {
				path = absPath,
				lnum = newLnum,
				displayLong = ("%s %s"):format(relPath, stat),
				displayShort = ("%s:%s %s"):format(name, newLnum, stat),
				patch = patch,
			}
			table.insert(hunks, hunkObj)
		end
	end
	return hunks
end

---@param hunk Hunk
local function stageHunk(hunk)
	-- use `git apply` to stage only part of a file
	-- https://stackoverflow.com/a/66618356/22114136
	vim.system(
		{ "git", "apply", "--apply", "--cached", "--verbose", "-" },
		{ stdin = hunk.patch },
		function(out)
			if u.nonZeroExit(out) then return end
			u.notify(hunk.displayShort)
		end
	)
end

---@param hunks Hunk[]
local function telescopePickHunk(hunks)
	local pickers = require("telescope.pickers")
	local telescopeConf = require("telescope.config").values
	local actionState = require("telescope.actions.state")
	local actions = require("telescope.actions")
	local finders = require("telescope.finders")
	local previewers = require("telescope.previewers")

	local opts = require("tinygit.config").config.staging

	---@param _hunks Hunk[]
	local function newFinder(_hunks)
		return finders.new_table {
			results = _hunks,
			-- search for filenames, but also changed line contents
			entry_maker = function(hunk)
				local changeLines = vim.iter(vim.split(hunk.patch, "\n"))
					:filter(function(line) return line:match("^[+-]") end)
					:join("\n")
				local matcher = hunk.path .. "\n" .. changeLines
				return {
					value = hunk,
					display = hunk.displayShort,
					ordinal = matcher,
				}
			end,
		}
	end

	-- DOCS https://github.com/nvim-telescope/telescope.nvim/blob/master/developers.md
	pickers
		.new({}, {
			prompt_title = "Git Hunks",
			sorter = telescopeConf.generic_sorter {},

			finder = newFinder(hunks),

			-- DOCS `:help telescope.previewers`
			previewer = previewers.new_buffer_previewer {
				define_preview = function(self, entry)
					local bufnr = self.state.bufnr
					local hunk = entry.value
					local display = vim.list_slice(vim.split(hunk.patch, "\n"), 5)
					vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, display)
					vim.bo[bufnr].filetype = "diff"
				end,
				dyn_title = function(_, entry)
					local hunk = entry.value
					return hunk.displayLong
				end,
			},

			attach_mappings = function(prompt_bufnr, map)
				map({ "n", "i" }, opts.keymaps.gotoHunk, function()
					local hunk = actionState.get_selected_entry().value
					actions.close(prompt_bufnr)
					vim.cmd(("edit +%d %s"):format(hunk.lnum, hunk.path))
				end, { desc = "Goto Hunk" })

				map({ "n", "i" }, opts.keymaps.stageHunk, function()
					local entry = actionState.get_selected_entry()
					local hunk = entry.value
					stageHunk(hunk)
					table.remove(hunks, entry.index)

					if #hunks > 0 then
						local picker = actionState.get_current_picker(prompt_bufnr)
						picker:refresh(newFinder(hunks), { reset_prompt = false })
					else
						actions.close(prompt_bufnr)
					end
				end, { desc = "Stage Hunk" })

				return true -- keep default mappings
			end,
		})
		:find()
end

--------------------------------------------------------------------------------

function M.interactiveStaging()
	vim.cmd("silent update")
	if u.notInGitRepo() or hasNoUnstagedChanges() then return end

	local hunks = getHunks()
	if not hunks then return end

	telescopePickHunk(hunks)
end
--------------------------------------------------------------------------------
return M
