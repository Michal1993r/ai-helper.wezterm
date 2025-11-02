local wezterm = require("wezterm")
local act = wezterm.action

local function findPluginPackagePath(search_pattern)
    local separator = package.config:sub(1, 1) == "\\" and "\\" or "/"
    for _, v in ipairs(wezterm.plugin.list()) do
        -- Match by component name or URL containing the search pattern
        if (v.component and v.component:find(search_pattern, 1, true)) or
            (v.url and v.url:find(search_pattern, 1, true)) then
            return v.plugin_dir .. separator .. "plugin" .. separator .. "?.lua"
        end
    end
    return nil
end

local plugin_path = findPluginPackagePath("ai-helpersDswezterm")
if plugin_path then
    package.path = package.path .. ";" .. plugin_path
else
    wezterm.log_warn("AI Helper: Could not find plugin directory, some modules may not load correctly")
end

-- Setup luarocks path function that can be called with config
local function setup_luarocks(config)
    local luarocks_bin = config.luarocks_path or "/opt/homebrew/bin/luarocks"
    local io = require("io")
    local ok, handle = pcall(io.popen, luarocks_bin .. " path --bin 2>&1")
    if ok and handle then
        local result = handle:read("*a")
        local exit_code = handle:close()

        if exit_code then
            local luarocks_path = result:match("LUA_PATH=(.-)\n")
            if luarocks_path then
                package.path = package.path .. ";" .. luarocks_path
                wezterm.log_info("AI Helper: luarocks path added successfully")
            end
        else
            wezterm.log_info("AI Helper: luarocks path command failed (luarocks may not be installed)")
        end
    else
        wezterm.log_info("AI Helper: luarocks not found at " ..
        luarocks_bin .. " (continuing without luarocks dependencies)")
    end
end

-- Default configuration
local default_config = {
    model = "google/gemma-3-4b",
    keybinding = {
        key = "i",
        mods = "SUPER",
    },
    system_prompt = "you are an assistant that specializes in CLI and macOS commands. "
        .. "you will be brief and to the point, if asked for commands print them in a way that's easy to copy, "
        .. "otherwise just answer the question. concatenate commands with && or || for ease of use. "
        .. "structure your output in a JSON schema with 2 fields: message and command",
    timeout = 30, -- seconds
    show_loading = true,
    type = "local",
    api_key = nil,                                -- Only used for Google API
    luarocks_path = "/opt/homebrew/bin/luarocks", -- Default path to luarocks binary
}

local function get_provider(config)
    if config.type == "google" then
        return require("generators.google")
    elseif config.type == "local" then
        return require("generators.local_lm_studio")
    elseif config.type == "ollama" then
        return require("generators.ollama")
    elseif config.type == "http" then
        return require("generators.http")
    else
        wezterm.log_error("AI Helper: Unsupported type: ", config.type)
        return nil
    end
end

-- Merge user config with defaults
local function merge_config(user_config)
    local config = {}
    for k, v in pairs(default_config) do
        config[k] = v
    end
    if user_config then
        for k, v in pairs(user_config) do
            config[k] = v
            if k == "system_prompt" then
                config[k] = v .. " structure your output in a JSON schema with 2 fields: message and command"
            end
        end
    end
    return config
end

-- Show loading indicator
local function show_loading(pane, show)
    if show then
        pane:inject_output("\r\n🤖 AI is thinking...")
    end
end

-- Clean up AI response by removing markdown code fences
local function clean_response(response)
    if not response then
        return ""
    end

    -- Remove code fences
    response = response:gsub("```%w*\n?", "")
    response = response:gsub("```", "")

    -- Trim whitespace
    response = response:match("^%s*(.-)%s*$")

    return response
end

-- Parse JSON response with better error handling
local function parse_ai_response(response)
    local cleaned = clean_response(response)
    local ok, json = pcall(wezterm.json_parse, cleaned)

    if not ok then
        wezterm.log_error("AI Helper: Failed to parse JSON response: ", cleaned)
        return {
            message = "❌ Error parsing AI response \r\n" .. cleaned,
            command = nil,
        }
    end

    if json and type(json) == "table" then
        return json
    end

    -- Fallback: treat as plain text message
    return {
        message = cleaned,
        command = nil,
    }
end

-- Send command to AI and handle response
local function handle_ai_request(window, pane, prompt, config)
    if not prompt or prompt:match("^%s*$") then
        wezterm.log_info("Empty prompt, cancelling AI request")
        return
    end

    if config.share_pane_history then
      local history
      if config.share_n_lines ~= nil then
        history = pane:get_logical_lines_as_text(config.share_n_lines)
      else
        history = pane:get_logical_lines_as_text()
      end
      prompt = prompt .. "\nHere is the previous history of my shell:\n" .. history
    end

    -- Show loading indicator
    if config.show_loading then
        show_loading(pane, true)
    end

    local provider = get_provider(config)
    if not provider then
        wezterm.log_error("AI Helper: No valid provider found for type: ", config.type)
        return
    end

    local success, stdout, err = provider.generate_content(config, prompt)
    wezterm.log_info("AI Helper: AI request completed with success: ", success)

    if success then
        wezterm.log_info("AI Helper: AI response received, response: ", stdout)
        local response = parse_ai_response(stdout)

        -- Display message if present
        if response.message and response.message ~= "" then
            pane:inject_output("\r\n💬 " .. response.message:gsub("[\n]", "\r\n"))
        end

        -- Clear current line and send command if present
        pane:send_text("\u{15}") -- Ctrl+U to clear line
        pane:send_text("\r")

        if response.command and response.command ~= "" then
            pane:send_text(response.command)
        end
    else
        -- Handle errors
        local error_msg = "❌ AI request failed"
        if err and err ~= "" then
            error_msg = error_msg .. ": " .. err
            wezterm.log_error("AI Helper err: ", err)
        end
        pane:inject_output("\r\n" .. error_msg)

        -- Still clear the line for user convenience
        pane:send_text("\u{15}")
        pane:send_text("\r")
    end
end

-- Main function to apply configuration
local function apply_to_config(wezterm_config, user_config)
    local config = merge_config(user_config)

    -- Setup luarocks with the configured path
    setup_luarocks(config)

    local provider = get_provider(config)
    if not provider then
        wezterm.log_error("AI Helper: No valid generator found for type: ", config.type)
        return
    end

    if not provider.validate_config(config) then
        wezterm.log_error("AI Helper: Invalid configuration")
        return
    end

    -- Validate required configuration
    if config.type == "local" and not config.lms_path then
        wezterm.log_error("AI Helper: lms_path is required in configuration")
        return
    end

    if wezterm_config.keys == nil then
        wezterm_config.keys = {}
    end

    table.insert(wezterm_config.keys, {
        key = config.keybinding.key,
        mods = config.keybinding.mods,
        action = act.PromptInputLine({
            description = "🤖 Enter AI prompt:",
            action = wezterm.action_callback(function(window, pane, line)
                if line then
                    handle_ai_request(window, pane, line, config)
                else
                    wezterm.log_info("AI Helper: Request cancelled by user")
                end
            end),
        }),
    })

    wezterm.log_info("AI Helper plugin loaded with model: " .. config.model .. " and type: " .. config.type)
end

return {
    apply_to_config = apply_to_config,
}
