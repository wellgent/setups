return {
  {
    "stevearc/conform.nvim",
    -- event = 'BufWritePre', -- uncomment for format on save
    opts = require "configs.conform",
  },

  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    config = function()
      require "configs.lspconfig"
    end,
  },

  -- test new blink
  -- { import = "nvchad.blink.lazyspec" },

  -- nvim-treesitter "main" branch. The archived "master" branch crashes on
  -- Neovim 0.12 (markdown threw `attempt to call method 'range'` on every
  -- redraw and lost highlighting). This overrides NvChad v2.5's master-API
  -- spec: it drops `require("nvim-treesitter.configs").setup()` and uses the
  -- new install() API + a FileType autocmd to start highlighting. Parsers
  -- compile with tree-sitter-cli (core Brewfile) into
  -- ~/.local/share/nvim/site/parser/.
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    build = ":TSUpdate",
    lazy = false,
    config = function()
      -- keep NvChad's base46 treesitter highlight groups
      pcall(function()
        dofile(vim.g.base46_cache .. "syntax")
        dofile(vim.g.base46_cache .. "treesitter")
      end)

      require("nvim-treesitter").install {
        "lua", "luadoc", "printf", "vim", "vimdoc",
        "html", "css", "prisma", "json",
        "markdown", "markdown_inline", "bash",
      }

      -- jsonc has no dedicated parser on the main branch; reuse the json parser
      vim.treesitter.language.register("json", "jsonc")

      -- enable treesitter highlighting per buffer (main branch is opt-in)
      vim.api.nvim_create_autocmd("FileType", {
        callback = function(ev)
          local lang = vim.treesitter.language.get_lang(vim.bo[ev.buf].filetype)
          if lang then
            pcall(vim.treesitter.start, ev.buf, lang)
          end
        end,
      })
    end,
  },

  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory" },
  },
}
