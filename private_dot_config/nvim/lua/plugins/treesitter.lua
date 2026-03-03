return {
	"nvim-treesitter/nvim-treesitter",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter").install({
			-- core
			"lua",
			"rust",
			"javascript",
			"typescript",
			"tsx",
			"python",
			"solidity",

			-- common project files
			"json",
			"yaml",
			"bash",
			"dockerfile",
			"html",
			"css",
			"markdown",
			"markdown_inline",
		})
	end,
}
