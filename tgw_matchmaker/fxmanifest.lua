fx_version 'cerulean'
game 'gta5'

name 'TGW Matchmaker'
description 'The Gun War Multi-1v1 Matchmaking System'
author 'TGW Development Team'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@tgw_core/config/shared.lua',
    'config/matchmaker.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/matchmaker.lua'
}

dependencies {
    'tgw_core',
    'tgw_queue',
    'es_extended',
    'oxmysql'
}

exports {
    'CreateMatch',
    'PairNow',
    'GetMatchmakingStats',
    'ForceMatch',
    'GetCompatiblePlayers'
}