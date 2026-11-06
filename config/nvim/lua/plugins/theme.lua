local omarchy_theme = (vim.env.XDG_STATE_HOME or vim.fn.expand("~/.local/state"))
	.. "/omarchy/current/theme/neovim.lua"
if vim.fn.filereadable(omarchy_theme) == 1 then
	return dofile(omarchy_theme)
end

return {
	{
		"folke/tokyonight.nvim",
		priority = 1000,
	},
	{
		"LazyVim/LazyVim",
		opts = {
			colorscheme = "tokyonight-night",
		},
	},
}
