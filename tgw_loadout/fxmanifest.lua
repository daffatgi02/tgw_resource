fx_version 'cerulean'
game 'gta5'

name 'TGW Loadout'
description 'The Gun War Multi-1v1 Loadout Management System'
author 'TGW Development Team'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@tgw_core/config/shared.lua',
    'config/loadout.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/loadout.lua'
}

client_scripts {
    'client/loadout.lua'
}

dependencies {
    'tgw_core',
    'tgw_round',
    'es_extended',
    'oxmysql'
}

exports {
    'ApplyLoadout',
    'RemoveLoadout',
    'GetLoadoutConfig',
    'ValidateLoadout',
    'GetPlayerLoadout',
    'SetPlayerPreference'
}