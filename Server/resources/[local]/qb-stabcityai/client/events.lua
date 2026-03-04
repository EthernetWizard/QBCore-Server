-- qb-stabcityai: Event detection and agent reactions
-- Detects gunshots, explosions, weapons drawn, dead peds near agents

local agentReactionCooldown = {}  -- [agentName] = GetGameTimer() of last reaction
local weaponWasDrawn = false
local reportedDeadPeds = {}       -- [pedHandle] = true

-- ─── Cooldown Check ──────────────────────────────────────────────────────────

local function CanReact(agentName)
    local last = agentReactionCooldown[agentName]
    return not last or (GetGameTimer() - last) > Config.ReactionCooldown
end

-- ─── Trigger Reaction ────────────────────────────────────────────────────────
-- Finds agents within range of the player and triggers a reaction on one

local function TriggerNearbyReaction(eventType, range)
    if IsTalking then return end
    local playerPos = GetEntityCoords(PlayerPedId())
    local candidates = {}

    for _, a in ipairs(SpawnedPeds) do
        if DoesEntityExist(a.ped) and CanReact(a.data.name) then
            local dist = #(GetEntityCoords(a.ped) - playerPos)
            if dist <= range then
                table.insert(candidates, a)
            end
        end
    end

    if #candidates > 0 then
        local chosen = candidates[math.random(#candidates)]
        agentReactionCooldown[chosen.data.name] = GetGameTimer()
        print("^5[StabCity AI] " .. chosen.data.name .. " reacts to " .. eventType)
        TriggerServerEvent("stabcityai:server:react", chosen.data.name, eventType)
    end
end

-- ─── GTA Game Events (gunshots, explosions) ──────────────────────────────────

AddEventHandler("gameEventTriggered", function(name, args)
    if name == "CEventGunShot" or name == "CEventShockingGunShotFired" then
        TriggerNearbyReaction("gunshot", Config.ReactionRanges.gunshot)
    elseif name == "CEventExplosion" or name == "CEventShockingExplosionHeard" then
        TriggerNearbyReaction("explosion", Config.ReactionRanges.explosion)
    end
end)

-- ─── Weapon Drawn Detection ──────────────────────────────────────────────────
-- Poll every 500ms to see if player has drawn a weapon near an agent

CreateThread(function()
    while true do
        Wait(500)
        local weapon = GetSelectedPedWeapon(PlayerPedId())
        local armed = weapon ~= GetHashKey("WEAPON_UNARMED")
        if armed and not weaponWasDrawn then
            weaponWasDrawn = true
            TriggerNearbyReaction("weapon_drawn", Config.ReactionRanges.weapon_drawn)
        elseif not armed then
            weaponWasDrawn = false
        end
    end
end)

-- ─── Dead Ped Detection ──────────────────────────────────────────────────────
-- Poll every 2s for dead peds near agents

CreateThread(function()
    while true do
        Wait(2000)
        local peds = GetGamePool("CPed")
        for _, ped in ipairs(peds) do
            if IsEntityDead(ped) and not IsPedAPlayer(ped) and not reportedDeadPeds[ped] then
                local pedPos = GetEntityCoords(ped)
                for _, a in ipairs(SpawnedPeds) do
                    if DoesEntityExist(a.ped) then
                        if #(GetEntityCoords(a.ped) - pedPos) <= Config.ReactionRanges.dead_ped then
                            reportedDeadPeds[ped] = true
                            TriggerNearbyReaction("dead_ped", Config.ReactionRanges.dead_ped)
                            break
                        end
                    end
                end
            end
        end
    end
end)
