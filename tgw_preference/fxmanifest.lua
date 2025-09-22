fx_version 'cerulean'
game 'gta5'

name 'TGW Preference'
description 'The Gun War Multi-1v1 Player Preference System'
author 'TGW Development Team'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@tgw_core/config/shared.lua',
    'config/preference.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/preference.lua'
}

client_scripts {
    'client/preference.lua'
}

dependencies {
    'tgw_core',
    'tgw_loadout',
    'es_extended',
    'oxmysql'
}

exports {
    'GetPlayerPreference',
    'SetPlayerPreference',
    'GetAllPreferences',
    'ResetPreferences',
    'ValidatePreference',
    'GetDefaultPreferences'
}