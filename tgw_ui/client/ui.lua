-- =====================================================
-- TGW UI CLIENT - HUD AND USER INTERFACE SYSTEM
-- =====================================================
-- Purpose: Comprehensive HUD and UI system for TGW
-- Dependencies: tgw_core
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']

-- UI client state
local UIPreferences = {}
local HUDEnabled = true
local HUDOpacity = 1.0
local CurrentTheme = 'default'

-- HUD data
local HUDData = {
    health = {current = 200, max = 200, armor = 0},
    weapon = {name = 'Unarmed', ammo = 0, maxAmmo = 0},
    timer = {current = 0, max = 0, warning = false, critical = false},
    score = {player = '', opponent = '', roundType = '', arena = 0},
    round = {active = false, state = 'inactive'}
}

-- Notification system
local ActiveNotifications = {}
local NotificationQueue = {}

-- Menu system
local MenuStack = {}
local CurrentMenu = nil

-- =====================================================
-- INITIALIZATION
-- =====================================================

CreateThread(function()
    while not ESX do
        ESX = exports['tgw_core']:GetESX()
        Wait(100)
    end

    RegisterEventHandlers()
    RegisterCommands()
    InitializeUI()
    StartUISystem()

    print('^2[TGW-UI CLIENT]^7 UI and HUD system initialized')
end)

function RegisterEventHandlers()
    -- UI system events
    RegisterNetEvent('tgw:ui:initialize', function(initData)
        InitializeUIFromServer(initData)
    end)

    RegisterNetEvent('tgw:ui:update', function(updateType, data)
        HandleUIUpdate(updateType, data)
    end)

    RegisterNetEvent('tgw:ui:notification', function(notificationData)
        ShowNotification(notificationData)
    end)

    RegisterNetEvent('tgw:ui:preferencesData', function(preferences)
        LoadUIPreferences(preferences)
    end)

    RegisterNetEvent('tgw:ui:preferencesUpdated', function(preferences)
        ApplyUIPreferences(preferences)
    end)

    -- Game state events
    RegisterNetEvent('tgw:round:freezeStart', function(freezeTime, opponentIdentifier)
        HandleRoundFreeze(freezeTime, opponentIdentifier)
    end)

    RegisterNetEvent('tgw:round:started', function(matchId, roundTime)
        HandleRoundStarted(matchId, roundTime)
    end)

    RegisterNetEvent('tgw:round:timer', function(remainingTime)
        UpdateRoundTimer(remainingTime)
    end)

    RegisterNetEvent('tgw:round:result', function(resultData)
        HandleRoundResult(resultData)
    end)

    RegisterNetEvent('tgw:ladder:xpGained', function(amount, reason, newLevel, newXP)
        ShowXPGain(amount, reason, newLevel, newXP)
    end)

    RegisterNetEvent('tgw:rating:updated', function(updateData)
        ShowRatingUpdate(updateData)
    end)

    -- Queue events
    RegisterNetEvent('tgw:queue:joined', function(queueData)
        ShowQueueStatus(queueData)
    end)

    RegisterNetEvent('tgw:queue:matchFound', function(matchData)
        ShowMatchFound(matchData)
    end)
end

function RegisterCommands()
    -- HUD toggle commands
    RegisterCommand('toggle_hud', function(source, args, rawCommand)
        ToggleHUD()
    end, false)

    RegisterCommand('hud_opacity', function(source, args, rawCommand)
        if args[1] then
            local opacity = tonumber(args[1])
            if opacity and opacity >= 0 and opacity <= 1 then
                SetHUDOpacity(opacity)
                TGWCore.ShowTGWNotification(string.format('HUD opacity set to %.1f', opacity), 'info', 2000)
            end
        end
    end, false)

    RegisterCommand('ui_theme', function(source, args, rawCommand)
        if args[1] and UIConfig.Themes[args[1]] then
            SetUITheme(args[1])
            TGWCore.ShowTGWNotification(string.format('UI theme changed to %s', args[1]), 'info', 2000)
        end
    end, false)

    RegisterCommand('clear_notifications', function(source, args, rawCommand)
        ClearAllNotifications()
        TGWCore.ShowTGWNotification('Notifications cleared', 'info', 1500)
    end, false)
end

-- =====================================================
-- UI INITIALIZATION
-- =====================================================

function InitializeUI()
    -- Request preferences from server
    TriggerServerEvent('tgw:ui:requestPreferences')

    -- Initialize default HUD data
    ResetHUDData()

    -- Hide default GTA HUD elements if configured
    if UIConfig.HUD.hideDefaultHUD then
        HideDefaultHUDElements()
    end
end

function InitializeUIFromServer(initData)
    if initData.preferences then
        LoadUIPreferences(initData.preferences)
    end

    if initData.config then
        -- Apply server config overrides
        ApplyServerConfig(initData.config)
    end
end

function LoadUIPreferences(preferences)
    UIPreferences = preferences

    -- Apply preferences
    HUDEnabled = preferences.hudEnabled or true
    HUDOpacity = preferences.hudOpacity or 1.0
    CurrentTheme = preferences.theme or 'default'

    -- Apply accessibility settings
    if preferences.accessibilitySettings then
        ApplyAccessibilitySettings(preferences.accessibilitySettings)
    end
end

function ApplyServerConfig(config)
    -- Apply server-side configuration overrides
    -- This allows servers to enforce certain UI settings
end

-- =====================================================
-- HUD SYSTEM
-- =====================================================

function StartUISystem()
    CreateThread(function()
        while true do
            Wait(UIConfig.Performance.updateInterval or 16)

            if HUDEnabled then
                -- Update HUD data
                UpdateHUDData()

                -- Draw HUD components
                DrawHUD()
            end

            -- Process notifications
            ProcessNotifications()

            -- Draw current menu
            if CurrentMenu then
                DrawCurrentMenu()
            end
        end
    end)
end

function UpdateHUDData()
    local playerPed = PlayerPedId()

    -- Update health and armor
    HUDData.health.current = GetEntityHealth(playerPed)
    HUDData.health.max = GetEntityMaxHealth(playerPed)
    HUDData.health.armor = GetPedArmour(playerPed)

    -- Update weapon data
    local currentWeapon = GetSelectedPedWeapon(playerPed)
    if currentWeapon and currentWeapon ~= 0 then
        HUDData.weapon.name = GetWeaponDisplayName(currentWeapon)
        HUDData.weapon.ammo = GetAmmoInPedWeapon(playerPed, currentWeapon)
        HUDData.weapon.maxAmmo = GetMaxAmmoInClip(playerPed, currentWeapon, true)
    else
        HUDData.weapon.name = 'Unarmed'
        HUDData.weapon.ammo = 0
        HUDData.weapon.maxAmmo = 0
    end
end

function DrawHUD()
    -- Draw health component
    if UIConfig.Health.enabled then
        DrawHealthComponent()
    end

    -- Draw weapon component
    if UIConfig.Weapon.enabled then
        DrawWeaponComponent()
    end

    -- Draw timer component
    if UIConfig.Timer.enabled and HUDData.timer.max > 0 then
        DrawTimerComponent()
    end

    -- Draw score component
    if UIConfig.Score.enabled and HUDData.round.active then
        DrawScoreComponent()
    end
end

function DrawHealthComponent()
    local config = UIConfig.Health
    local health = HUDData.health

    local x = config.position.x
    local y = config.position.y
    local width = config.size.width
    local height = config.size.height

    -- Calculate health percentage
    local healthPercent = health.current / health.max
    local armorPercent = health.armor / 100

    -- Determine colors
    local healthColor = config.colors.health
    if healthPercent <= (config.criticalHealthThreshold / 100) then
        healthColor = config.colors.criticalHealth
    elseif healthPercent <= (config.lowHealthThreshold / 100) then
        healthColor = config.colors.lowHealth
    end

    -- Draw background
    DrawRect(x + width/2, y + height/2, width, height, 0, 0, 0, 150 * HUDOpacity)

    -- Draw health bar
    local healthWidth = width * healthPercent
    if healthWidth > 0 then
        DrawRect(x + healthWidth/2, y + height/2, healthWidth, height * 0.6,
                healthColor[1], healthColor[2], healthColor[3], 255 * HUDOpacity)
    end

    -- Draw armor bar
    if armorPercent > 0 then
        local armorWidth = width * armorPercent
        local armorColor = config.colors.armor
        DrawRect(x + armorWidth/2, y + height/2 + height * 0.3, armorWidth, height * 0.4,
                armorColor[1], armorColor[2], armorColor[3], 255 * HUDOpacity)
    end

    -- Draw text if enabled
    if config.showNumbers then
        SetTextFont(4)
        SetTextProportional(true)
        SetTextScale(0.3, 0.3)
        SetTextColour(255, 255, 255, 255 * HUDOpacity)
        SetTextEntry('STRING')
        AddTextComponentString(string.format('%d/%d', health.current, health.max))
        DrawText(x, y - 0.02)
    end
end

function DrawWeaponComponent()
    local config = UIConfig.Weapon
    local weapon = HUDData.weapon

    local x = config.position.x
    local y = config.position.y

    -- Draw weapon name
    if config.showWeaponName then
        SetTextFont(4)
        SetTextProportional(true)
        SetTextScale(0.4, 0.4)
        SetTextColour(255, 255, 255, 255 * HUDOpacity)
        SetTextRightJustify(true)
        SetTextEntry('STRING')
        AddTextComponentString(weapon.name)
        DrawText(x, y)
    end

    -- Draw ammo count
    if config.showAmmoCount and weapon.ammo > 0 then
        local ammoColor = config.colors.normal
        if weapon.ammo <= config.lowAmmoThreshold then
            ammoColor = config.colors.lowAmmo
        end
        if weapon.ammo == 0 then
            ammoColor = config.colors.noAmmo
        end

        SetTextFont(4)
        SetTextProportional(true)
        SetTextScale(0.5, 0.5)
        SetTextColour(ammoColor[1], ammoColor[2], ammoColor[3], 255 * HUDOpacity)
        SetTextRightJustify(true)
        SetTextEntry('STRING')
        AddTextComponentString(string.format('%d', weapon.ammo))
        DrawText(x, y + 0.03)
    end
end

function DrawTimerComponent()
    local config = UIConfig.Timer
    local timer = HUDData.timer

    local x = config.position.x
    local y = config.position.y

    -- Format time
    local minutes = math.floor(timer.current / 60)
    local seconds = math.floor(timer.current % 60)
    local timeText = string.format('%02d:%02d', minutes, seconds)

    -- Determine color
    local timerColor = config.colors.normal
    if timer.critical then
        timerColor = config.colors.critical
    elseif timer.warning then
        timerColor = config.colors.warning
    end

    -- Draw background if enabled
    if config.showBackground then
        local bgColor = config.colors.background
        DrawRect(x, y, 0.15, 0.06, bgColor[1], bgColor[2], bgColor[3], bgColor[4] * HUDOpacity)
    end

    -- Draw timer text
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.8, 0.8)
    SetTextColour(timerColor[1], timerColor[2], timerColor[3], 255 * HUDOpacity)
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(timeText)
    DrawText(x, y - 0.015)

    -- Flash effect for critical time
    if timer.critical and config.flashOnCritical then
        local alpha = math.floor((math.sin(GetGameTimer() / 200) * 0.5 + 0.5) * 100)
        DrawRect(x, y, 0.15, 0.06, 255, 0, 0, alpha * HUDOpacity)
    end
end

function DrawScoreComponent()
    local config = UIConfig.Score
    local score = HUDData.score

    local x = config.position.x
    local y = config.position.y

    -- Draw arena info
    if config.showArenaNumber and score.arena > 0 then
        SetTextFont(4)
        SetTextProportional(true)
        SetTextScale(0.35, 0.35)
        SetTextColour(255, 255, 255, 255 * HUDOpacity)
        SetTextEntry('STRING')
        AddTextComponentString(string.format('Arena %d', score.arena))
        DrawText(x, y)
        y = y + 0.025
    end

    -- Draw round type
    if config.showRoundType and score.roundType ~= '' then
        SetTextFont(4)
        SetTextProportional(true)
        SetTextScale(0.4, 0.4)
        SetTextColour(config.colors.highlight[1], config.colors.highlight[2], config.colors.highlight[3], 255 * HUDOpacity)
        SetTextEntry('STRING')
        AddTextComponentString(score.roundType:upper())
        DrawText(x, y)
        y = y + 0.03
    end

    -- Draw player vs opponent
    if config.showPlayerNames and score.player ~= '' and score.opponent ~= '' then
        SetTextFont(4)
        SetTextProportional(true)
        SetTextScale(0.35, 0.35)
        SetTextColour(config.colors.player[1], config.colors.player[2], config.colors.player[3], 255 * HUDOpacity)
        SetTextEntry('STRING')
        AddTextComponentString(string.format('%s vs %s', score.player, score.opponent))
        DrawText(x, y)
    end
end

-- =====================================================
-- NOTIFICATION SYSTEM
-- =====================================================

function ShowNotification(notificationData)
    local notification = {
        id = notificationData.id or GenerateNotificationId(),
        type = notificationData.type or 'info',
        message = notificationData.message or '',
        duration = notificationData.duration or UIConfig.Notifications.defaultDuration,
        timestamp = GetGameTimer(),
        fadeIn = true,
        alpha = 0
    }

    table.insert(NotificationQueue, notification)

    -- Play sound if enabled
    if UIConfig.Audio.notificationSounds then
        PlayNotificationSound(notification.type)
    end
end

function ProcessNotifications()
    local currentTime = GetGameTimer()
    local config = UIConfig.Notifications

    -- Move notifications from queue to active
    while #NotificationQueue > 0 and #ActiveNotifications < config.maxNotifications do
        table.insert(ActiveNotifications, table.remove(NotificationQueue, 1))
    end

    -- Update and draw notifications
    for i = #ActiveNotifications, 1, -1 do
        local notification = ActiveNotifications[i]
        local age = currentTime - notification.timestamp

        -- Handle fade in/out
        if notification.fadeIn and age > config.fadeInTime then
            notification.fadeIn = false
            notification.alpha = 1
        elseif notification.fadeIn then
            notification.alpha = age / config.fadeInTime
        elseif age > notification.duration - config.fadeOutTime then
            notification.alpha = 1 - ((age - (notification.duration - config.fadeOutTime)) / config.fadeOutTime)
        end

        -- Remove expired notifications
        if age > notification.duration then
            table.remove(ActiveNotifications, i)
        else
            DrawNotification(notification, i - 1)
        end
    end
end

function DrawNotification(notification, index)
    local config = UIConfig.Notifications
    local typeConfig = UIConfig.NotificationTypes[notification.type]

    if not typeConfig then
        typeConfig = UIConfig.NotificationTypes.info
    end

    local x = config.position.x
    local y = config.position.y + (index * config.spacing)
    local width = config.width
    local height = config.height

    local alpha = notification.alpha * HUDOpacity

    -- Draw background
    local bg = typeConfig.backgroundColor
    DrawRect(x, y, width, height, bg[1], bg[2], bg[3], bg[4] * alpha)

    -- Draw border
    local border = typeConfig.borderColor
    DrawRect(x - width/2, y, 0.003, height, border[1], border[2], border[3], border[4] * alpha)

    -- Draw text
    local textColor = typeConfig.textColor
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.35, 0.35)
    SetTextColour(textColor[1], textColor[2], textColor[3], textColor[4] * alpha)
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString(notification.message)
    DrawText(x, y - 0.015)
end

function PlayNotificationSound(notificationType)
    local typeConfig = UIConfig.NotificationTypes[notificationType]
    if typeConfig and typeConfig.sound then
        PlaySoundFrontend(-1, typeConfig.sound, 'HUD_FRONTEND_DEFAULT_SOUNDSET', 1)
    end
end

function ClearAllNotifications()
    ActiveNotifications = {}
    NotificationQueue = {}
end

-- =====================================================
-- GAME STATE HANDLERS
-- =====================================================

function HandleRoundFreeze(freezeTime, opponentIdentifier)
    -- Update HUD for freeze phase
    HUDData.round.active = true
    HUDData.round.state = 'freeze'
    HUDData.timer.current = freezeTime
    HUDData.timer.max = freezeTime

    -- Get opponent info
    local opponentName = GetPlayerNameByIdentifier(opponentIdentifier)
    HUDData.score.opponent = opponentName or 'Unknown'
end

function HandleRoundStarted(matchId, roundTime)
    -- Update HUD for active round
    HUDData.round.active = true
    HUDData.round.state = 'active'
    HUDData.timer.current = roundTime
    HUDData.timer.max = roundTime
    HUDData.timer.warning = false
    HUDData.timer.critical = false

    ShowNotification({
        type = 'success',
        message = 'Round Started!',
        duration = 2000
    })
end

function UpdateRoundTimer(remainingTime)
    HUDData.timer.current = remainingTime

    -- Update warning/critical states
    HUDData.timer.warning = remainingTime <= UIConfig.Timer.warningTime
    HUDData.timer.critical = remainingTime <= UIConfig.Timer.criticalTime
end

function HandleRoundResult(resultData)
    -- Reset round state
    HUDData.round.active = false
    HUDData.round.state = 'ended'

    -- Show result notification
    local resultType = 'info'
    local resultMessage = 'Round Ended'

    if resultData.result == 'win' then
        resultType = 'success'
        resultMessage = '🏆 Victory!'
    elseif resultData.result == 'lose' then
        resultType = 'error'
        resultMessage = '💀 Defeat'
    else
        resultMessage = '🤝 Draw'
    end

    ShowNotification({
        type = resultType,
        message = resultMessage,
        duration = 4000
    })

    -- Show detailed results if enabled
    if UIConfig.Results.enabled then
        ShowResultScreen(resultData)
    end
end

function ShowXPGain(amount, reason, newLevel, newXP)
    local message = string.format('+%d XP (%s)', amount, FormatXPReason(reason))

    ShowNotification({
        type = 'success',
        message = message,
        duration = 3000
    })

    -- Check for level up
    if newLevel > (HUDData.player.level or 1) then
        ShowNotification({
            type = 'success',
            message = string.format('🎉 Level Up! Level %d', newLevel),
            duration = 5000
        })
    end

    HUDData.player = HUDData.player or {}
    HUDData.player.level = newLevel
    HUDData.player.xp = newXP
end

function ShowRatingUpdate(updateData)
    local change = updateData.change
    local changeText = change > 0 and string.format('+%d', change) or tostring(change)
    local notifType = change > 0 and 'success' or 'error'

    ShowNotification({
        type = notifType,
        message = string.format('Rating: %s (%d → %d)', changeText, updateData.oldRating, updateData.newRating),
        duration = 4000
    })
end

function ShowQueueStatus(queueData)
    ShowNotification({
        type = 'info',
        message = 'Joined matchmaking queue',
        duration = 3000
    })
end

function ShowMatchFound(matchData)
    ShowNotification({
        type = 'success',
        message = 'Match found! Preparing arena...',
        duration = 3000
    })
end

-- =====================================================
-- RESULT SCREEN SYSTEM
-- =====================================================

function ShowResultScreen(resultData)
    -- This would show a detailed result overlay
    -- For now, just enhanced notifications
    CreateThread(function()
        Wait(1000) -- Delay for dramatic effect

        -- Show match stats
        if resultData.stats then
            local statsMessage = string.format(
                'Duration: %02d:%02d | Accuracy: %.1f%%',
                math.floor(resultData.duration / 60),
                math.floor(resultData.duration % 60),
                (resultData.stats.accuracy or 0) * 100
            )

            ShowNotification({
                type = 'info',
                message = statsMessage,
                duration = 5000
            })
        end
    end)
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function ResetHUDData()
    HUDData = {
        health = {current = 200, max = 200, armor = 0},
        weapon = {name = 'Unarmed', ammo = 0, maxAmmo = 0},
        timer = {current = 0, max = 0, warning = false, critical = false},
        score = {player = GetPlayerName(PlayerId()), opponent = '', roundType = '', arena = 0},
        round = {active = false, state = 'inactive'},
        player = {level = 1, xp = 0}
    }
end

function HideDefaultHUDElements()
    CreateThread(function()
        while true do
            Wait(0)

            if HUDEnabled then
                -- Hide default GTA HUD elements
                HideHudComponentThisFrame(1)  -- Wanted Stars
                HideHudComponentThisFrame(2)  -- Weapon Icon
                HideHudComponentThisFrame(3)  -- Cash
                HideHudComponentThisFrame(4)  -- MP Cash
                HideHudComponentThisFrame(6)  -- Vehicle Name
                HideHudComponentThisFrame(7)  -- Area Name
                HideHudComponentThisFrame(8)  -- Vehicle Class
                HideHudComponentThisFrame(9)  -- Street Name
                HideHudComponentThisFrame(13) -- Cash Change
                HideHudComponentThisFrame(17) -- Save Game
                HideHudComponentThisFrame(20) -- Weapon Stats
            end
        end
    end)
end

function ToggleHUD()
    HUDEnabled = not HUDEnabled

    -- Update preferences
    UIPreferences.hudEnabled = HUDEnabled
    TriggerServerEvent('tgw:ui:updatePreferences', UIPreferences)

    ShowNotification({
        type = 'info',
        message = string.format('HUD %s', HUDEnabled and 'Enabled' or 'Disabled'),
        duration = 2000
    })
end

function SetHUDOpacity(opacity)
    HUDOpacity = math.max(0, math.min(1, opacity))

    -- Update preferences
    UIPreferences.hudOpacity = HUDOpacity
    TriggerServerEvent('tgw:ui:updatePreferences', UIPreferences)
end

function SetUITheme(themeName)
    if UIConfig.Themes[themeName] then
        CurrentTheme = themeName

        -- Update preferences
        UIPreferences.theme = themeName
        TriggerServerEvent('tgw:ui:updatePreferences', UIPreferences)

        -- Apply theme changes
        ApplyTheme(themeName)
    end
end

function ApplyTheme(themeName)
    local theme = UIConfig.Themes[themeName]
    if not theme then
        return
    end

    -- Update UI colors based on theme
    -- This would modify the color configurations
    print(string.format('^2[TGW-UI]^7 Applied theme: %s', themeName))
end

function ApplyAccessibilitySettings(settings)
    if settings.colorBlindSupport then
        -- Apply color blind friendly palette
        ApplyColorBlindPalette()
    end

    if settings.highContrast then
        -- Increase contrast
        HUDOpacity = math.min(1.0, HUDOpacity * 1.2)
    end

    if settings.largeText then
        -- Increase text scale
        -- This would modify text scaling throughout the UI
    end

    if settings.reducedMotion then
        -- Disable animations
        UIConfig.Animations.enabled = false
    end
end

function ApplyColorBlindPalette()
    local palette = UIConfig.ColorBlindPalette

    -- Replace standard colors with color blind friendly ones
    UIConfig.Health.colors.health = palette.green
    UIConfig.Health.colors.lowHealth = palette.yellow
    UIConfig.Health.colors.criticalHealth = palette.red

    print('^2[TGW-UI]^7 Applied color blind friendly palette')
end

function GenerateNotificationId()
    return string.format('%d_%d', GetGameTimer(), math.random(1000, 9999))
end

function GetPlayerNameByIdentifier(identifier)
    -- This would normally get player name from server
    return identifier:sub(-8) -- Simplified
end

function FormatXPReason(reason)
    local reasonMap = {
        match_win = 'Match Victory',
        match_loss = 'Match Participation',
        level_reward = 'Level Reward',
        achievement = 'Achievement'
    }

    return reasonMap[reason] or reason:gsub('_', ' '):gsub('^%l', string.upper)
end

function HandleUIUpdate(updateType, data)
    if updateType == 'round_started' then
        HandleRoundStarted(data.matchId, data.timer)
        if data.opponent then
            HUDData.score.opponent = data.opponent.name
        end
        if data.roundType then
            HUDData.score.roundType = data.roundType
        end
        if data.arenaId then
            HUDData.score.arena = data.arenaId
        end

    elseif updateType == 'round_ended' then
        HandleRoundResult(data)

    elseif updateType == 'xp_gained' then
        ShowXPGain(data.amount, data.reason, data.newLevel, data.newXP)

    elseif updateType == 'rating_updated' then
        ShowRatingUpdate(data)
    end
end

-- =====================================================
-- MENU SYSTEM (BASIC)
-- =====================================================

function DrawCurrentMenu()
    -- Basic menu rendering
    -- This would be expanded for a full menu system
    if not CurrentMenu then
        return
    end

    local config = UIConfig.Menu
    local x = 0.5
    local y = 0.3
    local width = config.width
    local height = config.itemHeight * #CurrentMenu.items

    -- Draw menu background
    DrawRect(x, y + height/2, width, height,
        config.backgroundColor[1], config.backgroundColor[2],
        config.backgroundColor[3], config.backgroundColor[4] * HUDOpacity)

    -- Draw menu items
    for i, item in ipairs(CurrentMenu.items) do
        local itemY = y + (i - 1) * config.itemHeight
        local textColor = config.textColor

        if i == CurrentMenu.selectedIndex then
            textColor = config.selectedColor
        end

        SetTextFont(config.fontFamily)
        SetTextProportional(true)
        SetTextScale(config.fontSize, config.fontSize)
        SetTextColour(textColor[1], textColor[2], textColor[3], textColor[4] * HUDOpacity)
        SetTextCentre(true)
        SetTextEntry('STRING')
        AddTextComponentString(item.label)
        DrawText(x, itemY)
    end
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('ShowUI', function(uiType, data)
    -- Generic UI display function
    if uiType == 'notification' then
        ShowNotification(data)
    end
end)

exports('HideUI', function(uiType)
    -- Generic UI hiding function
    if uiType == 'all' then
        HUDEnabled = false
        ClearAllNotifications()
    end
end)

exports('UpdateHUD', function(component, data)
    -- Update specific HUD components
    if component == 'timer' then
        UpdateRoundTimer(data.time)
    elseif component == 'health' then
        -- Health updates are automatic
    end
end)

exports('ShowNotification', ShowNotification)

exports('ToggleHUD', ToggleHUD)

exports('SetHUDOpacity', SetHUDOpacity)

exports('GetHUDData', function()
    return HUDData
end)

exports('IsHUDEnabled', function()
    return HUDEnabled
end)

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Save UI preferences
        if UIPreferences then
            TriggerServerEvent('tgw:ui:updatePreferences', UIPreferences)
        end

        -- Clear UI elements
        ClearAllNotifications()
        CurrentMenu = nil
    end
end)