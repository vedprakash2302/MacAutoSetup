return {
  "xiyaowong/transparent.nvim",
  name = "transparent",
  lazy = false,
  config = function()
    require("transparent").setup({
      -- table: additional groups that should be cleared
      extra_groups = {
        "NormalFloat",
      },
      -- table: groups you don't want to clear
      exclude_groups = { "CursorLine" },
      -- function: code to be executed after highlight groups are cleared
      -- Also the user event "TransparentClear" will be triggered
      on_clear = function() end,
    })
    require("transparent").clear_prefix("lualine")
  end,
}
