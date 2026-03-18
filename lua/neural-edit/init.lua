local M = {}

local provider = require("neural-edit.providers.request")
local builtin_providers = require("neural-edit.providers.builtin")

local selection = require("neural-edit.utils.selection")
local prompts = require("neural-edit.utils.prompts")

local popup = require("neural-edit.ui.popup")
local Spinner = require("neural-edit.ui.spinner").Spinner

local config = require("neural-edit.config")

local M = {}

function M.setup(opts)
  opts = opts or {}

  config.providers = vim.tbl_deep_extend("force", builtin_providers, opts.providers or {})
  if opts.default_provider then config.default_provider = opts.default_provider end

  require("neural-edit.ui.spinner").setup(opts.spinner)
end

local function extract_code_from_response(text)
  if not text or text == "" then return "" end

  local code_block = text:match("```%w*\n(.-)\n```")

  if code_block then
    return code_block
  else
    return text
  end
end

local function validate_response(response)
  if response.err ~= nil then
    vim.notify("Error: " .. response.err, vim.log.levels.ERROR)
    return false
  end

  if response.status == "refusal" then
    vim.notify("AI refused to answer: " .. response.text, vim.log.levels.WARN)
    return false
  end

  return true
end

function M.refactor_selection()
  local selected_text = selection.get_visual_selection()

  local bufnr = vim.api.nvim_get_current_buf()
  local spinner = Spinner.new(bufnr, selected_text.start_line, selected_text.end_line)

  popup.open_prompt_window(function(prompt)
    local payload = { { role = "user", content = prompts.prepare_refactor_prompt(prompt, selected_text.text) } }
    spinner:start()

    provider.send_request(payload, function(response)
      vim.schedule(function()
        spinner:stop()
        if validate_response(response) then
          local response_lines = vim.split(extract_code_from_response(response.text), "\n")
          if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_set_lines(
              bufnr,
              selected_text.start_line,
              selected_text.end_line + 1,
              false,
              response_lines
            )
          else
            vim.notify("Buffer changed; aborting insert", vim.log.levels.WARN)
          end
        end
      end)
    end)
  end)
end

function M.generate_code()
  local cursor_pos = vim.api.nvim_win_get_cursor(0)
  local cursor_row = cursor_pos[1] - 1
  local bufnr = vim.api.nvim_get_current_buf()
  local spinner = Spinner.new(bufnr, cursor_row, cursor_row)

  popup.open_prompt_window(function(prompt)
    local payload = { { role = "user", content = prompts.prepare_codegen_prompt(prompt) } }
    spinner:start()

    if not prompt or prompt:match("^%s*$") then
      vim.notify("Error: an empty prompt was provided", vim.log.levels.ERROR)
      return
    end

    provider.send_request(payload, function(response)
      vim.schedule(function()
        spinner:stop()

        if validate_response(response) then
          local response_lines = vim.split(extract_code_from_response(response.text), "\n")
          if vim.api.nvim_buf_is_valid(bufnr) then
            vim.api.nvim_buf_set_lines(bufnr, cursor_row + 1, cursor_row + 1, false, response_lines)
          else
            vim.notify("Buffer changed; aborting insert", vim.log.levels.WARN)
          end
        end
      end)
    end)
  end)
end

function M.explain_code()
  local selected_text = selection.get_visual_selection()

  local bufnr = vim.api.nvim_get_current_buf()
  local spinner = Spinner.new(bufnr, selected_text.start_line, selected_text.end_line)

  popup.open_prompt_window(function(prompt)
    local payload = { { role = "user", content = prompts.prepare_explain_prompt(prompt, selected_text.text) } }
    spinner:start()

    provider.send_request(payload, function(response)
      vim.schedule(function()
        spinner:stop()
        if validate_response(response) then
          local response_lines = vim.split(response.text or "", "\n")
          popup.open_result_window(response_lines)
        end
      end)
    end)
  end)
end

return M
