local wezterm = require("wezterm")

local function generate_content(config, prompt)
    local request_body = {
        contents = {
            {
                parts = {
                    {
                        text = prompt,
                    },
                },
            },
        },
        generationConfig = {
            responseMimeType = "application/json",
            responseSchema = {
                type = "OBJECT",
                properties = {
                    message = { type = "STRING" },
                    command = { type = "STRING" },
                },
                required = { "message" },
            },
        },
    }

    if config.system_instruction then
        request_body.system_instruction = {
            parts = {
                {
                    text = config.system_instruction,
                },
            },
        }
    end

    local url = "https://generativelanguage.googleapis.com/v1beta/models/"
        .. config.model
        .. ":generateContent?key="
        .. config.api_key

    local body = wezterm.json_encode(request_body)

    local success, stdout, stderr = wezterm.run_child_process({
        "curl",
        "-s",
        "-X", "POST",
        "-H", "Content-Type: application/json",
        url,
        "-d", body,
    })

    if not success then
        return false, nil, stderr or "Failed to execute HTTP request"
    end

    if stdout == "" then
        return false, nil, "Empty response from API"
    end

    local ok, response_data = pcall(wezterm.json_parse, stdout)
    if not ok then
        return false, nil, "Failed to parse JSON response: " .. stdout
    end

    if not response_data.candidates or not response_data.candidates[1] then
        wezterm.log_error("AI Helper: invalid response: " .. stdout)
        return false, nil, "Invalid API response format"
    end

    return true, response_data.candidates[1].content.parts[1].text, nil
end

local function validate_config(config)
    if not config.api_key then
        wezterm.log_error("AI Helper: api_key is required in configuration")
        return false
    end
    return true
end

return {
    generate_content = generate_content,
    validate_config = validate_config,
}
