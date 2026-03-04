fx_version 'cerulean'
game 'gta5'

author 'StabCityAI'
description 'StabCity AI - Intelligent NPCs for QBCore'
version '2.0.0'

shared_scripts {
    '@qb-core/shared/locale.lua',
    'config.lua',
    'shared/*.lua',
}

client_scripts {
    'client/main.lua',
    'client/interaction.lua',
    'client/events.lua',
    'client/a2a.lua',
}

server_scripts {
    'server/main.lua',
    'server/actions.lua',
}

ui_page 'ui/index.html'

files {
    'ui/index.html',
}

dependencies {
    'qb-core',
    'qb-target',
    'qb-inventory',
    'qb-input',
}
