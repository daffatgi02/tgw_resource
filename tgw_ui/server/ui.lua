-- =====================================================
-- TGW UI SERVER - UI DATA MANAGEMENT
-- =====================================================
-- Purpose: Manage UI data synchronization and preferences
-- Dependencies: tgw_core, es_extended
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']

-- UI server state
local PlayerUIPreferences = {}     -- [identifier] = uiPreferences
local ActiveUIElements = {}        -- [identifier] = activeElements

-- =====================================================
-- INITIALIZATION
-- =====================================================

CreateThread(function()
    while not ESX do
        ESX = exports['tgw_core']:GetESX()
        Wait(100)
    end

    RegisterEventHandlers()
    InitializeUISystem()

    print('^2[TGW-UI SERVER]^7 UI data management system initialized')
end)

function RegisterEventHandlers()
    -- UI preference events
    RegisterNetEvent('tgw:ui:updatePreferences', function(preferences)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            UpdatePlayerUIPreferences(xPlayer.identifier, preferences)
        end
    end)

    RegisterNetEvent('tgw:ui:requestPreferences', function()
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            SendUIPreferences(xPlayer.identifier, src)
        end
    end)

    RegisterNetEvent('tgw:ui:syncData', function(elementType, data)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            SyncUIData(xPlayer.identifier, src, elementType, data)
        end
    end)

    -- Game state events for UI updates
    RegisterNetEvent('tgw:round:started', function(matchData)
        for _, playerData in pairs(matchData.players) do
            UpdatePlayerUI(playerData.identifier, 'round_started', matchData)
        end
    end)

    RegisterNetEvent('tgw:round:result', function(resultData)
        for _, playerData in pairs(resultData.players) do
            UpdatePlayerUI(playerData.identifier, 'round_ended', resultData)
        end
    end)

    RegisterNetEvent('tgw:ladder:xpGained', function(playerId, amount, reason)
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            UpdatePlayerUI(xPlayer.identifier, 'xp_gained', {amount = amount, reason = reason})
        end
    end)

    RegisterNetEvent('tgw:rating:updated', function(playerId, ratingData)
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            UpdatePlayerUI(xPlayer.identifier, 'rating_updated', ratingData)
        end
    end)

    -- Player connection events
    RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
        LoadPlayerUIPreferences(xPlayer.identifier)
        InitializePlayerUI(xPlayer.identifier, playerId)
    end)

    RegisterNetEvent('esx:playerDropped', function(playerId, reason)
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            SavePlayerUIPreferences(xPlayer.identifier)
            CleanupPlayerUI(xPlayer.identifier)
        end
    end)
end

-- =====================================================
-- UI PREFERENCES MANAGEMENT
-- =====================================================

function LoadPlayerUIPreferences(identifier)
    MySQL.query('SELECT ui_preferences FROM tgw_player_preferences WHERE identifier = ? AND category = ?',
        {identifier, 'ui'}, function(results)
        if results and #results > 0 then
            local success, preferences = pcall(json.decode, results[1].ui_preferences)
            if success and preferences then
                PlayerUIPreferences[identifier] = preferences
                print(string.format('^2[TGW-UI]^7 Loaded UI preferences for %s', identifier))
            else
                InitializeDefaultUIPreferences(identifier)
            end
        else
            InitializeDefaultUIPreferences(identifier)
        end
    end)
end

function InitializeDefaultUIPreferences(identifier)
    PlayerUIPreferences[identifier] = {
        hudEnabled = UIConfig.HUD.enabled,
        hudOpacity = UIConfig.HUD.opacity,
        hudScale = UIConfig.HUD.scale,
        theme = UIConfig.CurrentTheme,
        notificationsEnabled = UIConfig.Notifications.enabled,
        animationsEnabled = UIConfig.Animations.enabled,
        audioEnabled = UIConfig.Audio.enabled,
        customPositions = {},
        accessibilitySettings = {
            colorBlindSupport = false,
            highContrast = false,
            largeText = false,
            reducedMotion = false
        }
    }

    print(string.format('^2[TGW-UI]^7 Initialized default UI preferences for %s', identifier))
end

function UpdatePlayerUIPreferences(identifier, preferences)
    PlayerUIPreferences[identifier] = preferences

    -- Save to database
    SavePlayerUIPreferences(identifier)

    -- Notify client of update
    local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)
    if playerId then
        TriggerClientEvent('tgw:ui:preferencesUpdated', playerId, preferences)
    end

    print(string.format('^2[TGW-UI]^7 Updated UI preferences for %s', identifier))
end

function SavePlayerUIPreferences(identifier)
    local preferences = PlayerUIPreferences[identifier]
    if not preferences then
        return
    end

    local preferencesJson = json.encode(preferences)

    MySQL.execute([[
        INSERT INTO tgw_player_preferences (identifier, category, preference_key, preference_value, updated_at)
        VALUES (?, 'ui', 'preferences', ?, NOW())
        ON DUPLICATE KEY UPDATE preference_value = VALUES(preference_value), updated_at = VALUES(updated_at)
    ]], {identifier, preferencesJson})
end

function SendUIPreferences(identifier, playerId)
    local preferences = PlayerUIPreferences[identifier]
    if preferences then
        TriggerClientEvent('tgw:ui:preferencesData', playerId, preferences)
    end
end

-- =====================================================
-- UI DATA SYNCHRONIZATION
-- =====================================================

function SyncUIData(identifier, playerId, elementType, data)
    -- Validate and process UI data sync requests
    if elementType == 'hud_update' then
        SyncHUDData(identifier, playerId, data)
    elseif elementType == 'notification' then
        SyncNotificationData(identifier, playerId, data)
    elseif elementType == 'menu_state' then
        SyncMenuData(identifier, playerId, data)
    end
end

function SyncHUDData(identifier, playerId, data)
    -- Process HUD data updates
    if not ActiveUIElements[identifier] then
        ActiveUIElements[identifier] = {}
    end

    ActiveUIElements[identifier].hud = data
    ActiveUIElements[identifier].lastHUDUpdate = os.time()
end

function SyncNotificationData(identifier, playerId, data)
    -- Process notification data
    if data.type and data.message then
        -- Broadcast notification to other relevant players if needed
        BroadcastNotification(identifier, data)
    end
end

function SyncMenuData(identifier, playerId, data)
    -- Process menu state data
    if not ActiveUIElements[identifier] then
        ActiveUIElements[identifier] = {}
    end

    ActiveUIElements[identifier].menuState = data
end

function UpdatePlayerUI(identifier, updateType, data)
    local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)
    if not playerId then
        return
    end

    TriggerClientEvent('tgw:ui:update', playerId, updateType, data)
end

function BroadcastNotification(senderIdentifier, notificationData)
    -- Determine who should receive this notification
    local recipients = GetNotificationRecipients(senderIdentifier, notificationData)

    for _, playerId in ipairs(recipients) do
        TriggerClientEvent('tgw:ui:notification', playerId, notificationData)
    end
end

function GetNotificationRecipients(senderIdentifier, notificationData)
    local recipients = {}

    -- For now, only send to sender unless it's a global notification
    if notificationData.global then
        local players = ESX.GetPlayers()
        for _, playerId in ipairs(players) do
            table.insert(recipients, playerId)
        end
    else
        local playerId = TGWCore.GetPlayerIdByIdentifier(senderIdentifier)
        if playerId then
            table.insert(recipients, playerId)
        end
    end

    return recipients
end

-- =====================================================
-- UI ELEMENT MANAGEMENT
-- =====================================================

function InitializePlayerUI(identifier, playerId)
    ActiveUIElements[identifier] = {
        playerId = playerId,
        initialized = true,
        lastUpdate = os.time(),
        activeElements = {},
        preferences = PlayerUIPreferences[identifier]
    }

    -- Send initial UI data to client
    TriggerClientEvent('tgw:ui:initialize', playerId, {
        preferences = PlayerUIPreferences[identifier],
        config = UIConfig
    })

    print(string.format('^2[TGW-UI]^7 Initialized UI for player %s', identifier))
end

function CleanupPlayerUI(identifier)
    if ActiveUIElements[identifier] then
        ActiveUIElements[identifier] = nil
        print(string.format('^2[TGW-UI]^7 Cleaned up UI for player %s', identifier))
    end
end

-- =====================================================
-- GAME STATE INTEGRATION
-- =====================================================

function HandleRoundStarted(matchData)
    -- Send round start UI updates to players
    for _, playerData in pairs(matchData.players) do
        local playerId = TGWCore.GetPlayerIdByIdentifier(playerData.identifier)
        if playerId then
            TriggerClientEvent('tgw:ui:roundStarted', playerId, {
                opponent = GetOpponentData(playerData.identifier, matchData),
                roundType = matchData.roundType,
                arenaId = matchData.arenaId,
                timer = matchData.timer
            })
        end
    end
end

function HandleRoundEnded(resultData)
    -- Send round end UI updates to players
    for _, playerData in pairs(resultData.players) do
        local playerId = TGWCore.GetPlayerIdByIdentifier(playerData.identifier)
        if playerId then
            TriggerClientEvent('tgw:ui:roundEnded', playerId, {
                result = resultData.winner == playerData.identifier and 'win' or 'loss',
                stats = resultData.stats,
                ratingChange = resultData.ratingChanges and resultData.ratingChanges[playerData.identifier],
                xpGained = resultData.xpGained and resultData.xpGained[playerData.identifier]
            })
        end
    end
end

function GetOpponentData(playerIdentifier, matchData)
    for _, playerData in pairs(matchData.players) do
        if playerData.identifier ~= playerIdentifier then
            return {
                identifier = playerData.identifier,
                name = GetPlayerNameByIdentifier(playerData.identifier),
                rating = GetPlayerRating(playerData.identifier),
                level = GetPlayerLevel(playerData.identifier)
            }
        end
    end
    return nil
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function GetPlayerNameByIdentifier(identifier)
    local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)
    if playerId then
        return GetPlayerName(playerId)
    end
    return identifier:sub(-8)
end

function GetPlayerRating(identifier)
    local ratingExport = exports['tgw_rating']
    if ratingExport then
        return ratingExport:GetPlayerRating(identifier)
    end
    return 1200
end

function GetPlayerLevel(identifier)
    local ladderExport = exports['tgw_ladder']
    if ladderExport then
        return ladderExport:GetPlayerLevel(identifier)
    end
    return 1
end

function InitializeUISystem()
    -- Load UI preferences for active players
    local players = ESX.GetPlayers()
    for _, playerId in ipairs(players) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            LoadPlayerUIPreferences(xPlayer.identifier)
            InitializePlayerUI(xPlayer.identifier, playerId)
        end
    end
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('UpdatePlayerUI', UpdatePlayerUI)

exports('BroadcastNotification', function(notificationData)
    BroadcastNotification('system', notificationData)
end)

exports('GetPlayerUIPreferences', function(identifier)
    return PlayerUIPreferences[identifier]
end)

exports('SetPlayerUIPreference', function(identifier, key, value)
    if PlayerUIPreferences[identifier] then
        PlayerUIPreferences[identifier][key] = value
        SavePlayerUIPreferences(identifier)
        return true
    end
    return false
end)

-- =====================================================
-- ADMIN COMMANDS
-- =====================================================

RegisterCommand('tgw_ui_stats', function(source, args, rawCommand)
    if source == 0 then -- Console only
        print('^2[TGW-UI STATS]^7')
        print(string.format('  Active UI Elements: %d', GetActiveUICount()))
        print(string.format('  Loaded Preferences: %d', GetLoadedPreferencesCount()))
    end
end, true)

RegisterCommand('tgw_ui_reload', function(source, args, rawCommand)
    if source == 0 and args[1] then -- Console only
        local identifier = args[1]
        LoadPlayerUIPreferences(identifier)

        local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)
        if playerId then
            InitializePlayerUI(identifier, playerId)
            print(string.format('^2[TGW-UI]^7 Reloaded UI for %s', identifier))
        else
            print(string.format('^1[TGW-UI]^7 Player not found: %s', identifier))
        end
    end
end, true)

function GetActiveUICount()
    local count = 0
    for _ in pairs(ActiveUIElements) do
        count = count + 1
    end
    return count
end

function GetLoadedPreferencesCount()
    local count = 0
    for _ in pairs(PlayerUIPreferences) do
        count = count + 1
    end
    return count
end

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Save all UI preferences
        for identifier, _ in pairs(PlayerUIPreferences) do
            SavePlayerUIPreferences(identifier)
        end

        print('^2[TGW-UI]^7 UI system stopped, all preferences saved')
    end
end)