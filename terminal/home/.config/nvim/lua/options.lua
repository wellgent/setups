require "nvchad.options"

-- Use OSC 52 only over SSH, where no native clipboard tool is available.
-- Locally on macOS, let nvim auto-detect pbcopy/pbpaste - Warp does not honor OSC 52,
-- so forcing it unconditionally silently breaks local yanks.
-- Paste from OSC 52 is disabled (unreliable - terminals block it);
-- use terminal paste (Cmd+V) instead.
if vim.env.SSH_TTY then
  vim.g.clipboard = {
    name = 'OSC 52',
    copy = {
      ['+'] = require('vim.ui.clipboard.osc52').copy('+'),
      ['*'] = require('vim.ui.clipboard.osc52').copy('*'),
    },
    paste = {
      ['+'] = function() return { vim.fn.getreg('', 1, true), vim.fn.getregtype('') } end,
      ['*'] = function() return { vim.fn.getreg('', 1, true), vim.fn.getregtype('') } end,
    },
  }
end

-- winbar: the file's relative path at the top of each window
vim.opt.winbar = "%f"
vim.opt.mousescroll = "ver:1"
vim.opt.autoread = true
vim.opt.linebreak = true

-- Auto-reload files changed on disk
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorMoved" }, {
  pattern = "*",
  command = "if mode() != 'c' | checktime | endif",
})

-- Treat all .json as jsonc - many real-world configs (VS Code, Cursor, Zed,
-- tsconfig, etc.) allow comments and trailing commas despite the .json extension.
vim.filetype.add({
  extension = {
    json = "jsonc",
  },
})
