Config = {}

-- Bridge URL (ASP.NET Core backend)
Config.BridgeURL = "http://localhost:5000"

-- Interaction
Config.InteractionDistance = 2.5         -- qb-target range in meters

-- Wandering
Config.RoamCenter = vector3(63.8, 3693.47, 39.75)  -- shared center point agents roam around
Config.WanderRadius = 100.0             -- max distance from RoamCenter before teleport back
Config.WanderInterval = 12000           -- ms between wander moves
Config.WanderMinDist = 5.0              -- min wander distance per step
Config.WanderMaxDist = 25.0             -- max wander distance per step

-- Routines
Config.RoutineCheckInterval = 60000     -- ms between GTA clock checks

-- Agent-to-Agent conversations
Config.A2AChatMinDelay = 60             -- seconds min between ambient chats
Config.A2AChatMaxDelay = 120            -- seconds max between ambient chats

-- Event reactions
Config.ReactionCooldown = 30000         -- ms cooldown per agent
Config.ReactionRanges = {
    gunshot      = 50.0,
    explosion    = 80.0,
    weapon_drawn = 8.0,
    dead_ped     = 20.0,
}

-- Agent definitions — add/remove/relocate agents here
Config.Agents = {
    {
        name = "Earl",
        model = "cs_dale",
        home = vector3(89.89, 3747.99, 40.77),
        heading = 220.1,
        blip = { sprite = 480, color = 47, label = "Earl" },
        targetLabel = "Talk to Earl",
    },
    {
        name = "Dolly",
        model = "g_f_y_vagos_01",
        home = vector3(91.63, 3752.12, 40.77),
        heading = 235.61,
        blip = { sprite = 480, color = 48, label = "Dolly" },
        targetLabel = "Talk to Dolly",
    },
    {
        name = "Wade",
        model = "cs_omega",
        home = vector3(27.88, 3664.96, 40.44),
        heading = 220.03,
        blip = { sprite = 480, color = 52, label = "Wade" },
        targetLabel = "Talk to Wade",
    },
    {
        name = "Sheryl",
        model = "s_f_y_bartender_01",
        home = vector3(29.24, 3668.44, 40.44),
        heading = 232.06,
        blip = { sprite = 480, color = 3, label = "Sheryl" },
        targetLabel = "Talk to Sheryl",
    },
}

-- Chat colors per agent (RGB)
Config.AgentColors = {
    Earl   = {220, 120,  60},   -- burnt orange
    Dolly  = {200,  80, 160},   -- dusty pink
    Wade   = { 80, 180, 100},   -- paranoid green
    Sheryl = { 80, 160, 220},   -- mechanic blue
}

-- Daily routine schedules per agent
-- WANDER = pseudo-scenario handled by wander loop (navmesh pathfinding)
Config.Routines = {
    Earl = {
        { fromHour =  0, scenario = "WORLD_HUMAN_LEAN_WALL_SMOKING"  },
        { fromHour =  6, scenario = "WORLD_HUMAN_AA_COFFEE"          },
        { fromHour =  8, scenario = "WANDER"                         },
        { fromHour = 10, scenario = "WORLD_HUMAN_DRINKING"           },
        { fromHour = 12, scenario = "WANDER"                         },
        { fromHour = 18, scenario = "WORLD_HUMAN_DRINKING"           },
        { fromHour = 20, scenario = "WANDER"                         },
        { fromHour = 22, scenario = "WORLD_HUMAN_LEAN_WALL_SMOKING"  },
    },
    Dolly = {
        { fromHour =  0, scenario = "WORLD_HUMAN_SMOKING"               },
        { fromHour =  7, scenario = "WORLD_HUMAN_LOOK_AT_PHONE_GROUND"  },
        { fromHour =  9, scenario = "WANDER"                            },
        { fromHour = 11, scenario = "WORLD_HUMAN_LEAN_WALL_SMOKING"     },
        { fromHour = 13, scenario = "WANDER"                            },
        { fromHour = 19, scenario = "WORLD_HUMAN_LOOK_AT_PHONE_GROUND"  },
        { fromHour = 21, scenario = "WANDER"                            },
        { fromHour = 23, scenario = "WORLD_HUMAN_SMOKING"               },
    },
    Wade = {
        { fromHour =  0, scenario = "WORLD_HUMAN_AA_COFFEE"         },
        { fromHour =  6, scenario = "WANDER"                        },
        { fromHour =  8, scenario = "WORLD_HUMAN_BINOCULARS"        },
        { fromHour = 10, scenario = "WANDER"                        },
        { fromHour = 12, scenario = "WORLD_HUMAN_SMOKING"           },
        { fromHour = 14, scenario = "WANDER"                        },
        { fromHour = 18, scenario = "WORLD_HUMAN_GUARD_STAND"       },
        { fromHour = 20, scenario = "WANDER"                        },
        { fromHour = 22, scenario = "WORLD_HUMAN_BINOCULARS"        },
    },
    Sheryl = {
        { fromHour =  0, scenario = "WORLD_HUMAN_AA_COFFEE"         },
        { fromHour =  6, scenario = "WANDER"                        },
        { fromHour =  8, scenario = "WORLD_HUMAN_GUARD_STAND"       },
        { fromHour = 10, scenario = "WANDER"                        },
        { fromHour = 12, scenario = "WORLD_HUMAN_AA_COFFEE"         },
        { fromHour = 14, scenario = "WANDER"                        },
        { fromHour = 18, scenario = "WORLD_HUMAN_GUARD_STAND"       },
        { fromHour = 20, scenario = "WANDER"                        },
        { fromHour = 22, scenario = "WORLD_HUMAN_SMOKING"           },
    },
}
