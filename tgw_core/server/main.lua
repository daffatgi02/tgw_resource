-- =====================================================
-- TGW CORE SERVER - MAIN ENTRY POINT
-- =====================================================
-- Purpose: ESX integration, database initialization, core utilities
-- Dependencies: es_extended, oxmysql
-- =====================================================

local ESX = nil
local TGWPlayers = {}
local TGWStats = {
    playersOnline = 0,
    activeMatches = 0,
    queueCount = 0,
    serverStartTime = os.time()
}

-- =====================================================
-- INITIALIZATION
-- =====================================================

-- Initialize ESX
TriggerEvent('esx:getSharedObject', function(obj)
    ESX = obj
    print('^2[TGW-CORE]^7 ESX object loaded successfully')
end)

-- Wait for dependencies and initialize
CreateThread(function()
    while ESX == nil do
        Wait(100)
    end

    -- Initialize database tables
    InitializeDatabase()

    -- Start core systems
    StartHeartbeatSystem()
    StartStatsTracker()

    print(string.format('^2[TGW-CORE]^7 System initialized successfully (v%s)', Config.GetVersionString()))
end)

-- =====================================================
-- DATABASE INITIALIZATION
-- =====================================================

function InitializeDatabase()
    -- Check if TGW tables exist
    MySQL.query('SHOW TABLES LIKE "tgw_%"', {}, function(result)
        if not result or #result == 0 then
            print('^3[TGW-CORE]^7 TGW database tables not found. Please run tgw_schema.sql first!')
            return
        end

        local tableCount = #result
        print(string.format('^2[TGW-CORE]^7 Found %d TGW database tables', tableCount))

        -- Verify critical tables
        VerifyDatabaseTables()
    end)
end

function VerifyDatabaseTables()
    local requiredTables = {
        'tgw_players',
        'tgw_preferences',
        'tgw_arenas',
        'tgw_matches',
        'tgw_queue'
    }

    for _, tableName in ipairs(requiredTables) do
        MySQL.query('SHOW TABLES LIKE ?', { tableName }, function(result)
            if not result or #result == 0 then
                print(string.format('^1[TGW-CORE ERROR]^7 Required table %s not found!', tableName))
            end
        end)
    end
end

-- =====================================================
-- PLAYER MANAGEMENT
-- =====================================================

-- Player connect handler
AddEventHandler('esx:playerLoaded', function(playerId, xPlayer)
    local identifier = xPlayer.identifier

    -- Initialize player in TGW system
    InitializeTGWPlayer(identifier, playerId)

    -- Store player reference
    TGWPlayers[identifier] = {
        playerId = playerId,
        xPlayer = xPlayer,
        joinTime = os.time(),
        inTGW = false,
        currentState = 'lobby',
        arenaId = nil,
        bucketId = Config.LobbyBucket,
        lastHeartbeat = os.time()
    }

    TGWStats.playersOnline = TGWStats.playersOnline + 1

    print(string.format('^2[TGW-CORE]^7 Player %s initialized in TGW system', xPlayer.getName()))
end)

-- Player disconnect handler
AddEventHandler('esx:playerDropped', function(playerId, reason)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end

    local identifier = xPlayer.identifier

    -- Clean up player from TGW system
    CleanupTGWPlayer(identifier)

    -- Remove player reference
    if TGWPlayers[identifier] then
        TGWPlayers[identifier] = nil
        TGWStats.playersOnline = math.max(0, TGWStats.playersOnline - 1)
    end

    print(string.format('^3[TGW-CORE]^7 Player %s cleaned up from TGW system', xPlayer.getName()))
end)

function InitializeTGWPlayer(identifier, playerId)
    -- Use stored procedure to initialize player
    MySQL.query('CALL sp_tgw_init_player(?)', { identifier }, function(result)
        if not result then
            print(string.format('^1[TGW-CORE ERROR]^7 Failed to initialize player: %s', identifier))
            return
        end

        print(string.format('^2[TGW-CORE]^7 Player initialized in database: %s', identifier))
    end)
end

function CleanupTGWPlayer(identifier)
    -- Remove from queue if present
    MySQL.query('DELETE FROM tgw_queue WHERE identifier = ?', { identifier }, function(result)
        -- Update last seen
        MySQL.query('UPDATE tgw_players SET last_seen = NOW() WHERE identifier = ?', { identifier })
    end)
end

-- =====================================================
-- CORE UTILITY FUNCTIONS
-- =====================================================

function GetTGWPlayer(identifier)
    return TGWPlayers[identifier]
end

function IsPlayerInTGW(identifier)
    local player = TGWPlayers[identifier]
    return player and player.inTGW or false
end

function SetPlayerTGWState(identifier, state, arenaId, bucketId)
    local player = TGWPlayers[identifier]
    if not player then return false end

    player.currentState = state
    player.arenaId = arenaId
    player.bucketId = bucketId or Config.LobbyBucket
    player.inTGW = (state ~= 'lobby')

    -- Set routing bucket
    SetPlayerRoutingBucket(player.playerId, player.bucketId)

    return true
end

function GetPlayerTGWData(identifier)
    return MySQL.query.await('SELECT * FROM tgw_players WHERE identifier = ?', { identifier })
end

function GetPlayerPreferences(identifier)
    return MySQL.query.await('SELECT * FROM tgw_preferences WHERE identifier = ?', { identifier })
end

-- =====================================================
-- ESX INTEGRATION HELPERS
-- =====================================================

function SendTGWNotification(playerId, message, type)
    local xPlayer = ESX.GetPlayerFromId(playerId)
    if not xPlayer then return end

    type = type or 'info'
    xPlayer.showNotification(message, type)
end

function ValidateIdentifier(identifier)
    return identifier and type(identifier) == 'string' and #identifier > 0
end

function FormatPlayerName(xPlayer)
    if not xPlayer then return 'Unknown' end
    return string.format('%s %s', xPlayer.getName() or 'Unknown', '')
end

function LogTGWEvent(eventType, identifier, data)
    if not Config.EnableDebugMode then return end

    local logData = {
        timestamp = os.time(),
        event = eventType,
        player = identifier,
        data = data
    }

    print(string.format('^5[TGW-LOG]^7 %s: %s - %s',
        eventType,
        identifier or 'system',
        json.encode(data) or 'no data'
    ))
end

-- =====================================================
-- HEARTBEAT SYSTEM
-- =====================================================

function StartHeartbeatSystem()
    CreateThread(function()
        while true do
            Wait(Config.HeartbeatInterval)

            -- Check player heartbeats
            local currentTime = os.time()
            for identifier, player in pairs(TGWPlayers) do
                if currentTime - player.lastHeartbeat > 60 then
                    print(string.format('^3[TGW-CORE]^7 Player %s missed heartbeat, cleaning up...', identifier))
                    CleanupTGWPlayer(identifier)
                end
            end
        end
    end)
end

-- Player heartbeat handler
RegisterNetEvent(Config.Events.PlayerHeartbeat, function()
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local identifier = xPlayer.identifier
    local player = TGWPlayers[identifier]
    if player then
        player.lastHeartbeat = os.time()
    end
end)

-- =====================================================
-- STATISTICS TRACKER
-- =====================================================

function StartStatsTracker()
    CreateThread(function()
        while true do
            Wait(60000) -- Update every minute

            -- Update active matches count
            MySQL.query('SELECT COUNT(*) as count FROM tgw_matches WHERE status = "running"', {}, function(result)
                if result and result[1] then
                    TGWStats.activeMatches = result[1].count or 0
                end
            end)

            -- Update queue count
            MySQL.query('SELECT COUNT(*) as count FROM tgw_queue', {}, function(result)
                if result and result[1] then
                    TGWStats.queueCount = result[1].count or 0
                end
            end)

            -- Log stats if debug mode enabled
            if Config.EnableDebugMode then
                print(string.format('^6[TGW-STATS]^7 Online: %d | Matches: %d | Queue: %d',
                    TGWStats.playersOnline,
                    TGWStats.activeMatches,
                    TGWStats.queueCount
                ))
            end
        end
    end)
end

function GetTGWStats()
    return TGWStats
end

-- =====================================================
-- SERVER CALLBACKS
-- =====================================================

-- Get player TGW data
ESX.RegisterServerCallback(Config.Events.GetPlayerData, function(source, cb, targetIdentifier)
    local identifier = targetIdentifier or ESX.GetPlayerFromId(source).identifier

    MySQL.query('SELECT * FROM v_tgw_player_stats WHERE identifier = ?', { identifier }, function(result)
        if result and result[1] then
            cb(result[1])
        else
            cb(nil)
        end
    end)
end)

-- Get player preferences
ESX.RegisterServerCallback(Config.Events.GetPreferences, function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then
        cb(nil)
        return
    end

    local prefs = GetPlayerPreferences(xPlayer.identifier)
    cb(prefs and prefs[1] or nil)
end)

-- Get leaderboard
ESX.RegisterServerCallback(Config.Events.GetLeaderboard, function(source, cb, limit)
    limit = limit or 10

    MySQL.query('CALL sp_tgw_get_leaderboard(?)', { limit }, function(result)
        cb(result or {})
    end)
end)

-- Get queue status
ESX.RegisterServerCallback(Config.Events.GetQueueStatus, function(source, cb)
    MySQL.query('SELECT * FROM v_tgw_queue_status ORDER BY queued_at ASC', {}, function(result)
        cb(result or {})
    end)
end)

-- =====================================================
-- ADMIN COMMANDS
-- =====================================================

-- TGW status command
RegisterCommand('tgwstatus', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.getGroup() ~= 'admin' then return end

    local stats = GetTGWStats()
    local message = string.format(
        '^2[TGW STATUS]^7\nOnline Players: %d\nActive Matches: %d\nQueue Count: %d\nUptime: %d seconds',
        stats.playersOnline,
        stats.activeMatches,
        stats.queueCount,
        os.time() - stats.serverStartTime
    )

    TriggerClientEvent('chat:addMessage', source, {
        color = { 255, 255, 255 },
        multiline = true,
        args = { 'TGW', message }
    })
end, true)

-- Cleanup old data command
RegisterCommand('tgwcleanup', function(source, args, rawCommand)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer or xPlayer.getGroup() ~= 'admin' then return end

    MySQL.query('CALL sp_tgw_cleanup_old_matches()', {}, function(result)
        SendTGWNotification(source, 'TGW cleanup completed', 'success')
    end)
end, true)

-- =====================================================
-- EXPORTS
-- =====================================================

exports('GetESX', function()
    return ESX
end)

exports('GetTGWConfig', function()
    return Config
end)

exports('IsPlayerInTGW', function(identifier)
    return IsPlayerInTGW(identifier)
end)

exports('LogTGWEvent', function(eventType, identifier, data)
    LogTGWEvent(eventType, identifier, data)
end)

exports('ValidateIdentifier', function(identifier)
    return ValidateIdentifier(identifier)
end)

exports('FormatPlayerName', function(xPlayer)
    return FormatPlayerName(xPlayer)
end)

exports('GetPlayerTGWData', function(identifier)
    return GetPlayerTGWData(identifier)
end)

exports('SendTGWNotification', function(playerId, message, type)
    SendTGWNotification(playerId, message, type)
end)

exports('GetTGWPlayer', function(identifier)
    return GetTGWPlayer(identifier)
end)

exports('SetPlayerTGWState', function(identifier, state, arenaId, bucketId)
    return SetPlayerTGWState(identifier, state, arenaId, bucketId)
end)

exports('GetTGWStats', function()
    return GetTGWStats()
end)

-- =====================================================
-- SERVER SHUTDOWN HANDLER
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('^3[TGW-CORE]^7 Shutting down and cleaning up...')

        -- Clean up all players
        for identifier, _ in pairs(TGWPlayers) do
            CleanupTGWPlayer(identifier)
        end

        print('^2[TGW-CORE]^7 Cleanup completed')
    end
end)