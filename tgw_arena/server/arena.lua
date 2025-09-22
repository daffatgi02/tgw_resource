-- =====================================================
-- TGW ARENA SERVER - ARENA MANAGEMENT SYSTEM
-- =====================================================
-- Purpose: Routing bucket management, arena assignment, teleportation
-- Dependencies: tgw_core
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']

-- Arena state management
local ArenaStates = {}
local PlayerArenas = {}  -- mapping identifier -> arena_id
local ArenaPlayers = {}  -- mapping arena_id -> {player1, player2}
local ArenaMonitor = nil

-- =====================================================
-- INITIALIZATION
-- =====================================================

CreateThread(function()
    -- Wait for dependencies
    while not ESX do
        ESX = exports['tgw_core']:GetESX()
        Wait(100)
    end

    -- Initialize arena system
    InitializeArenaSystem()
    StartArenaMonitor()

    print('^2[TGW-ARENA]^7 Arena management system initialized')
end)

function InitializeArenaSystem()
    -- Auto-seed arenas if configured
    if ArenaConfig.AutoSeedArenas then
        SeedArenas()
    end

    -- Load existing arenas from database
    LoadArenasFromDatabase()

    -- Initialize arena states
    InitializeArenaStates()

    -- Register event handlers
    RegisterEventHandlers()
end

function SeedArenas()
    -- Check if arenas already exist
    MySQL.query('SELECT COUNT(*) as count FROM tgw_arenas', {}, function(result)
        local existingCount = result and result[1] and result[1].count or 0

        if existingCount < ArenaConfig.ArenasCount then
            print('^3[TGW-ARENA]^7 Seeding arenas...')

            -- Clear existing arenas and re-seed
            MySQL.query('DELETE FROM tgw_arenas', {}, function()
                local template = ArenaConfig.Template
                local insertValues = {}

                for i = 1, ArenaConfig.ArenasCount do
                    local bucketId = ArenaConfig.BaseBucket + (i - 1)
                    local arenaName = string.format('Arena %d', i)

                    table.insert(insertValues, {
                        arenaName,
                        bucketId,
                        template.spawnA.x,
                        template.spawnA.y,
                        template.spawnA.z,
                        template.spawnB.x,
                        template.spawnB.y,
                        template.spawnB.z,
                        template.headingA,
                        template.headingB,
                        template.radius,
                        1  -- level
                    })
                end

                -- Batch insert arenas
                local query = [[
                    INSERT INTO tgw_arenas
                    (name, bucket_id, spawn_ax, spawn_ay, spawn_az, spawn_bx, spawn_by, spawn_bz, heading_a, heading_b, radius, level)
                    VALUES
                ]]

                local valueStrings = {}
                for _, values in ipairs(insertValues) do
                    table.insert(valueStrings, string.format(
                        "('%s', %d, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, %.2f, %d)",
                        values[1], values[2], values[3], values[4], values[5],
                        values[6], values[7], values[8], values[9], values[10], values[11], values[12]
                    ))
                end

                query = query .. table.concat(valueStrings, ',')

                MySQL.query(query, {}, function(insertResult)
                    if insertResult then
                        print(string.format('^2[TGW-ARENA]^7 Successfully seeded %d arenas', ArenaConfig.ArenasCount))
                    else
                        print('^1[TGW-ARENA ERROR]^7 Failed to seed arenas')
                    end
                end)
            end)
        else
            print(string.format('^2[TGW-ARENA]^7 Found %d existing arenas, skipping seed', existingCount))
        end
    end)
end

function LoadArenasFromDatabase()
    MySQL.query('SELECT * FROM tgw_arenas WHERE active = 1 ORDER BY id ASC', {}, function(result)
        if result then
            print(string.format('^2[TGW-ARENA]^7 Loaded %d arenas from database', #result))
        else
            print('^1[TGW-ARENA ERROR]^7 Failed to load arenas from database')
        end
    end)
end

function InitializeArenaStates()
    -- Initialize all arenas as empty
    for i = 1, ArenaConfig.ArenasCount do
        local arenaId = i
        ArenaStates[arenaId] = {
            id = arenaId,
            state = ArenaConfig.States.EMPTY,
            bucketId = ArenaConfig.BaseBucket + (i - 1),
            matchId = nil,
            players = {},
            lastActivity = os.time(),
            violations = {}
        }
        ArenaPlayers[arenaId] = {}
    end
end

function RegisterEventHandlers()
    -- Handle match assignment from matchmaker
    AddEventHandler('tgw:arena:assignPlayers', function(matchData)
        AssignPlayersToArena(matchData.arenaId, matchData.player1, matchData.player2, matchData.matchId, matchData.roundType)
    end)

    -- Handle match completion
    AddEventHandler('tgw:match:completed', function(matchData)
        CleanupArena(matchData.arenaId)
    end)

    -- Handle player disconnect
    AddEventHandler('playerDropped', function(reason)
        local playerId = source
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            HandlePlayerDisconnect(xPlayer.identifier)
        end
    end)
end

-- =====================================================
-- ARENA MONITORING SYSTEM
-- =====================================================

function StartArenaMonitor()
    if ArenaMonitor then return end

    ArenaMonitor = CreateThread(function()
        while true do
            Wait(ArenaConfig.UpdateInterval)

            -- Monitor each arena
            for arenaId, arenaState in pairs(ArenaStates) do
                MonitorArena(arenaId, arenaState)
            end

            -- Cleanup check
            CheckArenaCleanup()
        end
    end)
end

function MonitorArena(arenaId, arenaState)
    -- Check if players are still in the arena
    local activePlayers = GetActivePlayersInArena(arenaId)

    -- Update player list
    ArenaPlayers[arenaId] = activePlayers

    -- Check arena state transitions
    if arenaState.state == ArenaConfig.States.ACTIVE then
        if #activePlayers == 0 then
            -- Arena became empty during active match
            print(string.format('^3[TGW-ARENA]^7 Arena %d became empty during active match', arenaId))
            StartArenaCleanup(arenaId)
        elseif #activePlayers == 1 and arenaState.matchId then
            -- One player left during match - should trigger forfeit
            TriggerEvent('tgw:match:playerLeft', arenaState.matchId, activePlayers[1])
        end
    elseif arenaState.state == ArenaConfig.States.EMPTY then
        if #activePlayers > 0 then
            -- Players appeared in empty arena (shouldn't happen)
            print(string.format('^3[TGW-ARENA]^7 Unexpected players in empty arena %d, cleaning up...', arenaId))
            ForceCleanupArena(arenaId)
        end
    end

    -- Update last activity
    if #activePlayers > 0 then
        arenaState.lastActivity = os.time()
    end
end

function GetActivePlayersInArena(arenaId)
    local arenaState = ArenaStates[arenaId]
    if not arenaState then return {} end

    local activePlayers = {}

    -- Check registered players
    for _, identifier in ipairs(arenaState.players) do
        local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
        if xPlayer then
            local playerId = xPlayer.source
            local playerBucket = GetPlayerRoutingBucket(playerId)

            if playerBucket == arenaState.bucketId then
                table.insert(activePlayers, identifier)
            end
        end
    end

    return activePlayers
end

-- =====================================================
-- ARENA ASSIGNMENT AND MANAGEMENT
-- =====================================================

function GetFreeArena()
    local freeArenas = {}

    -- Find all empty arenas
    for arenaId, arenaState in pairs(ArenaStates) do
        if arenaState.state == ArenaConfig.States.EMPTY then
            table.insert(freeArenas, arenaId)
        end
    end

    if #freeArenas == 0 then
        return nil
    end

    -- Return first available arena (can be enhanced with load balancing)
    return freeArenas[1]
end

function AssignPlayersToArena(arenaId, player1Identifier, player2Identifier, matchId, roundType)
    local arenaState = ArenaStates[arenaId]
    if not arenaState then
        print(string.format('^1[TGW-ARENA ERROR]^7 Arena %d not found', arenaId))
        return false
    end

    if arenaState.state ~= ArenaConfig.States.EMPTY then
        print(string.format('^1[TGW-ARENA ERROR]^7 Arena %d is not empty (state: %s)', arenaId, arenaState.state))
        return false
    end

    -- Update arena state
    arenaState.state = ArenaConfig.States.PREPARING
    arenaState.matchId = matchId
    arenaState.players = { player1Identifier, player2Identifier }
    arenaState.lastActivity = os.time()
    arenaState.violations = {}

    -- Clear any existing players in this bucket
    ClearBucket(arenaState.bucketId)

    -- Teleport players to arena
    TeleportPlayerToArena(player1Identifier, arenaId, ArenaConfig.SpawnSides.A)
    TeleportPlayerToArena(player2Identifier, arenaId, ArenaConfig.SpawnSides.B)

    -- Start arena preparation
    CreateThread(function()
        Wait(ArenaConfig.TeleportDelay)

        -- Verify both players arrived
        local activePlayers = GetActivePlayersInArena(arenaId)
        if #activePlayers == 2 then
            arenaState.state = ArenaConfig.States.ACTIVE

            -- Notify round system
            TriggerEvent('tgw:round:startMatch', {
                matchId = matchId,
                arenaId = arenaId,
                player1 = player1Identifier,
                player2 = player2Identifier,
                roundType = roundType
            })

            TGWCore.LogTGWEvent('arena_assigned', player1Identifier, {
                arena = arenaId,
                opponent = player2Identifier,
                match = matchId
            })
        else
            print(string.format('^1[TGW-ARENA ERROR]^7 Failed to assign players to arena %d', arenaId))
            StartArenaCleanup(arenaId)
        end
    end)

    return true
end

function TeleportPlayerToArena(identifier, arenaId, spawnSide)
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    if not xPlayer then
        print(string.format('^1[TGW-ARENA ERROR]^7 Player %s not found for teleport', identifier))
        return false
    end

    local playerId = xPlayer.source
    local arenaData = GetArenaData(arenaId)
    if not arenaData then
        print(string.format('^1[TGW-ARENA ERROR]^7 Arena %d data not found', arenaId))
        return false
    end

    local arenaState = ArenaStates[arenaId]
    local spawnPos, heading

    if spawnSide == ArenaConfig.SpawnSides.A then
        spawnPos = vector3(arenaData.spawn_ax, arenaData.spawn_ay, arenaData.spawn_az)
        heading = arenaData.heading_a
    else
        spawnPos = vector3(arenaData.spawn_bx, arenaData.spawn_by, arenaData.spawn_bz)
        heading = arenaData.heading_b
    end

    -- Set routing bucket first
    SetPlayerRoutingBucket(playerId, arenaState.bucketId)

    -- Update player arena mapping
    PlayerArenas[identifier] = arenaId

    -- Set player TGW state
    TGWCore.SetPlayerTGWState(identifier, 'arena', arenaId, arenaState.bucketId)

    -- Trigger client teleport
    TriggerClientEvent(Config.Events.MatchTeleport, playerId, arenaId, spawnSide, {
        position = spawnPos,
        heading = heading,
        bucket = arenaState.bucketId
    })

    print(string.format('^2[TGW-ARENA]^7 Teleported %s to arena %d (side %s)', identifier, arenaId, spawnSide))
    return true
end

-- =====================================================
-- ARENA CLEANUP AND MANAGEMENT
-- =====================================================

function StartArenaCleanup(arenaId)
    local arenaState = ArenaStates[arenaId]
    if not arenaState then return end

    arenaState.state = ArenaConfig.States.CLEANUP

    CreateThread(function()
        Wait(ArenaConfig.CleanupDelay * 1000)

        CleanupArena(arenaId)
    end)
end

function CleanupArena(arenaId)
    local arenaState = ArenaStates[arenaId]
    if not arenaState then return end

    print(string.format('^3[TGW-ARENA]^7 Cleaning up arena %d', arenaId))

    -- Remove players from arena tracking
    for _, identifier in ipairs(arenaState.players) do
        PlayerArenas[identifier] = nil

        -- Return player to lobby
        local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
        if xPlayer then
            TGWCore.SetPlayerTGWState(identifier, 'lobby', nil, Config.LobbyBucket)
        end
    end

    -- Clear bucket
    ClearBucket(arenaState.bucketId)

    -- Reset arena state
    arenaState.state = ArenaConfig.States.EMPTY
    arenaState.matchId = nil
    arenaState.players = {}
    arenaState.violations = {}
    arenaState.lastActivity = os.time()

    -- Clear arena player mapping
    ArenaPlayers[arenaId] = {}

    TGWCore.LogTGWEvent('arena_cleanup', 'system', { arena = arenaId })
end

function ForceCleanupArena(arenaId)
    local arenaState = ArenaStates[arenaId]
    if not arenaState then return end

    -- Get all players in the bucket
    local bucketsPlayers = GetBucketPlayers(arenaState.bucketId)

    for _, playerId in ipairs(bucketsPlayers) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            -- Force return to lobby
            TGWCore.SetPlayerTGWState(xPlayer.identifier, 'lobby', nil, Config.LobbyBucket)
        end
    end

    CleanupArena(arenaId)
end

function ClearBucket(bucketId)
    -- Remove all entities from bucket
    -- Note: This is a placeholder - actual implementation would depend on server setup
    print(string.format('^3[TGW-ARENA]^7 Clearing bucket %d', bucketId))
end

function GetBucketPlayers(bucketId)
    -- Get all players in a specific bucket
    local players = {}
    local allPlayers = ESX.GetExtendedPlayers()

    for _, xPlayer in pairs(allPlayers) do
        if GetPlayerRoutingBucket(xPlayer.source) == bucketId then
            table.insert(players, xPlayer.source)
        end
    end

    return players
end

function CheckArenaCleanup()
    local currentTime = os.time()

    for arenaId, arenaState in pairs(ArenaStates) do
        -- Force cleanup arenas that have been inactive too long
        if arenaState.state ~= ArenaConfig.States.EMPTY then
            local inactiveTime = currentTime - arenaState.lastActivity
            if inactiveTime > ArenaConfig.ForceCleanupAfter then
                print(string.format('^3[TGW-ARENA]^7 Force cleaning arena %d (inactive for %d seconds)', arenaId, inactiveTime))
                ForceCleanupArena(arenaId)
            end
        end
    end
end

-- =====================================================
-- PLAYER VIOLATION SYSTEM
-- =====================================================

function AddPlayerViolation(identifier, arenaId, violationType)
    local arenaState = ArenaStates[arenaId]
    if not arenaState then return end

    if not arenaState.violations[identifier] then
        arenaState.violations[identifier] = {}
    end

    table.insert(arenaState.violations[identifier], {
        type = violationType,
        time = os.time()
    })

    local violationCount = #arenaState.violations[identifier]

    if violationCount >= ArenaConfig.MaxViolations then
        -- Trigger forfeit
        TriggerEvent('tgw:round:forfeit', arenaState.matchId, identifier, violationType)
        return true
    end

    return false
end

function ResetPlayerViolations(identifier, arenaId)
    local arenaState = ArenaStates[arenaId]
    if not arenaState then return end

    arenaState.violations[identifier] = {}
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function GetArenaData(arenaId)
    local result = MySQL.query.await('SELECT * FROM tgw_arenas WHERE id = ? AND active = 1', { arenaId })
    return result and result[1] or nil
end

function IsArenaAvailable(arenaId)
    local arenaState = ArenaStates[arenaId]
    return arenaState and arenaState.state == ArenaConfig.States.EMPTY
end

function GetPlayerArena(identifier)
    return PlayerArenas[identifier]
end

function GetArenaPlayers(arenaId)
    return ArenaPlayers[arenaId] or {}
end

function SetPlayerBucket(playerId, bucketId)
    SetPlayerRoutingBucket(playerId, bucketId)
end

function HandlePlayerDisconnect(identifier)
    local arenaId = PlayerArenas[identifier]
    if arenaId then
        local arenaState = ArenaStates[arenaId]
        if arenaState and arenaState.matchId then
            -- Player disconnected during match
            TriggerEvent('tgw:round:playerDisconnect', arenaState.matchId, identifier)
        end

        -- Remove from arena tracking
        PlayerArenas[identifier] = nil

        -- Remove from arena players list
        if arenaState then
            for i, playerId in ipairs(arenaState.players) do
                if playerId == identifier then
                    table.remove(arenaState.players, i)
                    break
                end
            end
        end
    end
end

-- =====================================================
-- ADMIN FUNCTIONS
-- =====================================================

function GetArenaStatus()
    local status = {}
    for arenaId, arenaState in pairs(ArenaStates) do
        status[arenaId] = {
            id = arenaId,
            state = arenaState.state,
            bucket = arenaState.bucketId,
            players = #arenaState.players,
            matchId = arenaState.matchId,
            lastActivity = arenaState.lastActivity
        }
    end
    return status
end

-- =====================================================
-- EVENT HANDLERS
-- =====================================================

RegisterNetEvent('tgw:arena:reportViolation', function(violationType)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local arenaId = PlayerArenas[xPlayer.identifier]
    if arenaId then
        AddPlayerViolation(xPlayer.identifier, arenaId, violationType)
    end
end)

-- =====================================================
-- EXPORTS
-- =====================================================

exports('GetFreeArena', GetFreeArena)
exports('AssignPlayersToArena', AssignPlayersToArena)
exports('GetArenaData', GetArenaData)
exports('IsArenaAvailable', IsArenaAvailable)
exports('TeleportToArena', TeleportPlayerToArena)
exports('SetPlayerBucket', SetPlayerBucket)
exports('GetPlayerArena', GetPlayerArena)
exports('GetArenaPlayers', GetArenaPlayers)
exports('CleanupArena', CleanupArena)
exports('GetArenaStatus', GetArenaStatus)

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('^3[TGW-ARENA]^7 Shutting down arena system...')

        -- Cleanup all arenas
        for arenaId, _ in pairs(ArenaStates) do
            ForceCleanupArena(arenaId)
        end

        ArenaMonitor = nil
    end
end)