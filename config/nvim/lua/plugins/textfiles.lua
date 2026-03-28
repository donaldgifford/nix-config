-- Textfiles theme (WIP) - disabled for now, using default tokyo night
-- Uncomment to enable custom colors
return {
  --[[
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night",
      transparent = false,
      styles = {
        comments = { italic = true },
        keywords = { italic = true },
      },
      on_colors = function(colors)
        -- Core palette from blog
        colors.bg = "#16161e"
        colors.bg_dark = "#13131a"
        colors.fg = "#b4b4b4"
        colors.fg_dark = "#6b6b6b"
        colors.fg_gutter = "#6b6b6b"
        colors.comment = "#6b6b6b"

        -- Accent colors
        colors.purple = "#9d7cd8"
        colors.blue = "#7aa2f7"
        colors.cyan = "#7dcfff"
        colors.teal = "#73daca"
        colors.green = "#9ece6a"
        colors.yellow = "#e0af68"
        colors.orange = "#ff9e64"
        colors.red = "#f7768e"
      end,
      on_highlights = function(hl, colors)
        -- Adjusted to avoid green/teal clash
        hl.String = { fg = colors.green }
        hl.Function = { fg = colors.blue }
        hl.Keyword = { fg = colors.purple, italic = true }
        hl.Type = { fg = colors.blue }        -- was cyan, now blue
        hl.Number = { fg = colors.orange }
        hl.Constant = { fg = colors.orange }
        hl.Error = { fg = colors.red }
        hl.Warning = { fg = colors.yellow }
        hl.Parameter = { fg = colors.orange } -- function params
        hl["@parameter"] = { fg = colors.orange }
        hl["@variable.parameter"] = { fg = colors.orange }
      end,
    },
  },
  --]]
}
