fx_version 'cerulean'
game 'gta5'

name 'TGW Core'
description 'The Gun War Multi-1v1 Core Framework - ESX Integration and Shared Utilities'
author 'TGW Development Team'
version '1.0.0'

lua54 'yes'

shared_scripts {
    'config/shared.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

client_scripts {
    'client/main.lua'
}

dependencies {
    'es_extended',
    'oxmysql'
}

exports {
    'GetESX',
    'GetTGWConfig',
    'IsPlayerInTGW',
    'LogTGWEvent',
    'ValidateIdentifier',
    'FormatPlayerName',
    'GetPlayerTGWData',
    'SendTGWNotification'
}