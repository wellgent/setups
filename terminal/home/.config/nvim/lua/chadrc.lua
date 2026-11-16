-- This file needs to have same structure as nvconfig.lua 
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :( 

---@type ChadrcConfig
local M = {}

M.base46 = {
	theme = "catppuccin",

	hl_override = {
		Comment = { italic = true },
		["@comment"] = { italic = true },
		["@keyword"] = { italic = true },
		["@function"] = { italic = true },
		["@type"] = { italic = true },
	},
}

M.ui = {
	statusline = {
		modules = {
			file = function()
				local x = require("nvchad.stl.utils").file()
				local name = " " .. x[2] .. " "
				local modified = vim.bo[vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)].modified
				return "%#St_file# " .. x[1] .. name .. (modified and "%#St_gitIcons# " or "") .. "%#St_file_sep#"
			end,
		},
	},
}

return M
