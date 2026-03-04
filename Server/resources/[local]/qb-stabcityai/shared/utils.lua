-- Shared utility functions for qb-stabcityai

-- Get routine scenario for an agent at a given GTA hour
function GetRoutineSlot(agentName, hour)
    local schedule = Config.Routines[agentName]
    if not schedule then return "WORLD_HUMAN_STAND_IMPATIENT" end
    local chosen = schedule[1].scenario
    for _, entry in ipairs(schedule) do
        if hour >= entry.fromHour then
            chosen = entry.scenario
        end
    end
    return chosen
end

-- Find agent config by name
function GetAgentConfig(name)
    for _, agent in ipairs(Config.Agents) do
        if agent.name == name then
            return agent
        end
    end
    return nil
end
