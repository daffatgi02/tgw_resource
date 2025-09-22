fx_version 'cerulean'
game 'gta5'

name 'TGW Round'
description 'The Gun War Multi-1v1 Round Controller System'
author 'TGW Development Team'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@tgw_core/config/shared.lua',
    'config/round.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/round.lua'
}

client_scripts {
    'client/round.lua'
}

dependencies {
    'tgw_core',
    'tgw_arena',
    'es_extended',
    'oxmysql'
}

exports {
    'StartMatch',
    'EndMatch',
    'ForceEnd',
    'GetMatchStatus',
    'ReportHit',
    'ReportKill',
    'CheckAFK',
    'GetRoundState',
    'GetRoundTime'
}