local M = {}

function M.get_visual_selection()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "x", false)

  local _, csrow, cscol, _ = unpack(vim.fn.getpos "'<")
  local _, cerow, cecol, _ = unpack(vim.fn.getpos "'>")

  local lines = vim.fn.getline(csrow, cerow)
  if type(lines) ~= "table" or #lines == 0 then return nil end

  lines[#lines] = string.sub(lines[#lines], 1, cecol)
  lines[1] = string.sub(lines[1], cscol)

  local text = table.concat(lines, "\n")

  return {
    text = text,
    start_line = csrow - 1,
    end_line = cerow - 1,
  }
end

return M
