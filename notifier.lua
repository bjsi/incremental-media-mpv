local function subprocess(args, completion_fn)
    -- if `completion_fn` is passed, the command is ran asynchronously,
    -- and upon completion, `completion_fn` is called to process the results.
    local command_native = type(completion_fn) == 'function' and mp.command_native_async or mp.command_native
    local command_table = {
        name = "subprocess",
        playback_only = false,
        capture_stdout = true,
        args = args
    }
    return command_native(command_table, completion_fn)
end

local function notify_extracted(queue)
    local args = {
        "notify-send",
        queue .. ": Extract created."
    }
    subprocess(args)
end

local function notify_element_changed(queue)
    local args = {
        "notify-send",
        queue .. ": Element changed."
    }
    subprocess(args)
end

local main
do
    local main_executed = false

    main  = function()
        if main_executed then return end
        mp.register_script_message("element_changed", notify_element_changed)
        mp.register_script_message("extracted", notify_extracted)
    end
end

mp.register_event("file-loaded", main)
