local providers = require("neural-edit.providers.builtin")
local config = require("neural-edit.config")

local M = {}

function M.send_request(messages, callback, opts)
  opts = opts or {}

  local provider_name = opts.provider or config.default_provider
  local provider = config.providers[provider_name]
  if not provider then
    callback({ err = "Unknown provider: " .. tostring(provider_name), status = "error" })
    return
  end

  local model = opts.model or provider.default_model

  local config = provider.get_config(model)
  if not config then
    callback({ err = "Configuration/API key missing for provider: " .. provider_name, status = "error" })
    return
  end

  local request_body, headers = provider.build_request(config, messages)

  local ok, json_body = pcall(vim.fn.json_encode, request_body)
  if not ok then
    callback({ err = "Error forming JSON request", status = "error" })
    return
  end

  local cmd = {
    "curl",
    "-s",
    config.url,
    "-d",
    json_body,
  }
  for _, header_part in ipairs(headers) do
    table.insert(cmd, header_part)
  end

  vim.system(cmd, { text = true }, function(obj)
    if obj.code ~= 0 then
      callback({
        err = "Network error (curl): " .. (obj.stderr or "Unknown error"),
        status = "error",
      })
      return
    end

    local decode_ok, response = pcall(vim.json.decode, obj.stdout)
    if not decode_ok then
      callback({ err = "Error parsing API response: " .. tostring(response), status = "error" })
      return
    end

    if response.error then
      callback({ err = "API Error: " .. (response.error.message or "Unknown"), status = "error" })
      return
    end

    local result = provider.parse_response(response)
    callback(result)
  end)
end

return M
