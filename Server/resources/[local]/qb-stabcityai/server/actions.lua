-- qb-stabcityai: Execute game actions decided by the AI agent
-- Handles give_item, take_item, give_money, take_money

local QBCore = exports['qb-core']:GetCoreObject()

function ExecuteAgentAction(src, Player, agentName, action)
    if not action or not action.type then return end

    if action.type == "give_item" then
        local item = tostring(action.item)
        local count = tonumber(action.count) or 1
        count = math.min(count, 10)  -- safety cap

        -- Verify item exists in QBCore shared items
        if not QBCore.Shared.Items[item] then
            print("^1[StabCity AI] Unknown item: " .. item .. " (agent: " .. agentName .. ")")
            return
        end

        local success = exports['qb-inventory']:AddItem(src, item, count)
        if success then
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], "add", count)
            print("^2[StabCity AI] " .. agentName .. " gave " .. count .. "x " .. item .. " to player")
        else
            print("^1[StabCity AI] Failed to give item " .. item .. " to player")
        end

    elseif action.type == "take_item" then
        local item = tostring(action.item)
        local count = tonumber(action.count) or 1

        if not QBCore.Shared.Items[item] then
            print("^1[StabCity AI] Unknown item: " .. item)
            return
        end

        local hasItem = exports['qb-inventory']:HasItem(src, item, count)
        if hasItem then
            exports['qb-inventory']:RemoveItem(src, item, count)
            TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[item], "remove", count)
            print("^2[StabCity AI] " .. agentName .. " took " .. count .. "x " .. item .. " from player")
        else
            print("^3[StabCity AI] Player doesn't have " .. count .. "x " .. item .. " to give")
        end

    elseif action.type == "give_money" then
        local amount = tonumber(action.amount) or 0
        local moneyType = action.moneyType or "cash"
        amount = math.min(amount, 10000)  -- safety cap

        if amount > 0 then
            Player.Functions.AddMoney(moneyType, amount, "stabcityai-" .. agentName)
            print("^2[StabCity AI] " .. agentName .. " gave $" .. amount .. " " .. moneyType .. " to player")
        end

    elseif action.type == "take_money" then
        local amount = tonumber(action.amount) or 0
        local moneyType = action.moneyType or "cash"

        if amount > 0 then
            local currentMoney = Player.PlayerData.money[moneyType] or 0
            if currentMoney >= amount then
                Player.Functions.RemoveMoney(moneyType, amount, "stabcityai-" .. agentName)
                print("^2[StabCity AI] " .. agentName .. " took $" .. amount .. " " .. moneyType .. " from player")
            else
                print("^3[StabCity AI] Player doesn't have enough " .. moneyType .. " ($" .. amount .. " needed)")
            end
        end

    else
        print("^3[StabCity AI] Unknown action type: " .. tostring(action.type))
    end
end
