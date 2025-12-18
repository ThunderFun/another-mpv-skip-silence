local opts = {
    threshold = -40,
    dynamic_threshold = true,
    threshold_percentile = 0.20,
    max_volume_samples = 150,
    silence_duration = 1.0,
    silence_speed = 2.5,
    playback_speed = 1.01,
    enabled = false,
    debug = false,
}

local state = {
    is_silent = false,
    volume_samples = {},
    last_update_time = 0,
    speed_reset_timer = nil,
}

function setup_filters()
    if not opts.enabled then return end
    local af_string = string.format("@amps:lavfi=[silencedetect=n=%ddB:d=%f]", 
                                    opts.threshold, opts.silence_duration)
    mp.commandv("af", "add", af_string)
end

function update_threshold(new_threshold)
    local old_threshold = opts.threshold
    opts.threshold = math.floor(new_threshold + 0.5)
    opts.threshold = math.max(-60, math.min(-10, opts.threshold))
    
    if opts.enabled and opts.threshold ~= old_threshold then
        mp.commandv("af", "remove", "@amps")
        setup_filters()
    end
end

function handle_log_message(msg)
    if not opts.enabled then return end
    if msg.prefix ~= "ffmpeg" and msg.prefix ~= "lavfi" then return end

    if msg.text:find("silence_start") then
        if not state.is_silent then
            state.is_silent = true
            local current_speed = mp.get_property_number("speed", 1.0)
            if current_speed ~= opts.silence_speed then
                opts.playback_speed = current_speed
            end
            mp.set_property("speed", opts.silence_speed)
        end
    elseif msg.text:find("silence_end") then
        if state.is_silent then
            state.is_silent = false
            mp.set_property("speed", opts.playback_speed)
        end

        local peak = msg.text:match("silence_peak: ([-%d%.]+)")
        if opts.dynamic_threshold and peak then
            local peak_db = tonumber(peak)
            if peak_db then
                table.insert(state.volume_samples, peak_db)
                if #state.volume_samples > opts.max_volume_samples then
                    table.remove(state.volume_samples, 1)
                end

                local now = mp.get_time()
                if #state.volume_samples >= 5 and (now - state.last_update_time > 2.0) then
                    local sorted = {}
                    for _, v in ipairs(state.volume_samples) do table.insert(sorted, v) end
                    table.sort(sorted)

                    local idx = math.max(1, math.floor(#sorted * opts.threshold_percentile))
                    local target = sorted[idx] + 3
                    local diff = target - opts.threshold
                    
                    if math.abs(diff) >= 1 then
                        state.last_update_time = now
                        update_threshold(opts.threshold + ((diff > 0) and 1 or -1))
                    end
                end
            end
        end
    end
end

function toggle_enabled()
    opts.enabled = not opts.enabled
    if opts.enabled then
        setup_filters()
        mp.set_property("speed", opts.playback_speed)
        mp.osd_message("AMPS: Enabled")
    else
        mp.commandv("af", "remove", "@amps")
        mp.set_property("speed", opts.playback_speed)
        state.is_silent = false
        mp.osd_message("AMPS: Disabled")
    end
end

mp.enable_messages("v") 
mp.register_event("log-message", handle_log_message)

mp.register_event("file-loaded", function()
    state.is_silent = false
    state.volume_samples = {}
    state.last_update_time = 0
    if opts.enabled then 
        setup_filters() 
        mp.set_property("speed", opts.playback_speed)
    end
end)

mp.add_key_binding("C", "toggle-amps", toggle_enabled)

mp.observe_property("speed", "number", function(name, value)
    if not mp.get_property("path") then return end
    
    if state.speed_reset_timer then
        state.speed_reset_timer:kill()
        state.speed_reset_timer = nil
    end

    if not value or state.is_silent or value == opts.silence_speed then return end
    
    if math.abs(value - 1.0) < 0.001 and math.abs(opts.playback_speed - 1.0) > 0.001 then
        state.speed_reset_timer = mp.add_timeout(5, function()
            mp.set_property("speed", opts.playback_speed)
            mp.osd_message("AMPS: Resetting speed to " .. opts.playback_speed .. "x")
        end)
    end

    if math.abs(value - opts.playback_speed) > 0.001 then
        opts.playback_speed = value
    end
end)

mp.register_event("end-file", function()
    mp.set_property("speed", 1.0)
end)
