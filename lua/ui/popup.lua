local M = {}

M.state = {
  winid = nil,
  bufnr = nil,
  result_winid = nil,
  result_bufnr = nil,
}

function M.open_result_window(lines)
  if M.state.result_winid and vim.api.nvim_win_is_valid(M.state.result_winid) then
    vim.api.nvim_win_close(M.state.result_winid, true)
  end

  local bufnr = vim.api.nvim_create_buf(false, true)
  M.state.result_bufnr = bufnr

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  vim.api.nvim_set_option_value("buftype", "nofile", { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })
  vim.api.nvim_set_option_value("modifiable", false, { buf = bufnr })

  local screen_width = vim.o.columns
  local screen_height = vim.o.lines
  local win_width = math.min(100, math.floor(screen_width * 0.8))
  local win_height = math.min(#lines + 2, math.floor(screen_height * 0.8))

  local title_text = " AI Response (q to close)"

  local win_opts = {
    relative = "editor",
    row = math.floor((screen_height - win_height) / 2),
    col = math.floor((screen_width - win_width) / 2),
    width = win_width,
    height = win_height,
    style = "minimal",
    border = "rounded",
    title = title_text,
    title_pos = "center",
  }

  local winid = vim.api.nvim_open_win(bufnr, true, win_opts)
  M.state.result_winid = winid

  vim.api.nvim_set_option_value("wrap", true, { win = winid })
  vim.api.nvim_set_option_value("linebreak", true, { win = winid })
  vim.api.nvim_set_option_value("conceallevel", 2, { win = winid }) -- Renders markdown nicely

  local keymap_opts = { buffer = bufnr, noremap = true, silent = true, desc = "Close AI Response" }
  vim.keymap.set("n", "<Leader>q", M.close_result_window, keymap_opts)
  vim.keymap.set("n", "q", M.close_result_window, keymap_opts)
end

function M.open_prompt_window(on_submit)
  if M.state.winid then M.close_prompt_window() end

  local bufnr = vim.api.nvim_create_buf(false, true)
  M.state.bufnr = bufnr

  vim.api.nvim_buf_set_name(bufnr, "AI prompt " .. bufnr)
  vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })
  vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = bufnr })
  vim.api.nvim_set_option_value("filetype", "markdown", { buf = bufnr })

  local win_opts = {
    relative = "cursor",
    row = 1,
    col = 0,
    width = 60,
    height = 8,
    style = "minimal",
    border = "rounded",
    title = " AI Prompt (:w to submit, q to cancel) ",
    title_pos = "center",
  }

  local winid = vim.api.nvim_open_win(bufnr, true, win_opts)
  M.state.winid = winid

  vim.api.nvim_set_option_value("wrap", true, { win = winid })
  vim.api.nvim_set_option_value("linebreak", true, { win = winid })

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = bufnr,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local prompt_text = table.concat(lines, "\n")
      vim.api.nvim_set_option_value("modified", false, { buf = bufnr })

      M.close_prompt_window()
      if prompt_text:match "%S" then on_submit(prompt_text) end
    end,
  })

  local keymap_opts = { buffer = bufnr, noremap = true, silent = true, desc = "Close AI Prompt" }
  vim.keymap.set("n", "<Leader>q", M.close_prompt_window, keymap_opts)
  vim.keymap.set("n", "q", M.close_prompt_window, keymap_opts)

  vim.cmd "startinsert"
end

function M.close_prompt_window()
  if M.state.bufnr and vim.api.nvim_buf_is_valid(M.state.bufnr) then
    vim.api.nvim_set_option_value("modified", false, { buf = M.state.bufnr })
  end
  if M.state.winid and vim.api.nvim_win_is_valid(M.state.winid) then vim.api.nvim_win_close(M.state.winid, true) end

  M.state.winid = nil
  M.state.bufnr = nil
end

function M.close_result_window()
  if vim.api.nvim_win_is_valid(M.state.result_winid) then vim.api.nvim_win_close(M.state.result_winid, true) end
  M.state.result_winid = nil
  M.state.result_bufnr = nil
end

return M
