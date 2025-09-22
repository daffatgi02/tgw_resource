fx_version 'cerulean'
game 'gta5'

name 'TGW Integrity'
description 'The Gun War Multi-1v1 Anti-Cheat and Integrity Monitoring System'
author 'TGW Development Team'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@tgw_core/config/shared.lua',
    'config/integrity.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/integrity.lua'
}

client_scripts {
    'client/integrity.lua'
}

dependencies {
    'tgw_core',
    'tgw_round',
    'tgw_rating',
    'es_extended',
    'oxmysql'
}

exports {
    'ReportSuspiciousActivity',
    'ValidatePlayerAction',
    'GetPlayerTrustScore',
    'CheckPlayerIntegrity',
    'FlagPlayer',
    'GetViolationHistory'
}