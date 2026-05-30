return {
  "folke/snacks.nvim",
  opts = function(_, opts)
    -- Increase the timeout duration to 10000ms (10 seconds)
    -- You can adjust the 10000 to whatever time length you prefer
    opts.notifier = opts.notifier or {}
    opts.notifier.timeout = 10000
  end,
}
