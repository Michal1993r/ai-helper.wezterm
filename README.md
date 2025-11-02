# AI Helper for WezTerm

I really liked Warp but due to my company's AI policy I had to move to something else. WezTerm is 90% of what I need and I decided to build the remaining 10% myself.
And so here it is: a very simple WezTerm plugin that lets you ask an AI for CLI help using multiple providers: LM Studio (local), Google Gemini (cloud), Ollama (local/remote), or any OpenAPI-compatible service.

## Setup

### Option 1: Local with LM Studio (default)
1. Make sure you have [LM Studio](https://lmstudio.ai/) installed with CLI tools
2. Find your LM Studio CLI path (usually `/Applications/LM Studio.app/Contents/Resources/lms` on macOS)
3. Add to your `wezterm.lua`:

```lua
local ai_helper = require("path.to.plugin")
local config = wezterm.config_builder()
ai_helper.apply_to_config(config, {
    lms_path = "/path/to/lms", -- type = "local" is the default
})
```

### Option 2: Cloud with Google Gemini
1. Install the required Lua JSON library: `luarocks install dkjson`
2. Get a Google API key from [Google AI Studio](https://aistudio.google.com/app/apikey)
3. Add to your `wezterm.lua`:

```lua
local ai_helper = require("path.to.plugin")
local config = wezterm.config_builder()
ai_helper.apply_to_config(config, {
    type = "google",
    api_key = "your-google-api-key",
})
```

### Option 3: Ollama (Local or Remote)
1. Install [Ollama](https://ollama.ai/) and have it running
2. For local Ollama:

```lua
local ai_helper = require("path.to.plugin")
local config = wezterm.config_builder()
ai_helper.apply_to_config(config, {
    type = "ollama",
    ollama_path = "ollama", -- or full path like "/usr/local/bin/ollama"
    model = "llama2", -- or any model you have installed
})
```

3. For remote Ollama, set the `OLLAMA_HOST` environment variable or configure it in your system.

### Option 4: OpenAPI-compatible HTTP Service
Works with OpenAI, Anthropic, local servers, or any service using the OpenAI API format:

```lua
local ai_helper = require("path.to.plugin")
local config = wezterm.config_builder()
ai_helper.apply_to_config(config, {
    type = "http",
    api_url = "https://api.openai.com/v1/chat/completions", -- or your service URL
    api_key = "your-api-key", -- if required
    model = "gpt-4", -- model name
    headers = { -- optional custom headers
        ["X-Custom-Header"] = "value"
    }
})
```

## Usage

Press `Cmd+I` (default keybinding), type your question, get help.

Example: "find large files" → AI explains and gives you the command.

## Configuration

All configuration options with their defaults:

```lua
ai_helper.apply_to_config(config, {
    -- Provider type: "local", "google", "ollama", or "http" (default: "local")
    type = "local",
    
    -- For local LM Studio: Path to LM Studio CLI binary (required when type = "local")
    lms_path = "/path/to/lms",
    
    -- For Google Gemini: API key (required when type = "google")
    api_key = "your-google-api-key",
    
    -- For Ollama: Path to ollama binary (required when type = "ollama")
    ollama_path = "ollama", -- or "/usr/local/bin/ollama"
    
    -- For HTTP: API endpoint URL (required when type = "http")
    api_url = "https://api.openai.com/v1/chat/completions",
    
    -- For HTTP: Optional custom headers
    headers = {
        ["X-Custom-Header"] = "value"
    },
    
    -- Path to luarocks binary (default: "/opt/homebrew/bin/luarocks")
    luarocks_path = "/usr/local/bin/luarocks",
    
    -- AI model to use (default: "google/gemma-3-4b")
    model = "your-model-name",
    
    -- Keybinding configuration (default: Cmd+I)
    keybinding = { 
        key = "i", 
        mods = "SUPER" 
    },

    -- this keybinding will share the pane history with the AI
    keybinding_with_pane = { 
        key = "I", 
        mods = "SUPER" 
    },
    
    -- System prompt for the AI (default: CLI/macOS specialist prompt)
    system_prompt = "you are an assistant that specializes in CLI and macOS commands. "
        .. "you will be brief and to the point, if asked for commands print them in a way that's easy to copy, "
        .. "otherwise just answer the question. concatenate commands with && or || for ease of use. ",
    
    -- Request timeout in seconds (default: 30)
    timeout = 30,
    
    -- Show loading indicator while AI is thinking (default: true)
    show_loading = true,

    -- Numer of history lines shared with the AI
    share_n_lines = 150
})
```

### Configuration Details

- **`type`**: Choose between "local" (LM Studio), "google" (Gemini), "ollama" (Ollama), or "http" (OpenAPI-compatible)
- **`lms_path`** (required for local): Full path to the LM Studio CLI binary
- **`api_key`** (required for google/http): API key for the service
- **`ollama_path`** (required for ollama): Path to the ollama binary (e.g., "ollama" or "/usr/local/bin/ollama")
- **`api_url`** (required for http): Full URL to the API endpoint (e.g., "https://api.openai.com/v1/chat/completions")
- **`headers`** (optional for http): Custom HTTP headers as key-value pairs
- **`luarocks_path`** (optional for some types): Path to the luarocks binary for Lua dependencies (default: "/opt/homebrew/bin/luarocks"). Required for Google Gemini provider which needs the `dkjson` library.
- **`model`**: The AI model name
- **`keybinding`**: Key combination to trigger the AI helper
  - `key`: The key to press
  - `mods`: Modifier keys (e.g., "SUPER", "CTRL", "ALT", "SHIFT")
- **`keybinding_with_pane`**: Same as keybinding, but it will share the pane history with the AI.
  You can use this for improved context knowledge and for revising the suggested commands
- **`system_prompt`**: Instructions for the AI on how to behave and format responses
- **`timeout`**: How long to wait for AI response before timing out
- **`show_loading`**: Whether to display "🤖 AI is thinking..." while waiting
- **`share_n_lines`**: The maximum number of lines shared with the AI; by default, it is the view pane

### Example Output

When you ask "what's my public IP?", you might see:

```
🤖 AI is thinking...
💬 Your public IP address is
➜  ai-helper.wezterm git:(master) ✗ curl ifconfig.me
```

The output consists of:
1. **Loading indicator**: Shows while the AI processes your request
2. **AI message**: Plain text explanation or context
3. **Command**: Ready-to-execute command that appears in your terminal

That's it.
