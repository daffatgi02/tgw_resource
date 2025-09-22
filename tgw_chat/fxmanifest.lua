fx_version 'cerulean'
game 'gta5'

name 'TGW Chat'
description 'The Gun War Multi-1v1 Arena-Specific Chat System'
author 'TGW Development Team'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@tgw_core/config/shared.lua',
    'config/chat.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/chat.lua'
}

client_scripts {
    'client/chat.lua'
}

dependencies {
    'tgw_core',
    'tgw_arena',
    'es_extended',
    'oxmysql'
}

exports {
    'SendArenaMessage',
    'BroadcastToArena',
    'MutePlayer',
    'UnmutePlayer',
    'GetChatHistory',
    'FilterMessage',
    'IsPlayerMuted'
}