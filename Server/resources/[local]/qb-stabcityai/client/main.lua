-- qb-stabcityai: Agent spawning, routines, wandering
-- Ported from StabCity AI vanilla → QBCore integration

local QBCore = exports['qb-core']:GetCoreObject()

-- Shared state (accessed by other client scripts)
SpawnedPeds = {}                -- { { ped = handle, data = agentConfig }, ... }
AgentSpawnCoords = {}           -- [pedHandle] = vector3
AgentCurrentSlot = {}           -- [agentName] = current scenario string
IsTalking = false               -- player is in conversation with an agent
IsA2AChatting = false           -- agents are chatting with each other
AgentBlips = {}                 -- [agentName] = blipHandle

-- ─── Ped Spawning ────────────────────────────────────────────────────────────

local function SpawnAgent(agent)
    local model = GetHashKey(agent.model)
    RequestModel(model)

    local timeout = 0
    while not HasModelLoaded(model) do
        Wait(100)
        timeout = timeout + 1
        if timeout > 50 then
            print("^1[StabCity AI] FAILED to load model: " .. agent.name)
            return nil
        end
    end

    local ped = CreatePed(4, model, agent.home.x, agent.home.y, agent.home.z, agent.heading, false, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    FreezeEntityPosition(ped, false)

    -- Set initial routine
    local initialScenario = GetRoutineSlot(agent.name, GetClockHours())
    AgentCurrentSlot[agent.name] = initialScenario
    AgentSpawnCoords[ped] = agent.home
    ApplyRoutineTask(ped, initialScenario)

    table.insert(SpawnedPeds, { ped = ped, data = agent })
    SetModelAsNoLongerNeeded(model)

    print("^2[StabCity AI] Spawned: " .. agent.name .. " | ID: " .. ped)
    return ped
end

function ApplyRoutineTask(ped, scenario)
    ClearPedTasks(ped)
    if scenario ~= "WANDER" then
        TaskStartScenarioInPlace(ped, scenario, 0, true)
    end
end

local function CreateAgentBlip(agent)
    if not agent.blip then return end
    local blip = AddBlipForCoord(agent.home.x, agent.home.y, agent.home.z)
    SetBlipSprite(blip, agent.blip.sprite)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 0.7)
    SetBlipColour(blip, agent.blip.color)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(agent.blip.label)
    EndTextCommandSetBlipName(blip)
    AgentBlips[agent.name] = blip
end

local function DespawnAllAgents()
    for _, a in ipairs(SpawnedPeds) do
        if DoesEntityExist(a.ped) then
            DeleteEntity(a.ped)
        end
    end
    SpawnedPeds = {}
    AgentSpawnCoords = {}
    AgentCurrentSlot = {}

    for name, blip in pairs(AgentBlips) do
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    AgentBlips = {}
end

-- ─── QBCore Lifecycle ────────────────────────────────────────────────────────

local function SpawnAllAgents()
    DespawnAllAgents()
    Wait(1000)

    for _, agent in ipairs(Config.Agents) do
        local ped = SpawnAgent(agent)
        if ped then
            CreateAgentBlip(agent)
        end
        Wait(500)
    end

    print("^2[StabCity AI] All " .. #Config.Agents .. " agents deployed!")
end

-- Spawn agents when player is fully loaded
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    SpawnAllAgents()
end)

-- Despawn agents when player unloads (character select, disconnect)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    DespawnAllAgents()
end)

-- Handle resource restart
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    Wait(2000)
    if QBCore.Functions.GetPlayerData().citizenid then
        SpawnAllAgents()
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    DespawnAllAgents()
end)

-- ─── Wander Maintenance Loop ─────────────────────────────────────────────────
-- Every N seconds, send WANDER-slot agents to a random point within the shared
-- roam center. This draws all agents toward the same area so they can meet up.

CreateThread(function()
    Wait(8000)
    while true do
        Wait(Config.WanderInterval)
        for _, a in ipairs(SpawnedPeds) do
            if not DoesEntityExist(a.ped) then goto wanderContinue end
            if AgentCurrentSlot[a.data.name] ~= "WANDER" then goto wanderContinue end
            if IsTalking or IsA2AChatting then goto wanderContinue end

            -- Wander toward a random point near the shared roam center
            local center = Config.RoamCenter
            local angle  = math.random() * 2 * math.pi
            local r      = Config.WanderMinDist + math.random() * (Config.WanderMaxDist - Config.WanderMinDist)
            local tx     = center.x + math.cos(angle) * r
            local ty     = center.y + math.sin(angle) * r
            TaskFollowNavMeshToCoord(a.ped, tx, ty, center.z, 1.0, 30000, 0.5, false, 0.0)

            ::wanderContinue::
        end
    end
end)

-- ─── Leash Loop ──────────────────────────────────────────────────────────────
-- Teleport agents back to roam center if they wander too far from it

CreateThread(function()
    Wait(5000)
    while true do
        Wait(10000)
        local center = Config.RoamCenter
        for _, a in ipairs(SpawnedPeds) do
            if DoesEntityExist(a.ped) then
                local pos = GetEntityCoords(a.ped)
                if #(pos - center) > Config.WanderRadius then
                    SetEntityCoords(a.ped, center.x, center.y, center.z)
                    print("^3[StabCity AI] " .. a.data.name .. " returned to roam center")
                end
            end
        end
    end
end)

-- ─── Routine Tick ────────────────────────────────────────────────────────────
-- Check GTA clock, update agent activities when time slot changes

CreateThread(function()
    Wait(6000)
    while true do
        Wait(Config.RoutineCheckInterval)
        if not IsTalking then
            local hour = GetClockHours()
            for _, a in ipairs(SpawnedPeds) do
                if DoesEntityExist(a.ped) then
                    local scenario = GetRoutineSlot(a.data.name, hour)
                    if AgentCurrentSlot[a.data.name] ~= scenario then
                        AgentCurrentSlot[a.data.name] = scenario
                        ApplyRoutineTask(a.ped, scenario)
                        print("^5[StabCity AI] " .. a.data.name .. " -> " .. scenario .. " (hour " .. hour .. ")")
                    end
                end
            end
        end
    end
end)

-- ─── Helper: Find ped by agent name ──────────────────────────────────────────

function GetAgentPed(agentName)
    for _, a in ipairs(SpawnedPeds) do
        if a.data.name == agentName then
            return a.ped
        end
    end
    return nil
end
