-- qb-stabcityai: Agent-to-Agent ambient conversations
-- Two agents randomly chat every 1-2 minutes
-- Audio is queued so agents never talk over each other

-- Track when a specific audio clip finishes
local audioCallbacks = {}

-- NUI callback: audio clip finished playing
RegisterNUICallback('audioFinished', function(data, cb)
    cb('ok')
    local id = data.id
    if id and audioCallbacks[id] then
        audioCallbacks[id]()
        audioCallbacks[id] = nil
    end
end)

-- Helper: play TTS and call onDone when the clip ends (or after fallback timeout)
local function PlayTTSWithCallback(url, onDone)
    if not url or url == "" then
        if onDone then onDone() end
        return
    end

    local clipId = "tts_" .. tostring(GetGameTimer()) .. "_" .. tostring(math.random(10000))
    local callbackFired = false

    audioCallbacks[clipId] = function()
        if not callbackFired then
            callbackFired = true
            if onDone then onDone() end
        end
    end

    SendNUIMessage({
        type = "playTTS",
        url = url,
        id = clipId,
    })

    -- Fallback timeout in case NUI callback doesn't fire (15s max)
    SetTimeout(15000, function()
        if not callbackFired then
            callbackFired = true
            audioCallbacks[clipId] = nil
            if onDone then onDone() end
        end
    end)
end

-- ─── Ambient Chat Timer ──────────────────────────────────────────────────────

CreateThread(function()
    Wait(30000)  -- let agents fully spawn and settle
    while true do
        local delay = math.random(Config.A2AChatMinDelay * 1000, Config.A2AChatMaxDelay * 1000)
        Wait(delay)

        if IsTalking or IsA2AChatting or #SpawnedPeds < 2 then goto continue end

        do
            local idx1 = math.random(#SpawnedPeds)
            local idx2
            repeat idx2 = math.random(#SpawnedPeds) until idx2 ~= idx1

            local initiator = SpawnedPeds[idx1].data.name
            local responder = SpawnedPeds[idx2].data.name

            IsA2AChatting = true
            print("^5[StabCity AI] Ambient chat: " .. initiator .. " -> " .. responder)
            TriggerServerEvent("stabcityai:server:chat", initiator, responder)
        end

        ::continue::
    end
end)

-- ─── Handle A2A Chat Response ────────────────────────────────────────────────

RegisterNetEvent("stabcityai:client:chatResponse")
AddEventHandler("stabcityai:client:chatResponse", function(initiatorName, initiatorLine, responderName, responderLine, initiatorAudio, responderAudio)
    -- Resolve ped handles
    local initiatorPed = GetAgentPed(initiatorName)
    local responderPed = GetAgentPed(responderName)

    -- Both peds face each other
    if initiatorPed and DoesEntityExist(initiatorPed) and
       responderPed and DoesEntityExist(responderPed) then
        TaskTurnPedToFaceEntity(initiatorPed, responderPed, 2000)
        TaskTurnPedToFaceEntity(responderPed, initiatorPed, 2000)
    end

    -- Show initiator line + play audio
    TriggerEvent("chat:addMessage", {
        color     = Config.AgentColors[initiatorName] or {255, 165, 0},
        multiline = true,
        args      = {initiatorName, initiatorLine}
    })

    -- Play initiator audio, then when it finishes → show responder line
    local initiatorUrl = ""
    if initiatorAudio and initiatorAudio ~= "" then
        initiatorUrl = Config.BridgeURL .. "/audio/" .. initiatorAudio
    end

    PlayTTSWithCallback(initiatorUrl, function()
        -- Small pause between speakers (feels natural)
        SetTimeout(500, function()
            -- Show responder line + play audio
            TriggerEvent("chat:addMessage", {
                color     = Config.AgentColors[responderName] or {255, 165, 0},
                multiline = true,
                args      = {responderName, responderLine}
            })

            local responderUrl = ""
            if responderAudio and responderAudio ~= "" then
                responderUrl = Config.BridgeURL .. "/audio/" .. responderAudio
            end

            PlayTTSWithCallback(responderUrl, function()
                -- Resume routines after both are done speaking
                SetTimeout(1000, function()
                    if initiatorPed and DoesEntityExist(initiatorPed) then
                        local s = AgentCurrentSlot[initiatorName]
                        if s then ApplyRoutineTask(initiatorPed, s) end
                    end
                    if responderPed and DoesEntityExist(responderPed) then
                        local s = AgentCurrentSlot[responderName]
                        if s then ApplyRoutineTask(responderPed, s) end
                    end
                    IsA2AChatting = false
                end)
            end)
        end)
    end)
end)
