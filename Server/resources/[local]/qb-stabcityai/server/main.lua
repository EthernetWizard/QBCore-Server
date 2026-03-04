-- qb-stabcityai: Server-side bridge communication with QBCore player context

local QBCore = exports['qb-core']:GetCoreObject()

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print("^2[StabCity AI] QBCore bridge server started!")
    end
end)

-- ─── /talk — Player talks to an agent ────────────────────────────────────────
-- Gathers full QBCore player context and sends to bridge

RegisterNetEvent("stabcityai:server:talk")
AddEventHandler("stabcityai:server:talk", function(agentName, playerMessage, gameHour)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then
        print("^1[StabCity AI] No QBCore player found for source " .. src)
        return
    end

    local citizenid = Player.PlayerData.citizenid
    local charinfo  = Player.PlayerData.charinfo
    local jobData   = Player.PlayerData.job
    local gangData  = Player.PlayerData.gang
    local money     = Player.PlayerData.money

    local playerName = (charinfo.firstname or "Unknown") .. " " .. (charinfo.lastname or "")

    local body = json.encode({
        AgentName      = agentName,
        PlayerId       = citizenid,
        PlayerName     = playerName,
        PlayerJob      = jobData and jobData.name or "unemployed",
        PlayerJobLabel = jobData and jobData.label or "Unemployed",
        PlayerJobGrade = jobData and jobData.grade and jobData.grade.name or "",
        PlayerGang     = gangData and gangData.name or "none",
        PlayerGangLabel= gangData and gangData.label or "None",
        PlayerMoney    = {
            cash = money and money.cash or 0,
            bank = money and money.bank or 0,
        },
        PlayerMessage  = playerMessage,
        GameHour       = gameHour or 0,
    })

    print("^2[StabCity AI] " .. playerName .. " -> " .. agentName .. ": " .. playerMessage)

    PerformHttpRequest(Config.BridgeURL .. "/talk", function(statusCode, response, headers)
        if statusCode == 200 then
            local data = json.decode(response)
            if data and data.reply then
                print("^2[StabCity AI] " .. agentName .. " replies: " .. data.reply)

                -- Execute any game actions the agent decided to take
                if data.actions and #data.actions > 0 then
                    for _, action in ipairs(data.actions) do
                        ExecuteAgentAction(src, Player, agentName, action)
                    end
                end

                -- Send response to client (include actions for notification display)
                TriggerClientEvent("stabcityai:client:response", src, agentName, data.reply, data.audioFile or "", data.actions or {})
            else
                print("^1[StabCity AI] Bad response from bridge")
            end
        else
            print("^1[StabCity AI] Bridge error: " .. tostring(statusCode))
        end
    end, "POST", body, { ["Content-Type"] = "application/json" })
end)

-- ─── /react — Agent reacts to a game event ───────────────────────────────────

RegisterNetEvent("stabcityai:server:react")
AddEventHandler("stabcityai:server:react", function(agentName, eventType)
    local src = source
    print("^5[StabCity AI] " .. agentName .. " reacting to: " .. eventType)

    PerformHttpRequest(Config.BridgeURL .. "/react", function(statusCode, response, headers)
        if statusCode == 200 then
            local data = json.decode(response)
            if data and data.reply then
                TriggerClientEvent("stabcityai:client:response", src, agentName, data.reply, data.audioFile or "", {})
            else
                print("^1[StabCity AI] Bad react response")
            end
        else
            print("^1[StabCity AI] React error: " .. tostring(statusCode))
        end
    end, "POST", json.encode({
        AgentName = agentName,
        EventType = eventType,
    }), { ["Content-Type"] = "application/json" })
end)

-- ─── /chat — Agent-to-agent conversation ─────────────────────────────────────

RegisterNetEvent("stabcityai:server:chat")
AddEventHandler("stabcityai:server:chat", function(initiatorName, responderName)
    local src = source
    print("^5[StabCity AI] A2A: " .. initiatorName .. " -> " .. responderName)

    PerformHttpRequest(Config.BridgeURL .. "/chat", function(statusCode, response, headers)
        if statusCode == 200 then
            local data = json.decode(response)
            if data and data.initiatorLine and data.responderLine then
                TriggerClientEvent("stabcityai:client:chatResponse", src,
                    initiatorName, data.initiatorLine,
                    responderName, data.responderLine,
                    data.initiatorAudio or "", data.responderAudio or "")
            else
                print("^1[StabCity AI] Bad /chat response")
            end
        else
            print("^1[StabCity AI] /chat error: " .. tostring(statusCode))
        end
    end, "POST", json.encode({
        InitiatorName = initiatorName,
        ResponderName = responderName,
    }), { ["Content-Type"] = "application/json" })
end)
