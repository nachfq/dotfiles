return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"nvim-tree/nvim-web-devicons", -- optional, but recommended
	},
	lazy = false, -- neo-tree will lazily load itself
	config = function()
		require("neo-tree").setup({
			filesystem = {
				filtered_items = {
					visible = true, -- show hidden items in the tree
					hide_dotfiles = false,
					hide_gitignored = false,
				},
			},
		})
		vim.keymap.set("n", "<leader>n", ":Neotree filesystem reveal right<CR>")
	end,
}
