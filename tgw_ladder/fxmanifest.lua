fx_version 'cerulean'
game 'gta5'

name 'TGW Ladder'
description 'The Gun War Multi-1v1 Ladder and Progression System'
author 'TGW Development Team'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@tgw_core/config/shared.lua',
    'config/ladder.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/ladder.lua'
}

client_scripts {
    'client/ladder.lua'
}

dependencies {
    'tgw_core',
    'tgw_rating',
    'es_extended',
    'oxmysql'
}

exports {
    'GetPlayerLevel',
    'GetPlayerXP',
    'AddXP',
    'GetLevelInfo',
    'GetLeaderboard',
    'GetPlayerStats',
    'CalculateNextLevel',
    'GetLevelRewards'
}