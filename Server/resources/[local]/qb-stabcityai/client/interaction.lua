-- qb-stabcityai: Player interaction via qb-target + qb-input
-- Replaces the vanilla G key system with QBCore's eye-targeting

local QBCore = exports['qb-core']:GetCoreObject()

-- Track which agents have had targets registered (to avoid duplicates)
local registeredTargets = {}

-- ─── Register qb-target on spawned agents ────────────────────────────────────

-- Poll for newly spawned peds and register targets
CreateThread(function()
    Wait(5000)  -- let agents spawn first
    while true do
        Wait(2000)
        for _, a in ipairs(SpawnedPeds) do
            if DoesEntityExist(a.ped) and not registeredTargets[a.ped] then
                registeredTargets[a.ped] = true
                exports['qb-target']:AddTargetEntity(a.ped, {
                    options = {
                        {
                            type = "client",
                            event = "stabcityai:client:startTalk",
                            icon = "fas fa-comment",
                            label = a.data.targetLabel or ("Talk to " .. a.data.name),
                            agentName = a.data.name,
                        },
                    },
                    distance = Config.InteractionDistance,
                })
                print("^2[StabCity AI] qb-target registered for " .. a.data.name)
            end
        end
    end
end)

-- ─── Start conversation via qb-input ─────────────────────────────────────────

RegisterNetEvent('stabcityai:client:startTalk', function(data)
    if IsTalking then return end

    local agentName = data.agentName
    if not agentName then return end

    -- Freeze the agent during conversation
    local agentPed = GetAgentPed(agentName)
    if agentPed and DoesEntityExist(agentPed) then
        ClearPedTasks(agentPed)
    end

    -- Open text input dialog
    local input = exports['qb-input']:ShowInput({
        header = "Talk to " .. agentName,
        submitText = "Say it",
        inputs = {
            {
                text = "What do you want to say?",
                name = "message",
                type = "text",
                isRequired = true,
            },
        },
    })

    if input and input.message and input.message ~= "" then
        IsTalking = true
        print("^2[StabCity AI] Player says to " .. agentName .. ": " .. input.message)
        TriggerServerEvent("stabcityai:server:talk", agentName, input.message, GetClockHours())

        -- Safety timeout to clear talking flag
        SetTimeout(15000, function()
            IsTalking = false
        end)
    else
        -- Input cancelled — resume agent routine
        if agentPed and DoesEntityExist(agentPed) then
            local scenario = AgentCurrentSlot[agentName]
            if scenario then
                ApplyRoutineTask(agentPed, scenario)
            end
        end
    end
end)

-- ─── Handle response from server ─────────────────────────────────────────────

RegisterNetEvent("stabcityai:client:response")
AddEventHandler("stabcityai:client:response", function(agentName, reply, audioFile, actions)
    local agentPed = GetAgentPed(agentName)

    -- Face the player
    if agentPed and DoesEntityExist(agentPed) then
        TaskTurnPedToFaceEntity(agentPed, PlayerPedId(), 2000)
    end

    -- Show response in chat with agent color
    local color = Config.AgentColors[agentName] or {255, 165, 0}
    TriggerEvent("chat:addMessage", {
        color     = color,
        multiline = true,
        args      = {agentName, reply}
    })

    -- Play TTS audio (queued — won't overlap with A2A or other responses)
    if audioFile and audioFile ~= "" then
        SendNUIMessage({
            type = "playTTS",
            url = Config.BridgeURL .. "/audio/" .. audioFile,
            id = "talk_" .. tostring(GetGameTimer()),
        })
    end

    -- Show notifications for game actions
    if actions then
        for _, action in ipairs(actions) do
            if action.type == "give_item" then
                QBCore.Functions.Notify(agentName .. " gave you " .. action.count .. "x " .. action.item, "success", 3000)
            elseif action.type == "take_item" then
                QBCore.Functions.Notify(agentName .. " took " .. action.count .. "x " .. action.item, "error", 3000)
            elseif action.type == "give_money" then
                QBCore.Functions.Notify(agentName .. " gave you $" .. action.amount, "success", 3000)
            elseif action.type == "take_money" then
                QBCore.Functions.Notify(agentName .. " charged you $" .. action.amount, "error", 3000)
            end
        end
    end

    -- Resume routine after face-turn animation
    SetTimeout(2500, function()
        if not IsTalking then
            if agentPed and DoesEntityExist(agentPed) then
                local scenario = AgentCurrentSlot[agentName]
                if scenario then
                    ApplyRoutineTask(agentPed, scenario)
                end
            end
        end
    end)

    IsTalking = false
end)

-- ─── Clean up targets on despawn ─────────────────────────────────────────────

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    registeredTargets = {}
end)
