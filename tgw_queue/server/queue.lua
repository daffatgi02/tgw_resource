-- =====================================================
-- TGW QUEUE SERVER - QUEUE MANAGEMENT SYSTEM
-- =====================================================
-- Purpose: Handle player queue, spectate while waiting
-- Dependencies: tgw_core
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']
local QueuedPlayers = {}
local SpectatingPlayers = {}
local QueueProcessor = nil

-- =====================================================
-- INITIALIZATION
-- =====================================================

CreateThread(function()
    -- Wait for dependencies
    while not ESX do
        ESX = exports['tgw_core']:GetESX()
        Wait(100)
    end

    -- Initialize queue system
    InitializeQueueSystem()
    StartQueueProcessor()

    print('^2[TGW-QUEUE]^7 Queue system initialized')
end)

function InitializeQueueSystem()
    -- Clear any stale queue entries from database
    MySQL.query('DELETE FROM tgw_queue WHERE queued_at < DATE_SUB(NOW(), INTERVAL 1 HOUR)', {})

    -- Load existing queue from database (in case of restart)
    MySQL.query('SELECT * FROM tgw_queue ORDER BY queued_at ASC', {}, function(result)
        if result then
            for _, queueEntry in ipairs(result) do
                QueuedPlayers[queueEntry.identifier] = {
                    identifier = queueEntry.identifier,
                    queuedAt = queueEntry.queued_at,
                    state = queueEntry.state,
                    preferredRound = queueEntry.preferred_round,
                    ratingSnapshot = queueEntry.rating_snapshot,
                    spectateTarget = queueEntry.spectate_target,
                    spectateArena = queueEntry.spectate_arena,
                    lastSpectateSwitch = 0
                }
            end
            print(string.format('^2[TGW-QUEUE]^7 Loaded %d players from database queue', #result))
        end
    end)
end

-- =====================================================
-- QUEUE PROCESSING THREAD
-- =====================================================

function StartQueueProcessor()
    if QueueProcessor then return end

    QueueProcessor = CreateThread(function()
        while true do
            Wait(1000) -- Process every second

            ProcessQueue()
            UpdateSpectateTargets()
            CleanupStaleEntries()
        end
    end)
end

function ProcessQueue()
    local waitingPlayers = GetWaitingPlayers()
    if #waitingPlayers < QueueConfig.MinPlayersForMatch then
        -- Not enough players, assign spectating
        AssignSpectateToWaiting(waitingPlayers)
        return
    end

    -- Try to create matches
    local availableArenas = GetAvailableArenas()
    if #availableArenas == 0 then
        -- No arenas available, assign spectating
        AssignSpectateToWaiting(waitingPlayers)
        return
    end

    -- Process pairing
    for _, arena in ipairs(availableArenas) do
        if #waitingPlayers >= 2 then
            local pair = FindBestPair(waitingPlayers)
            if pair then
                CreateMatch(pair[1], pair[2], arena)
                -- Remove paired players from waiting list
                for i = #waitingPlayers, 1, -1 do
                    if waitingPlayers[i].identifier == pair[1].identifier or
                       waitingPlayers[i].identifier == pair[2].identifier then
                        table.remove(waitingPlayers, i)
                    end
                end
            end
        else
            break
        end
    end

    -- Assign remaining players to spectate
    AssignSpectateToWaiting(waitingPlayers)
end

-- =====================================================
-- QUEUE MANAGEMENT FUNCTIONS
-- =====================================================

function JoinQueue(identifier, preferredRound)
    -- Validate player
    if not TGWCore.ValidateIdentifier(identifier) then
        return false, QueueConfig.Errors.INVALID_PREFERENCES
    end

    -- Check if already in queue
    if IsPlayerInQueue(identifier) then
        return false, QueueConfig.Errors.ALREADY_IN_QUEUE
    end

    -- Check queue size
    if GetQueueSize() >= QueueConfig.MaxQueueSize then
        return false, QueueConfig.Errors.QUEUE_FULL
    end

    -- Get player data
    local playerData = TGWCore.GetPlayerTGWData(identifier)
    if not playerData or #playerData == 0 then
        return false, 'Player data not found'
    end

    local rating = playerData[1].rating or Config.DefaultRating

    -- Add to queue
    local queueEntry = {
        identifier = identifier,
        queuedAt = os.time(),
        state = QueueConfig.States.WAITING,
        preferredRound = preferredRound or 'rifle',
        ratingSnapshot = rating,
        spectateTarget = nil,
        spectateArena = nil,
        lastSpectateSwitch = 0
    }

    QueuedPlayers[identifier] = queueEntry

    -- Add to database
    MySQL.query([[
        INSERT INTO tgw_queue (identifier, state, preferred_round, rating_snapshot)
        VALUES (?, ?, ?, ?)
        ON DUPLICATE KEY UPDATE
        state = VALUES(state),
        preferred_round = VALUES(preferred_round),
        rating_snapshot = VALUES(rating_snapshot),
        queued_at = NOW()
    ]], {
        identifier,
        queueEntry.state,
        queueEntry.preferredRound,
        queueEntry.ratingSnapshot
    })

    -- Notify player
    local playerId = GetPlayerFromIdentifier(identifier)
    if playerId then
        TriggerClientEvent(Config.Events.PlayerJoinedTGW, playerId, queueEntry.state, queueEntry)
        TGWCore.SetPlayerTGWState(identifier, 'queue', nil, Config.LobbyBucket)
    end

    TGWCore.LogTGWEvent('queue_join', identifier, queueEntry)
    return true, QueueConfig.Messages.JOINED_QUEUE
end

function LeaveQueue(identifier)
    if not IsPlayerInQueue(identifier) then
        return false, QueueConfig.Errors.NOT_IN_QUEUE
    end

    local queueEntry = QueuedPlayers[identifier]

    -- Stop spectating if active
    if queueEntry.state == QueueConfig.States.SPECTATE then
        StopSpectate(identifier)
    end

    -- Remove from queue
    QueuedPlayers[identifier] = nil

    -- Remove from database
    MySQL.query('DELETE FROM tgw_queue WHERE identifier = ?', { identifier })

    -- Notify player
    local playerId = GetPlayerFromIdentifier(identifier)
    if playerId then
        TriggerClientEvent(Config.Events.PlayerLeftTGW, playerId)
        TGWCore.SetPlayerTGWState(identifier, 'lobby', nil, Config.LobbyBucket)
    end

    TGWCore.LogTGWEvent('queue_leave', identifier, queueEntry)
    return true, QueueConfig.Messages.LEFT_QUEUE
end

-- =====================================================
-- SPECTATE SYSTEM
-- =====================================================

function StartSpectate(identifier, targetIdentifier, arenaId)
    local queueEntry = QueuedPlayers[identifier]
    if not queueEntry then return false end

    -- Check cooldown
    if os.time() - queueEntry.lastSpectateSwitch < QueueConfig.SpectateSwitchCooldown then
        return false, QueueConfig.Errors.COOLDOWN_ACTIVE
    end

    -- Stop current spectating
    if queueEntry.state == QueueConfig.States.SPECTATE then
        StopSpectate(identifier)
    end

    -- Find target if not provided
    if not targetIdentifier or not arenaId then
        local spectateTarget = FindSpectateTarget(identifier)
        if not spectateTarget then
            return false, QueueConfig.Errors.NO_MATCHES_TO_SPECTATE
        end
        targetIdentifier = spectateTarget.targetIdentifier
        arenaId = spectateTarget.arenaId
    end

    -- Update queue entry
    queueEntry.state = QueueConfig.States.SPECTATE
    queueEntry.spectateTarget = targetIdentifier
    queueEntry.spectateArena = arenaId
    queueEntry.lastSpectateSwitch = os.time()

    -- Update database
    MySQL.query([[
        UPDATE tgw_queue
        SET state = ?, spectate_target = ?, spectate_arena = ?
        WHERE identifier = ?
    ]], {
        queueEntry.state,
        queueEntry.spectateTarget,
        queueEntry.spectateArena,
        identifier
    })

    -- Get arena data
    local arenaData = GetArenaData(arenaId)
    if not arenaData then return false, 'Arena not found' end

    -- Set player routing bucket
    TGWCore.SetPlayerTGWState(identifier, 'spectate', arenaId, arenaData.bucket_id)

    -- Notify client
    local playerId = GetPlayerFromIdentifier(identifier)
    if playerId then
        local targetPlayerId = GetPlayerFromIdentifier(targetIdentifier)
        TriggerClientEvent(Config.Events.SpectateStart, playerId, targetPlayerId, arenaData)
        TriggerClientEvent(Config.Events.QueueStatusUpdate, playerId, 'spectate', queueEntry)
    end

    TGWCore.LogTGWEvent('spectate_start', identifier, {
        target = targetIdentifier,
        arena = arenaId
    })

    return true, QueueConfig.Messages.SPECTATE_STARTED
end

function StopSpectate(identifier)
    local queueEntry = QueuedPlayers[identifier]
    if not queueEntry or queueEntry.state ~= QueueConfig.States.SPECTATE then
        return false
    end

    -- Update queue entry
    queueEntry.state = QueueConfig.States.WAITING
    queueEntry.spectateTarget = nil
    queueEntry.spectateArena = nil

    -- Update database
    MySQL.query([[
        UPDATE tgw_queue
        SET state = ?, spectate_target = NULL, spectate_arena = NULL
        WHERE identifier = ?
    ]], {
        queueEntry.state,
        identifier
    })

    -- Return to lobby bucket
    TGWCore.SetPlayerTGWState(identifier, 'queue', nil, Config.LobbyBucket)

    -- Notify client
    local playerId = GetPlayerFromIdentifier(identifier)
    if playerId then
        TriggerClientEvent(Config.Events.SpectateStop, playerId)
        TriggerClientEvent(Config.Events.QueueStatusUpdate, playerId, 'waiting', queueEntry)
    end

    TGWCore.LogTGWEvent('spectate_stop', identifier, queueEntry)
    return true, QueueConfig.Messages.SPECTATE_STOPPED
end

function SwitchSpectateTarget(identifier, direction)
    local queueEntry = QueuedPlayers[identifier]
    if not queueEntry or queueEntry.state ~= QueueConfig.States.SPECTATE then
        return false
    end

    -- Check cooldown
    if os.time() - queueEntry.lastSpectateSwitch < QueueConfig.SpectateSwitchCooldown then
        return false, QueueConfig.Errors.COOLDOWN_ACTIVE
    end

    -- Find next/previous spectate target
    local newTarget = FindNextSpectateTarget(identifier, direction)
    if not newTarget then
        return false, QueueConfig.Errors.NO_MATCHES_TO_SPECTATE
    end

    -- Start spectating new target
    return StartSpectate(identifier, newTarget.targetIdentifier, newTarget.arenaId)
end

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================

function GetWaitingPlayers()
    local waiting = {}
    for identifier, queueEntry in pairs(QueuedPlayers) do
        if queueEntry.state == QueueConfig.States.WAITING then
            table.insert(waiting, queueEntry)
        end
    end

    -- Sort by queue time (oldest first)
    table.sort(waiting, function(a, b)
        return a.queuedAt < b.queuedAt
    end)

    return waiting
end

function GetAvailableArenas()
    local arenas = MySQL.query.await([[
        SELECT a.* FROM tgw_arenas a
        LEFT JOIN tgw_matches m ON a.id = m.arena_id AND m.status = 'running'
        WHERE a.active = 1 AND m.id IS NULL
        ORDER BY a.id ASC
    ]], {})

    return arenas or {}
end

function FindBestPair(waitingPlayers)
    if #waitingPlayers < 2 then return nil end

    for i = 1, #waitingPlayers - 1 do
        local player1 = waitingPlayers[i]
        for j = i + 1, #waitingPlayers do
            local player2 = waitingPlayers[j]

            -- Check if they can be paired
            if CanPairPlayers(player1, player2) then
                return { player1, player2 }
            end
        end
    end

    return nil
end

function CanPairPlayers(player1, player2)
    -- Check rating difference
    local ratingDiff = math.abs(player1.ratingSnapshot - player2.ratingSnapshot)

    -- Calculate max allowed difference based on wait time
    local waitTime = math.max(
        os.time() - player1.queuedAt,
        os.time() - player2.queuedAt
    )

    local maxDiff = QueueConfig.MinEloDiff +
                    math.floor(waitTime / QueueConfig.EloDiffGrowStep) * QueueConfig.EloDiffGrow
    maxDiff = math.min(maxDiff, QueueConfig.MaxEloDiff)

    if ratingDiff > maxDiff then
        return false
    end

    -- Check round type compatibility
    return AreRoundTypesCompatible(player1.preferredRound, player2.preferredRound)
end

function AreRoundTypesCompatible(round1, round2)
    -- Get player preferences from database
    -- For now, simplified logic - can be enhanced
    return true
end

function CreateMatch(player1, player2, arena)
    -- This will be handled by matchmaker
    TriggerEvent('tgw:matchmaker:createMatch', player1, player2, arena)

    -- Update queue states
    if QueuedPlayers[player1.identifier] then
        QueuedPlayers[player1.identifier].state = QueueConfig.States.PAIRED
    end
    if QueuedPlayers[player2.identifier] then
        QueuedPlayers[player2.identifier].state = QueueConfig.States.PAIRED
    end
end

function AssignSpectateToWaiting(waitingPlayers)
    if not QueueConfig.AutoSpectateWhenFull then return end

    for _, player in ipairs(waitingPlayers) do
        if player.state == QueueConfig.States.WAITING then
            StartSpectate(player.identifier)
        end
    end
end

function FindSpectateTarget(identifier)
    -- Get active matches
    local activeMatches = MySQL.query.await([[
        SELECT m.*, a.bucket_id, a.name as arena_name
        FROM tgw_matches m
        JOIN tgw_arenas a ON m.arena_id = a.id
        WHERE m.status = 'running'
        ORDER BY m.start_time ASC
    ]], {})

    if not activeMatches or #activeMatches == 0 then
        return nil
    end

    -- Simple selection for now - can be enhanced with preferences
    local selectedMatch = activeMatches[math.random(#activeMatches)]

    -- Choose random player to spectate
    local targetIdentifier = math.random() > 0.5 and selectedMatch.player_a or selectedMatch.player_b

    return {
        targetIdentifier = targetIdentifier,
        arenaId = selectedMatch.arena_id
    }
end

function FindNextSpectateTarget(identifier, direction)
    -- Implementation for cycling through spectate targets
    return FindSpectateTarget(identifier)
end

function UpdateSpectateTargets()
    -- Update spectating players if their targets are no longer valid
    for identifier, queueEntry in pairs(QueuedPlayers) do
        if queueEntry.state == QueueConfig.States.SPECTATE then
            -- Check if spectate target is still valid
            if not IsSpectateTargetValid(queueEntry.spectateTarget, queueEntry.spectateArena) then
                -- Find new target or return to waiting
                local newTarget = FindSpectateTarget(identifier)
                if newTarget then
                    StartSpectate(identifier, newTarget.targetIdentifier, newTarget.arenaId)
                else
                    StopSpectate(identifier)
                end
            end
        end
    end
end

function IsSpectateTargetValid(targetIdentifier, arenaId)
    if not targetIdentifier or not arenaId then return false end

    -- Check if target is still in an active match in the specified arena
    local result = MySQL.query.await([[
        SELECT 1 FROM tgw_matches
        WHERE arena_id = ? AND status = 'running'
        AND (player_a = ? OR player_b = ?)
    ]], { arenaId, targetIdentifier, targetIdentifier })

    return result and #result > 0
end

function CleanupStaleEntries()
    local currentTime = os.time()

    for identifier, queueEntry in pairs(QueuedPlayers) do
        -- Remove entries older than max queue time
        if currentTime - queueEntry.queuedAt > QueueConfig.MaxQueueTime then
            LeaveQueue(identifier)
        end
    end
end

function GetArenaData(arenaId)
    local result = MySQL.query.await('SELECT * FROM tgw_arenas WHERE id = ?', { arenaId })
    return result and result[1] or nil
end

function GetPlayerFromIdentifier(identifier)
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    return xPlayer and xPlayer.source or nil
end

function IsPlayerInQueue(identifier)
    return QueuedPlayers[identifier] ~= nil
end

function GetQueueSize()
    local count = 0
    for _ in pairs(QueuedPlayers) do
        count = count + 1
    end
    return count
end

function GetQueuePosition(identifier)
    if not IsPlayerInQueue(identifier) then return -1 end

    local waitingPlayers = GetWaitingPlayers()
    for i, player in ipairs(waitingPlayers) do
        if player.identifier == identifier then
            return i
        end
    end
    return -1
end

function GetQueueStatus(identifier)
    return QueuedPlayers[identifier]
end

-- =====================================================
-- EVENT HANDLERS
-- =====================================================

RegisterNetEvent(Config.Events.QueueJoin, function(preferredRound)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local success, message = JoinQueue(xPlayer.identifier, preferredRound)
    TGWCore.SendTGWNotification(source, message, success and 'success' or 'error')
end)

RegisterNetEvent(Config.Events.QueueLeave, function()
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local success, message = LeaveQueue(xPlayer.identifier)
    TGWCore.SendTGWNotification(source, message, success and 'success' or 'error')
end)

RegisterNetEvent(Config.Events.SpectateNext, function()
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local success, message = SwitchSpectateTarget(xPlayer.identifier, 1)
    if not success then
        TGWCore.SendTGWNotification(source, message, 'error')
    end
end)

RegisterNetEvent(Config.Events.SpectatePrev, function()
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local success, message = SwitchSpectateTarget(xPlayer.identifier, -1)
    if not success then
        TGWCore.SendTGWNotification(source, message, 'error')
    end
end)

-- =====================================================
-- EXPORTS
-- =====================================================

exports('JoinQueue', JoinQueue)
exports('LeaveQueue', LeaveQueue)
exports('GetQueuePosition', GetQueuePosition)
exports('GetQueueStatus', GetQueueStatus)
exports('IsPlayerInQueue', IsPlayerInQueue)
exports('StartSpectate', StartSpectate)
exports('StopSpectate', StopSpectate)
exports('GetSpectateTarget', function(identifier)
    local queueEntry = QueuedPlayers[identifier]
    return queueEntry and queueEntry.spectateTarget or nil
end)

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('^3[TGW-QUEUE]^7 Shutting down queue system...')

        -- Save queue state and cleanup
        for identifier, _ in pairs(QueuedPlayers) do
            LeaveQueue(identifier)
        end

        QueueProcessor = nil
    end
end)