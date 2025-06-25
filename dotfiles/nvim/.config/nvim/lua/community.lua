-- AstroCommunity: import any community modules here
-- We import this file in `lazy_setup.lua` before the `plugins/` folder.
-- This guarantees that the specs are processed before any user plugins.

---@type LazySpec
return {
  "AstroNvim/astrocommunity",
  { import = "astrocommunity.pack.lua" },
  { import = "astrocommunity.completion.copilot-vim" },
  { import = "astrocommunity.recipes.ai" },
  { import = "astrocommunity.pack.python" },
  { import = "astrocommunity.recipes.disable-tabline" },
}
