local QueueBase = require 'queues.base.base'
local obj = require 'utils.object'
local exporter = require 'systems.exporter'
local subs = require 'systems.subs.subs'
local repCreators = require 'reps.rep.repCreators'
local player = require 'systems.player'
local sounds = require 'systems.sounds'
local log = require 'utils.log'
local active = require 'systems.active'
local item_format = require 'reps.rep.item_format'
local cfg = require 'systems.config'
local get_user_input = require 'systems.user_input'
local mp = require 'mp'
local tbl = require 'utils.table'

local LocalTopics
local LocalItems
local GlobalItems
local GlobalTopics

local ExtractQueueBase = {}
ExtractQueueBase.__index = ExtractQueueBase

setmetatable(ExtractQueueBase, {
    __index = QueueBase, -- this is what makes the inheritance work
    __call = function(cls, ...)
        local self = setmetatable({}, cls)
        self:_init(...)
        return self
    end
})

function ExtractQueueBase:_init(name, old_rep, rep_table)
    QueueBase._init(self, name, rep_table, old_rep)
    -- LuaFormatter off
    self.script_messages = {
        ["incmedia-create-qa"] = function() self:create_qa() end,
        ["incmedia-create-cloze-context"] = function() self:extract(item_format.cloze_context) end,
        ["incmedia-extract-extract"] = function() self:extract("extract") end
    }
    self.create_qa_chain = {
        function(args, chain, i) self:query_qa_format(args, chain, i) end,
        function(args, chain, i) self:query_include_image(args, chain, i) end,
        function(args, chain, i) self:query_include_sound(args, chain, i) end,
        function(args, chain, i) self:query_question(args, chain, i) end,
        function(args, chain, i) self:query_answer(args, chain, i) end,
        function(args, chain, i) self:query_confirm_qa(args, chain, i) end
    }
    -- LuaFormatter on
end

function ExtractQueueBase:clean_up_events() self:unregister_script_messages() end

function ExtractQueueBase:register_script_messages()
    log.debug("registering extract queue script messages")
    for k, v in ipairs(self.script_messages) do
        mp.register_script_message(k, v)
    end
end

function ExtractQueueBase:unregister_script_messages()
    log.debug("unregistering extract queue script messages")
    for k, _ in pairs(self.script_messages) do
        mp.unregister_script_message(k)
    end
end

function ExtractQueueBase:activate()
    if QueueBase.activate(self) then
        self:register_script_messages()
        return true
    end
    return false
end

function ExtractQueueBase:call_chain(args, chain, i)
    if chain ~= nil and i <= #chain then
        chain[i](args, chain, i)
    else
        log.debug("End of chain: ", args)
    end
end

function ExtractQueueBase:child()
    local curRep = self.reptable:current_scheduled()
    if curRep == nil then
        log.debug("Failed to load child queue because current rep is nil.")
        return false
    end

    LocalItems = LocalItems or require("queues.local.items")
    local queue = LocalItems(self.playing)
    if obj.empty(queue.reptable.subset) then
        log.debug("No children available for extract")
        sounds.play("negative")
        return false
    end

    active.change_queue(queue)
    return true
end

function ExtractQueueBase:parent()
    local cur = self.playing
    if cur == nil then
        log.debug("Failed to load parent queue because current rep is nil.")
        return false
    end

    LocalTopics = LocalTopics or require("queues.local.topics")
    local queue = LocalTopics(self.playing)
    active.change_queue(queue)
end

function ExtractQueueBase:adjust_extract(postpone, start, n)
    local curRep = self.playing
    if not curRep then
        log.debug("Failed to adjust extract because currently playing is nil")
        sounds.play("negative")
        return
    end

    local adj
    if postpone then
        adj = n
    else
        adj = -n
    end
    local oldStart = tonumber(curRep.row["start"])
    local oldStop = tonumber(curRep.row["stop"])
    local newStart = oldStart
    if start then newStart = oldStart + adj end
    local newStop = oldStop + adj
    if start then newStop = oldStop end

    local duration = tonumber(mp.get_property("duration"))
    if newStart < 0 or newStart > duration or newStop < 0 or newStop > duration then
        log.err("Failed to adjust extract because start stop invalid")
        sounds.play("negative")
        return
    end

    local start_changed = oldStart ~= newStart
    local stop_changed = oldStop ~= newStop

    curRep.row["start"] = newStart
    curRep.row["stop"] = newStop

    -- update loop timer
    player.loop_timer.set_start_time(newStart)
    player.loop_timer.set_stop_time(newStop)

    if start_changed then
        subs.set_timing('start', newStart)
        mp.commandv("seek", tostring(newStart), "absolute")
    elseif stop_changed then
        subs.set_timing('end', newStop)
        mp.commandv("seek", tostring(newStop - 1), "absolute")
    end

    log.debug(
        "Updated extract boundaries to " .. curRep.row["start"] .. " -> " ..
            curRep.row["stop"])
end

function ExtractQueueBase:save_data()
    self:update_speed()
    return self.reptable:write(self.reptable)
end

function ExtractQueueBase:advance_start(n)
    n = tonumber(n)
    local a = mp.get_property("ab-loop-a")
    local b = mp.get_property("ab-loop-b")
    if self:validate_abloop(a, b) then
        QueueBase.advance_start(self, n)
    else
        self:adjust_extract(false, true, n)
    end
end

function ExtractQueueBase:advance_stop(n)
    n = tonumber(n)
    local a = mp.get_property("ab-loop-a")
    local b = mp.get_property("ab-loop-b")
    if self:validate_abloop(a, b) then
        QueueBase.advance_stop(self, n)
    else
        self:adjust_extract(false, false, n)
    end
end

function ExtractQueueBase:postpone_start(n)
    n = tonumber(n)
    local a = mp.get_property("ab-loop-a")
    local b = mp.get_property("ab-loop-b")
    if self:validate_abloop(a, b) then
        QueueBase.postpone_start(self, n)
    else
        self:adjust_extract(true, true, n)
    end
end

function ExtractQueueBase:postpone_stop(n)
    n = tonumber(n)
    local a = mp.get_property("ab-loop-a")
    local b = mp.get_property("ab-loop-b")
    if self:validate_abloop(a, b) then
        QueueBase.postpone_stop(self, n)
    else
        self:adjust_extract(true, false, n)
    end
end

function ExtractQueueBase:query_confirm_qa(args, chain, i)
    local handle = function(input)
        if input == nil or input == "n" then
            log.notify("Cancelling.")
            return
        elseif input == "y" or input == "" then
            log.debug(args)
            log.notify("Importing.")
        else
            log.notify("Invalid input.")
            self:call_chain(args, chain, i)
            return
        end

        local parent = args.curRep
        local sound = args.sound
        local media = args.media
        local format = args.format

        -- if no question, answer, media... just cancel.
        if not args.text.question and not args.text.answer and not media and
            not sound then
            log.debug("No content!")
            return false
        end

        local text = {
            question = args.text.question and args.text.question or "",
            answer = args.text.answer and args.text.answer or ""
        }

        local itemRep = repCreators.createItem1(parent, sound, media, text,
                                                format)

        if itemRep == nil then
            log.notify("Failed to create item.")
            return false
        end

        return self:add_item(itemRep)
    end

    get_user_input(handle, {text = "Confirm? ([y]/n):", replace = true})
end

function ExtractQueueBase:add_item(itemRep)
    GlobalItems = GlobalItems or require("queues.global.items")
    local giq = GlobalItems(nil)
    local irt = giq.reptable
    if irt:add_to_reps(itemRep) then
        sounds.play("echo")
        player.unset_abloop()
        if giq:save_data() and cfg.auto_export then
            log.debug("Exporting created item to SM.")
            local time = exporter.get_last_export_time()
            exporter.export_new_items_to_sm(time)
        end
        return true
    else
        sounds.play("negative")
        log.err("Failed to add item to the rep table.")
        return false
    end
end

function ExtractQueueBase:query_flashcard_side(media, args, chain, i)
    local handler = function(input)
        if input == nil then
            log.notify("Cancelling")
            return
        end

        if input == "a" or input == "" then
            args[media .. "-side"] = "answer"
            i = i + 1
        elseif input == "q" then
            args[media .. "-side"] = "question"
            i = i + 1
        else
            log.notify("Invalid input.")
            self:query_flashcard_side(media, args, chain, i)
            return
        end

        self:call_chain(args, chain, i)
    end

    get_user_input(handler, {text = media .. " side? (a/[q]):", replace = true})
end

function ExtractQueueBase:query_include_sound(args, chain, i)
    local handler = function(input)
        if input == nil then
            log.notify("Cancelling")
            return
        end

        local cur = args.curRep
        args["sound"] = {}

        if input == "n" then
            args["sound"] = nil
        elseif input == "y" or input == "" then
            args["sound"]["start"] = cur.row.start
            args["sound"]["stop"] = cur.row.stop
            args["sound"]["showat"] = "answer"
        else
            log.notify("Invalid input.")
            self:call_chain(args, chain, i)
            return
        end

        self:call_chain(args, chain, i + 1)
    end

    get_user_input(handler, {text = "Include sound? (n/[y]):", replace = true})
end

function ExtractQueueBase:query_sound_side(args, chain, i)
    self:query_flashcard_side("sound", args, chain, i)
end

function ExtractQueueBase:query_image_side(args, chain, i)
    self:query_flashcard_side("image", args, chain, i)
end

function ExtractQueueBase:query_include_image(args, chain, i)
    local handler = function(input)
        if input == nil then
            log.notify("Cancelling")
            return
        end

        args["media"] = {}
        local cur = args.curRep
        if input == "n" or input == "" then
            args["media"] = nil
        elseif input == "s" then
            args["media"]["type"] = "screenshot"
            args["media"]["showat"] = "answer"
            args["media"]["start"] = cur.row.start
            args["media"]["stop"] = cur.row.stop
        elseif input == "g" then
            args["media"]["type"] = "gif"
            args["media"]["showat"] = "answer"
            args["media"]["start"] = cur.row.start
            args["media"]["stop"] = cur.row.stop
        else
            log.notify("Invalid input.")
            self:call_chain(args, chain, i)
            return
        end

        self:call_chain(args, chain, i + 1)
    end

    get_user_input(handler, {text = "Include image? (s/g/[n]):", replace = true})
end

function ExtractQueueBase:query_answer(args, chain, i)
    local handler = function(input)
        if input == nil then
            log.notify("Cancelled.")
            return
        end

        args["text"]["answer"] = input
        self:call_chain(args, chain, i + 1)
    end

    get_user_input(handler, {text = "Answer: ", replace = true})
end

function ExtractQueueBase:query_question(args, chain, i)
    local handler = function(input)
        if input == nil then
            log.notify("Cancelled.")
            return
        end

        args["text"] = {}
        args["text"]["question"] = input
        self:call_chain(args, chain, i + 1)
    end

    get_user_input(handler, {text = "Question: ", replace = true})
end

function ExtractQueueBase:query_qa_format(args, chain, i)

    local choices = {[1] = item_format.qa}

    local handler = function(input)
        local choice = tonumber(input)
        if choice == nil then
            log.notify("Cancelled.")
            return
        end

        if choice < 1 or choice > #choices then
            log.notify("Invalid input.")
            self:call_chain(args, chain, i)
            return
        end

        args["format"] = {name = choices[choice]}
        self:call_chain(args, chain, i + 1)
    end

    get_user_input(handler,
                   {text = "QA format:\n1) classic Q/A\n", replace = true})
end

function ExtractQueueBase:create_qa()
    local queue = active.queue
    if queue == nil or queue.playing == nil then return end
    local curRep = queue.playing
    self:call_chain({
        start = curRep.row.start,
        stop = curRep.row.stop,
        curRep = curRep
    }, self.create_qa_chain, 1)
end

function ExtractQueueBase:handle_extract_extract(start, stop, curRep)

    local queue = active.queue
    if queue == nil then return end

    GlobalTopics = GlobalTopics or require("queues.global.topics")
    local gtq = GlobalTopics(nil)
    local parent = tbl.first(function(r) return r:is_parent_of(curRep) end,
                             gtq.reptable.reps)
    if parent == nil then
        log.debug("Failed to find parent element.")
        return
    end

    local extract = repCreators.createExtract(parent, start, stop,
                                              curRep.row.subs)
    if obj.empty(extract) then return false end

    if queue.reptable:add_to_reps(extract) then
        sounds.play("echo")
        player.unset_abloop()
        queue:save_data()
        return true
    else
        sounds.play("negative")
        log.err("Failed to add item to the rep table.")
        return false
    end
end

function ExtractQueueBase:handle_extract_cloze(curRep, sound, format)
    local itemRep = repCreators.createItem1(curRep, sound, nil, nil, format)
    if obj.empty(itemRep) then
        log.debug("Failed to create item rep.")
        return false
    end

    return self:add_item(itemRep)
end

function ExtractQueueBase:handle_extract(loopStart, loopStop, curRep,
                                         extractType)
    if curRep == nil then
        log.debug("Failed to create item because current rep was nil.")
        return false
    end

    if not loopStart or not loopStop or (loopStart > loopStop) then
        log.err("Invalid boundaries.")
        return false
    end

    if not extractType then extractType = item_format.cloze end

    if extractType == "extract" then
        return self:handle_extract_extract(loopStart, loopStop, curRep)
    elseif extractType == item_format.cloze_context or extractType ==
        item_format.cloze then
        local sound = {
            path = curRep.row.url,
            start = curRep.row.start,
            stop = curRep.row.stop
        }
        local format = {
            name = extractType,
            ["cloze-start"] = loopStart,
            ["cloze-stop"] = loopStop
        }
        return self:handle_extract_cloze(curRep, sound, format)
    else
        log.err("Unrecognised extract type.")
    end
end

return ExtractQueueBase
