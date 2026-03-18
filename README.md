# 🧠 neural-edit.nvim

A Neovim plugin for LLM-assisted code generation, refactoring, and explanation. `neural-edit.nvim` executes operations directly within the buffer.

The plugin is customizable and integrates with multiple LLM providers, including **Grok**, **Gemini**, **Anthropic**, and **AWS Bedrock**.

## ✨ Features

* **In-Place Code Generation:** Insert generated code directly into the current buffer at the cursor position based on a provided prompt.
* **Code Refactoring:** Select a block of code, provide modification instructions, and replace the selection with the generated output.
* **Code Explanation:** Select code snippets to receive explanations, which are rendered in a floating window.
* **Provider Agnostic:** Includes built-in support for major LLM APIs, alongside an API for integrating custom or local endpoints.
* **Asynchronous Execution:** Non-blocking API requests with a UI status indicator ensure the editor remains responsive during generation.

---

## 📦 Installation

Install `neural-edit.nvim` using your preferred package manager. Here is an example using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "Berazold/neural-edit.nvim" ,
  config = function()
    require("neural-edit").setup({
      default_provider = "grok",
      spinner = {
        animation = {
          enabled = true,
          type = "line",
        },
      },
    })
  end
}
```

---

## 🚀 Usage & Keymaps

The plugin exposes three main functions. You can bind these to your preferred keys. 

Here is an example setup using native Neovim keymaps:

```lua
-- Normal Mode
vim.keymap.set("n", "<Leader>ac", function() require("neural-edit").generate_code() end, { desc = "AI: In-place code generation" })

-- Visual Mode
vim.keymap.set("v", "<Leader>ar", function() require("neural-edit").refactor_selection() end, { desc = "AI: Refactor visual selection" })
vim.keymap.set("v", "<Leader>aa", function() require("neural-edit").explain_code() end, { desc = "AI: Explain visual selection" })
```

---

### 💻 User Commands
If you prefer using Neovim's command line, `neural-edit.nvim` registers the following user commands by default:

* `:NeuralGenerate` - Opens the prompt window for in-place code generation.
* `:'<,'>NeuralRefactor` - Refactors the visually selected text.
* `:'<,'>NeuralExplain` - Explains the visually selected code.

**Under the hood, they are mapped like this:**
```lua
vim.api.nvim_create_user_command("NeuralGenerate", function()
    require("neural-edit").generate_code()
end, {
    desc = "Generate code using Neural Edit",
})

vim.api.nvim_create_user_command("NeuralRefactor", function()
    require("neural-edit").refactor_selection()
end, {
    range = true,
    desc = "Refactor selected text in-place using Neural Edit",
})

vim.api.nvim_create_user_command("NeuralExplain", function()
    require("neural-edit").explain_code()
end, {
    range = true,
    desc = "Explain selected code using Neural Edit",
})
```

---

## ⚙️ Advanced Configuration

Customize providers via `setup({ providers = { ... } })`. Each provider defines three core functions::

- `get_config(model)` — return `{ url, api_key, model }`.
- `build_request(config, messages)` — return `body, headers`.
- `parse_response(response)` — return `{ status, text?, err? }`.

You can easily override existing API implementations or define completely custom providers. `neural-edit.nvim` gives you full control over the request lifecycle: how configuration is gathered, how the request body is built, and how the response is parsed.

Here is an example of customizing the **Grok** provider:

```lua
require("neural-edit").setup {
  default_provider = "grok",
  providers = {
    grok = {
      default_model = "grok-4-1-fast",
      get_config = function(model)
        local key = vim.env.GROK_API_KEY
        if not key or key == "" then
          vim.notify("GROK_API_KEY environment variable is not set", vim.log.levels.ERROR)
          return nil
        end
        return { 
          url = "https://api.x.ai/v1/chat/completions", 
          api_key = key, 
          model = model 
        }
      end,

      build_request = function(config, messages)
        local body = {
          model = config.model,
          messages = messages,
          stream = false,
          temperature = 0,
        }
        local headers = {
          "-H", "Content-Type: application/json",
          "-H", "Authorization: Bearer " .. config.api_key,
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
  }
}
```
