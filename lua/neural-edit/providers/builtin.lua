local builtin_providers = {
	grok = {
		default_model = "grok-4-1-fast",
		get_config = function(model)
			local key = vim.env.GROK_API_KEY
			if not key or key == "" then
				return nil
			end
			return { url = "https://api.x.ai/v1/chat/completions", api_key = key, model = model }
		end,

		build_request = function(config, messages)
			local body = {
				model = config.model,
				messages = messages,
				stream = false,
				temperature = 0,
			}
			local headers = {
				"-H",
				"Content-Type: application/json",
				"-H",
				"Authorization: Bearer " .. config.api_key,
			}
			return body, headers
		end,

		parse_response = function(response)
			if response.error then
				return { status = "error", err = response.error.message }
			end

			local choice = response.choices and response.choices[1]
			if not choice then
				return { status = "error", err = "Missing choices in response" }
			end

			if choice.message.refusal and choice.message.refusal ~= vim.NIL then
				return { status = "refusal", text = choice.message.refusal }
			end

			return { status = choice.finish_reason or "stop", text = choice.message.content or "" }
		end,
	},

	anthropic = {
		get_config = function(model)
			local key = vim.env.ANTHROPIC_API_KEY
			if not key or key == "" then
				return nil
			end
			return { url = "https://api.anthropic.com/v1/messages", api_key = key, model = model }
		end,
		build_request = function(config, messages)
			local body = { model = config.model, max_tokens = 4096, messages = messages, temperature = 0 }
			local headers = {
				"-H",
				"Content-Type: application/json",
				"-H",
				"x-api-key: " .. config.api_key,
				"-H",
				"anthropic-version: 2023-06-01",
			}
			return body, headers
		end,
		parse_response = function(response)
			if response.type == "error" then
				return { status = "error", err = response.error.message }
			end

			local content = response.content and response.content[1]
			if not content then
				return { status = "error", err = "Missing content in response" }
			end

			return { status = response.stop_reason or "stop", text = content.text or "" }
		end,
	},

	gemini = {
		get_config = function(model)
			local key = vim.env.GEMINI_API_KEY
			if not key or key == "" then
				return nil
			end
			local url =
				string.format("https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent", model, key)
			return { url = url, api_key = key, model = model }
		end,

		build_request = function(config, messages)
			local gemini_contents = {}
			for _, msg in ipairs(messages) do
				table.insert(gemini_contents, {
					role = msg.role == "assistant" and "model" or "user",
					parts = { { text = msg.content } },
				})
			end
			local body = { contents = gemini_contents, generationConfig = { temperature = 0 } }
			local headers = {
				"-H",
				"x-goog-api-key: " .. config.api_key,
				"-H",
				"Content-Type: application/json",
			}
			return body, headers
		end,

		parse_response = function(response)
			if response.error then
				return { status = "error", err = response.error.message }
			end

			local candidate = response.candidates and response.candidates[1]
			if not candidate then
				return { status = "error", err = "Missing candidates in response" }
			end

			local text = candidate.content and candidate.content.parts and candidate.content.parts[1].text
			return { status = candidate.finishReason or "stop", text = text or "" }
		end,
	},

	bedrock = {
		get_config = function(model)
			local access_key = vim.env.AWS_ACCESS_KEY_ID
			local secret_key = vim.env.AWS_SECRET_ACCESS_KEY
			local region = vim.env.AWS_REGION or vim.env.AWS_DEFAULT_REGION or "us-east-1"

			if not access_key or not secret_key then
				return nil
			end

			local url = string.format("https://bedrock-runtime.%s.amazonaws.com/model/%s/converse", region, model)

			return {
				url = url,
				access_key = access_key,
				secret_key = secret_key,
				region = region,
				session_token = vim.env.AWS_SESSION_TOKEN,
				model = model,
			}
		end,

		build_request = function(config, messages)
			local bedrock_messages = {}
			local system_prompts = {}

			for _, msg in ipairs(messages) do
				if msg.role == "system" then
					table.insert(system_prompts, { text = msg.content })
				else
					table.insert(bedrock_messages, {
						role = msg.role == "assistant" and "assistant" or "user",
						content = { { text = msg.content } },
					})
				end
			end

			local body = {
				messages = bedrock_messages,
				inferenceConfig = {
					maxTokens = 4096,
					temperature = 0,
				},
			}
			if #system_prompts > 0 then
				body.system = system_prompts
			end

			local headers = {
				"-H",
				"Content-Type: application/json",
				"--aws-sigv4",
				"aws:amz:" .. config.region .. ":bedrock",
				"--user",
				config.access_key .. ":" .. config.secret_key,
			}

			if config.session_token and config.session_token ~= "" then
				table.insert(headers, "-H")
				table.insert(headers, "x-amz-security-token: " .. config.session_token)
			end

			return body, headers
		end,

		parse_response = function(response)
			if response.message and response.message == "Missing Authentication Token" then
				return { status = "error", err = "AWS Auth failed. Check credentials/region." }
			end

			if not response.output and response.message then
				return { status = "error", err = "Bedrock Error: " .. response.message }
			end

			local message = response.output and response.output.message
			if not message or not message.content then
				return { status = "error", err = "Missing message content in Bedrock response" }
			end

			local text = message.content[1] and message.content[1].text or ""
			return { status = response.stopReason or "stop", text = text }
		end,
	},
}

return builtin_providers
