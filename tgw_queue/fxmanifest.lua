fx_version 'cerulean'
game 'gta5'

name 'TGW Queue'
description 'The Gun War Multi-1v1 Queue Management System'
author 'TGW Development Team'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@tgw_core/config/shared.lua',
    'config/queue.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/queue.lua'
}

client_scripts {
    'client/ui.lua'
}

dependencies {
    'tgw_core',
    'es_extended',
    'oxmysql'
}

exports {
    'JoinQueue',
    'LeaveQueue',
    'GetQueuePosition',
    'GetQueueStatus',
    'IsPlayerInQueue',
    'StartSpectate',
    'StopSpectate',
    'GetSpectateTarget'
}