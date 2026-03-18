local namespace_id = vim.api.nvim_create_namespace "ai_spinner"

local M = {}

local config = {
  animation = {
    enabled = true,
    type = "line",
    interval = 100,
    hl_group = "Comment",
  },
  text = {
    message = "Waiting for response",
    animate_dots = true,
  },
}

local frame_patterns = {
  line = {
    "⣽⣻⢿⡿⣟⣯⣷⣾",
    "⣾⣽⣻⢿⡿⣟⣯⣷",
    "⣷⣾⣽⣻⢿⡿⣟⣯",
    "⣯⣷⣾⣽⣻⢿⡿⣟",
    "⣟⣯⣷⣾⣽⣻⢿⡿",
    "⡿⣟⣯⣷⣾⣽⣻⢿",
    "⢿⡿⣟⣯⣷⣾⣽⣻",
    "⣻⢿⡿⣟⣯⣷⣾⣽",
  },
  dots = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
  ascii = { "|", "/", "-", "\\" },
  ramp = { "▁", "▂", "▃", "▄", "▅", "▆", "▇", "█" },
  pulse = { " ", "░", "▒", "▓", "█", "▓", "▒", "░" },
  arrow = { "→", "↘", "↓", "↙", "←", "↖", "↑", "↗" },
  bounce = { "[    ]", "[=   ]", "[==  ]", "[=== ]", "[ ===]", "[  ==]", "[   =]", "[    ]" },
  stars = { "✶", "✷", "✸", "✹", "✺", "✻", "✼", "✽", "✾", "✿", "❀" },
  moon = { "🌕", "🌖", "🌗", "🌘", "🌑", "🌒", "🌓", "🌔" },
  moon_reverse = { "🌕", "🌔", "🌓", "🌒", "🌑", "🌘", "🌗", "🌖" },
}

local dots = { ".  ", ".. ", "..." }

function M.setup(opts) config = vim.tbl_deep_extend("force", config, opts or {}) end

local Spinner = {}
Spinner.__index = Spinner

function Spinner.new(bufnr, top_line, bottom_line)
  local self = setmetatable({}, Spinner)
  self.bufnr = bufnr == 0 and vim.api.nvim_get_current_buf() or bufnr
  self.start_line = top_line
  self.end_line = bottom_line
  self.timer = nil
  self.top_extmark_id = nil
  self.bottom_extmark_id = nil
  self.frame_idx = 1
  self.is_running = false
  self.animation = frame_patterns[config.animation.type]
  self.opts = config
  return self
end

function Spinner:render_frame()
  local slow_frame_idx = self.opts.text.animate_dots and math.floor(self.frame_idx / 4) or (#dots - 1)
  local animation_frame_idx = self.opts.animation.enabled and self.frame_idx or 1
  local frame = self.animation[animation_frame_idx]

  local top_virt_text = { { "╭─ " .. frame, self.opts.animation.hl_group } }
  local bottom_virt_text = {
    {
      "╰─ " .. frame .. " [" .. self.opts.text.message .. dots[(slow_frame_idx % #dots) + 1] .. "]",
      self.opts.animation.hl_group,
    },
  }

  self.top_extmark_id = vim.api.nvim_buf_set_extmark(self.bufnr, namespace_id, self.start_line, 0, {
    id = self.top_extmark_id,
    virt_lines = { top_virt_text },
    virt_lines_above = true,
  })

  self.bottom_extmark_id = vim.api.nvim_buf_set_extmark(self.bufnr, namespace_id, self.end_line, 0, {
    id = self.bottom_extmark_id,
    virt_lines = { bottom_virt_text },
    virt_lines_above = false,
  })
end

function Spinner:start()
  self.is_running = true
  self.timer = vim.uv.new_timer()
  self.timer:start(
    0,
    self.opts.animation.interval,
    vim.schedule_wrap(function()
      if not self.is_running then return end
      if not vim.api.nvim_buf_is_valid(self.bufnr) then
        self:stop()
        return
      end

      self:render_frame()
      self.frame_idx = (self.frame_idx % #self.animation) + 1
    end)
  )
end

function Spinner:stop()
  self.is_running = false

  if self.timer then
    self.timer:stop()
    if not self.timer:is_closing() then self.timer:close() end
    self.timer = nil
  end

  if vim.api.nvim_buf_is_valid(self.bufnr) then
    vim.api.nvim_buf_clear_namespace(self.bufnr, namespace_id, 0, -1)
    self.top_extmark_id = nil
    self.bottom_extmark_id = nil
  end
end

M.Spinner = Spinner

return M
