return {
  "lukas-reineke/headlines.nvim",
  after = "nvim-treesitter",
  config = function () require("headlines").setup() end,
}
