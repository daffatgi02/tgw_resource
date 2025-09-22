fx_version 'cerulean'
game 'gta5'

name 'TGW Rating'
description 'The Gun War Multi-1v1 ELO Rating and Competitive Ranking System'
author 'TGW Development Team'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@tgw_core/config/shared.lua',
    'config/rating.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/rating.lua'
}

client_scripts {
    'client/rating.lua'
}

dependencies {
    'tgw_core',
    'tgw_ladder',
    'es_extended',
    'oxmysql'
}

exports {
    'GetPlayerRating',
    'CalculateRatingChange',
    'UpdateRating',
    'GetRatingHistory',
    'GetCompetitiveRank',
    'GetSeasonRating',
    'RecalibrateRating'
}