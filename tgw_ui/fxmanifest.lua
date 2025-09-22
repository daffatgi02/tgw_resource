fx_version 'cerulean'
game 'gta5'

name 'TGW UI'
description 'The Gun War Multi-1v1 User Interface and HUD System'
author 'TGW Development Team'
version '1.0.0'

lua54 'yes'

shared_scripts {
    '@tgw_core/config/shared.lua',
    'config/ui.lua'
}

server_scripts {
    'server/ui.lua'
}

client_scripts {
    'client/ui.lua'
}

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/assets/*.png',
    'html/assets/*.svg'
}

ui_page 'html/index.html'

dependencies {
    'tgw_core',
    'tgw_round',
    'tgw_ladder',
    'tgw_rating',
    'tgw_queue',
    'es_extended'
}

exports {
    'ShowUI',
    'HideUI',
    'UpdateHUD',
    'ShowNotification',
    'ToggleHUD',
    'SetHUDOpacity'
}