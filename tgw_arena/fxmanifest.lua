fx_version 'cerulean'
game 'gta5'

name 'TGW Arena'
description 'The Gun War Multi-1v1 Arena Management System'
author 'TGW Development Team'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@tgw_core/config/shared.lua',
    'config/arena.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/arena.lua'
}

client_scripts {
    'client/zone.lua'
}

dependencies {
    'tgw_core',
    'es_extended',
    'oxmysql'
}

exports {
    'GetFreeArena',
    'AssignPlayersToArena',
    'GetArenaData',
    'IsArenaAvailable',
    'TeleportToArena',
    'SetPlayerBucket',
    'GetPlayerArena',
    'GetArenaPlayers',
    'CleanupArena'
}