-- =====================================================
-- TGW ROUND SERVER - ROUND STATE MACHINE
-- =====================================================
-- Purpose: Round controller - freeze, start, end, cleanup, sudden death, AFK detection
-- Dependencies: tgw_core, tgw_arena
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']
local TGWArena = exports['tgw_arena']

-- Round state management
local ActiveRounds = {}  -- matchId -> round data
local RoundTimers = {}   -- matchId -> timer threads

-- Player tracking for AFK and hits
local PlayerStats = {}   -- identifier -> stats for current round

-- =====================================================
-- INITIALIZATION
-- =====================================================

CreateThread(function()
    -- Wait for dependencies
    while not ESX do
        ESX = exports['tgw_core']:GetESX()
        Wait(100)
    end

    -- Register event handlers
    RegisterEventHandlers()

    print('^2[TGW-ROUND]^7 Round controller system initialized')
end)

function RegisterEventHandlers()
    -- Handle match start from arena
    AddEventHandler('tgw:round:startMatch', function(matchData)
        StartMatch(matchData.matchId, matchData.arenaId, matchData.player1, matchData.player2, matchData.roundType)
    end)

    -- Handle player disconnect
    AddEventHandler('tgw:round:playerDisconnect', function(matchId, identifier)
        HandlePlayerDisconnect(matchId, identifier)
    end)

    -- Handle forfeit
    AddEventHandler('tgw:round:forfeit', function(matchId, identifier, reason)
        HandleForfeit(matchId, identifier, reason)
    end)

    -- Handle player left arena
    AddEventHandler('tgw:match:playerLeft', function(matchId, remainingPlayer)
        HandlePlayerLeft(matchId, remainingPlayer)
    end)
end

-- =====================================================
-- ROUND STATE MACHINE
-- =====================================================

function StartMatch(matchId, arenaId, player1, player2, roundType)
    if ActiveRounds[matchId] then
        print(string.format('^3[TGW-ROUND]^7 Match %d already active', matchId))
        return false
    end

    print(string.format('^2[TGW-ROUND]^7 Starting match %d in arena %d (%s)', matchId, arenaId, roundType))

    -- Initialize round data
    local roundData = {
        matchId = matchId,
        arenaId = arenaId,
        player1 = player1,
        player2 = player2,
        roundType = roundType,
        state = RoundConfig.States.PREPARING,
        startTime = os.time(),
        endTime = nil,
        winner = nil,
        endReason = nil,
        suddenDeathActive = false,
        currentRadius = nil
    }

    ActiveRounds[matchId] = roundData

    -- Initialize player stats
    InitializePlayerStats(player1, player2)

    -- Log round start
    LogRoundEvent(matchId, 'start', nil, nil, {
        arena = arenaId,
        players = { player1, player2 },
        roundType = roundType
    })

    -- Start round sequence
    StartRoundSequence(matchId)

    return true
end

function StartRoundSequence(matchId)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    CreateThread(function()
        -- Phase 1: Preparation
        roundData.state = RoundConfig.States.PREPARING

        -- Notify loadout system to equip players
        TriggerEvent('tgw:loadout:equipPlayers', matchId, roundData.player1, roundData.player2, roundData.roundType)

        Wait(1000)  -- Give time for loadout

        -- Phase 2: Freeze with countdown
        StartFreezePhase(matchId)

        Wait(RoundConfig.FreezeTime * 1000)

        -- Phase 3: Active round
        if ActiveRounds[matchId] then  -- Check if round still active
            StartActivePhase(matchId)
        end
    end)
end

function StartFreezePhase(matchId)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    roundData.state = RoundConfig.States.FREEZE

    print(string.format('^2[TGW-ROUND]^7 Starting freeze phase for match %d', matchId))

    -- Notify clients to start freeze countdown
    local player1Id = GetPlayerFromIdentifier(roundData.player1)
    local player2Id = GetPlayerFromIdentifier(roundData.player2)

    if player1Id then
        TriggerClientEvent('tgw:round:freezeStart', player1Id, RoundConfig.FreezeTime, roundData.player2)
    end
    if player2Id then
        TriggerClientEvent('tgw:round:freezeStart', player2Id, RoundConfig.FreezeTime, roundData.player1)
    end

    -- Log freeze start
    LogRoundEvent(matchId, 'freeze_start', nil, nil, { duration = RoundConfig.FreezeTime })
end

function StartActivePhase(matchId)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    roundData.state = RoundConfig.States.ACTIVE
    roundData.roundStartTime = os.time()

    print(string.format('^2[TGW-ROUND]^7 Round %d is now ACTIVE', matchId))

    -- Notify clients round started
    local player1Id = GetPlayerFromIdentifier(roundData.player1)
    local player2Id = GetPlayerFromIdentifier(roundData.player2)

    if player1Id then
        TriggerClientEvent('tgw:round:started', player1Id, matchId, RoundConfig.RoundTime)
    end
    if player2Id then
        TriggerClientEvent('tgw:round:started', player2Id, matchId, RoundConfig.RoundTime)
    end

    -- Start round timer
    StartRoundTimer(matchId)

    -- Start AFK monitoring
    StartAFKMonitoring(matchId)

    -- Log round start
    LogRoundEvent(matchId, 'round_start', nil, nil, { duration = RoundConfig.RoundTime })
end

function StartRoundTimer(matchId)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    RoundTimers[matchId] = CreateThread(function()
        local remainingTime = RoundConfig.RoundTime

        while remainingTime > 0 and ActiveRounds[matchId] and ActiveRounds[matchId].state == RoundConfig.States.ACTIVE do
            Wait(RoundConfig.TickRate)
            remainingTime = remainingTime - (RoundConfig.TickRate / 1000)

            -- Update clients with remaining time
            UpdateRoundTimer(matchId, math.max(0, remainingTime))
        end

        -- Time's up - start sudden death if round still active
        if ActiveRounds[matchId] and ActiveRounds[matchId].state == RoundConfig.States.ACTIVE then
            StartSuddenDeath(matchId)
        end
    end)
end

function StartSuddenDeath(matchId)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    roundData.state = RoundConfig.States.SUDDEN_DEATH
    roundData.suddenDeathActive = true
    roundData.suddenDeathStartTime = os.time()

    print(string.format('^3[TGW-ROUND]^7 Sudden Death started for match %d', matchId))

    -- Get arena data for radius shrinking
    local arenaData = TGWArena.GetArenaData(roundData.arenaId)
    if arenaData then
        roundData.currentRadius = arenaData.radius
    end

    -- Notify clients
    local player1Id = GetPlayerFromIdentifier(roundData.player1)
    local player2Id = GetPlayerFromIdentifier(roundData.player2)

    if player1Id then
        TriggerClientEvent('tgw:round:suddenDeath', player1Id, RoundConfig.SuddenDeath)
    end
    if player2Id then
        TriggerClientEvent('tgw:round:suddenDeath', player2Id, RoundConfig.SuddenDeath)
    end

    -- Start sudden death timer
    StartSuddenDeathTimer(matchId)

    -- Log sudden death
    LogRoundEvent(matchId, 'sudden_death', nil, nil, { duration = RoundConfig.SuddenDeath })
end

function StartSuddenDeathTimer(matchId)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    CreateThread(function()
        local remainingTime = RoundConfig.SuddenDeath
        local lastShrinkTime = 0

        while remainingTime > 0 and ActiveRounds[matchId] and ActiveRounds[matchId].state == RoundConfig.States.SUDDEN_DEATH do
            Wait(RoundConfig.SuddenDeathTickRate)

            local elapsed = RoundConfig.SuddenDeathTickRate / 1000
            remainingTime = remainingTime - elapsed
            lastShrinkTime = lastShrinkTime + elapsed

            -- Shrink arena radius
            if RoundConfig.SuddenDeathShrink and lastShrinkTime >= RoundConfig.SuddenDeathTick then
                ShrinkArenaRadius(matchId)
                lastShrinkTime = 0
            end

            -- Apply out-of-bounds damage
            ApplyOutOfBoundsDamage(matchId)

            -- Update timer
            UpdateSuddenDeathTimer(matchId, math.max(0, remainingTime))
        end

        -- Sudden death time expired - determine winner
        if ActiveRounds[matchId] and ActiveRounds[matchId].state == RoundConfig.States.SUDDEN_DEATH then
            DetermineSuddenDeathWinner(matchId)
        end
    end)
end

-- =====================================================
-- SUDDEN DEATH MECHANICS
-- =====================================================

function ShrinkArenaRadius(matchId)
    local roundData = ActiveRounds[matchId]
    if not roundData or not roundData.currentRadius then return end

    local newRadius = math.max(
        RoundConfig.SuddenDeathMinRadius,
        roundData.currentRadius - RoundConfig.SuddenDeathShrinkStep
    )

    if newRadius ~= roundData.currentRadius then
        roundData.currentRadius = newRadius

        -- Notify clients of new radius
        local player1Id = GetPlayerFromIdentifier(roundData.player1)
        local player2Id = GetPlayerFromIdentifier(roundData.player2)

        if player1Id then
            TriggerClientEvent('tgw:round:radiusUpdate', player1Id, newRadius)
        end
        if player2Id then
            TriggerClientEvent('tgw:round:radiusUpdate', player2Id, newRadius)
        end

        print(string.format('^3[TGW-ROUND]^7 Arena radius shrunk to %.1f for match %d', newRadius, matchId))
    end
end

function ApplyOutOfBoundsDamage(matchId)
    local roundData = ActiveRounds[matchId]
    if not roundData or not roundData.currentRadius then return end

    -- Check each player's position and apply damage if out of bounds
    for _, identifier in ipairs({roundData.player1, roundData.player2}) do
        local playerId = GetPlayerFromIdentifier(identifier)
        if playerId then
            -- This would be enhanced with actual position checking
            -- For now, we'll rely on client-side reporting
            TriggerClientEvent('tgw:round:checkOutOfBounds', playerId, roundData.currentRadius, RoundConfig.OutOfBoundsDamagePerSec)
        end
    end
end

function DetermineSuddenDeathWinner(matchId)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    print(string.format('^3[TGW-ROUND]^7 Determining sudden death winner for match %d', matchId))

    -- Get player stats
    local player1Stats = PlayerStats[roundData.player1]
    local player2Stats = PlayerStats[roundData.player2]

    local winner = nil
    local reason = 'sudden_death_timeout'

    -- Apply tie-breaker rules
    for _, criteria in ipairs(RoundConfig.TieBreaker) do
        if criteria == 'health' then
            if player1Stats.health > player2Stats.health then
                winner = roundData.player1
                reason = 'sudden_death_hp'
                break
            elseif player2Stats.health > player1Stats.health then
                winner = roundData.player2
                reason = 'sudden_death_hp'
                break
            end
        elseif criteria == 'hits' then
            if player1Stats.hits > player2Stats.hits then
                winner = roundData.player1
                reason = 'sudden_death_hits'
                break
            elseif player2Stats.hits > player1Stats.hits then
                winner = roundData.player2
                reason = 'sudden_death_hits'
                break
            end
        elseif criteria == 'draw' then
            winner = nil
            reason = 'draw'
            break
        end
    end

    EndRound(matchId, winner, reason)
end

-- =====================================================
-- ROUND END MANAGEMENT
-- =====================================================

function EndRound(matchId, winner, reason)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    if roundData.state == RoundConfig.States.ENDING or roundData.state == RoundConfig.States.COMPLETED then
        return  -- Already ending
    end

    roundData.state = RoundConfig.States.ENDING
    roundData.endTime = os.time()
    roundData.winner = winner
    roundData.endReason = reason

    print(string.format('^2[TGW-ROUND]^7 Round %d ended - Winner: %s, Reason: %s',
        matchId, winner or 'draw', reason))

    -- Stop timers
    if RoundTimers[matchId] then
        RoundTimers[matchId] = nil
    end

    -- Calculate results and ratings
    local results = CalculateRoundResults(matchId)

    -- Update database
    UpdateMatchResults(matchId, winner, reason)

    -- Notify players of results
    NotifyRoundResults(matchId, results)

    -- Update ratings and ladder
    TriggerEvent('tgw:rating:updatePlayers', {
        matchId = matchId,
        player1 = roundData.player1,
        player2 = roundData.player2,
        winner = winner,
        results = results
    })

    TriggerEvent('tgw:ladder:updatePlayers', {
        matchId = matchId,
        player1 = roundData.player1,
        player2 = roundData.player2,
        winner = winner
    })

    -- Cleanup after delay
    CreateThread(function()
        Wait(5000)  -- Give time for result display
        CompleteRound(matchId)
    end)
end

function CalculateRoundResults(matchId)
    local roundData = ActiveRounds[matchId]
    if not roundData then return nil end

    local duration = roundData.endTime - roundData.roundStartTime
    local player1Stats = PlayerStats[roundData.player1]
    local player2Stats = PlayerStats[roundData.player2]

    return {
        duration = duration,
        roundType = roundData.roundType,
        endReason = roundData.endReason,
        player1Stats = player1Stats,
        player2Stats = player2Stats,
        suddenDeathActive = roundData.suddenDeathActive
    }
end

function UpdateMatchResults(matchId, winner, reason)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    local winnerEnum = nil
    if winner == roundData.player1 then
        winnerEnum = 'a'
    elseif winner == roundData.player2 then
        winnerEnum = 'b'
    else
        winnerEnum = 'draw'
    end

    MySQL.query([[
        UPDATE tgw_matches
        SET end_time = NOW(), winner = ?, status = 'ended'
        WHERE id = ?
    ]], {
        winnerEnum,
        matchId
    })

    -- Log round end
    LogRoundEvent(matchId, 'end', winner, nil, {
        reason = reason,
        duration = roundData.endTime - roundData.startTime
    })
end

function NotifyRoundResults(matchId, results)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    local player1Id = GetPlayerFromIdentifier(roundData.player1)
    local player2Id = GetPlayerFromIdentifier(roundData.player2)

    -- Determine result for each player
    local player1Result = 'draw'
    local player2Result = 'draw'

    if roundData.winner == roundData.player1 then
        player1Result = 'win'
        player2Result = 'lose'
    elseif roundData.winner == roundData.player2 then
        player1Result = 'lose'
        player2Result = 'win'
    end

    -- Send results to clients
    if player1Id then
        TriggerClientEvent('tgw:round:result', player1Id, {
            result = player1Result,
            reason = roundData.endReason,
            duration = results.duration,
            roundType = roundData.roundType,
            opponent = roundData.player2,
            stats = results.player1Stats
        })
    end

    if player2Id then
        TriggerClientEvent('tgw:round:result', player2Id, {
            result = player2Result,
            reason = roundData.endReason,
            duration = results.duration,
            roundType = roundData.roundType,
            opponent = roundData.player1,
            stats = results.player2Stats
        })
    end
end

function CompleteRound(matchId)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    roundData.state = RoundConfig.States.COMPLETED

    -- Clean up player stats
    PlayerStats[roundData.player1] = nil
    PlayerStats[roundData.player2] = nil

    -- Notify arena system to cleanup
    TriggerEvent('tgw:match:completed', {
        matchId = matchId,
        arenaId = roundData.arenaId,
        duration = roundData.endTime - roundData.startTime
    })

    -- Remove from active rounds
    ActiveRounds[matchId] = nil

    print(string.format('^2[TGW-ROUND]^7 Round %d completed and cleaned up', matchId))
end

-- =====================================================
-- PLAYER EVENT HANDLERS
-- =====================================================

function HandlePlayerDisconnect(matchId, identifier)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    local opponent = identifier == roundData.player1 and roundData.player2 or roundData.player1
    EndRound(matchId, opponent, 'disconnect')
end

function HandleForfeit(matchId, identifier, reason)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    local opponent = identifier == roundData.player1 and roundData.player2 or roundData.player1
    EndRound(matchId, opponent, 'forfeit_' .. reason)
end

function HandlePlayerLeft(matchId, remainingPlayer)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    EndRound(matchId, remainingPlayer, 'opponent_left')
end

-- =====================================================
-- HIT AND KILL TRACKING
-- =====================================================

function ReportHit(matchId, shooter, target, damage, isHeadshot)
    local roundData = ActiveRounds[matchId]
    if not roundData or roundData.state ~= RoundConfig.States.ACTIVE then
        return false
    end

    -- Validate hit
    if not ValidateHit(shooter, target, damage) then
        return false
    end

    -- Update stats
    if PlayerStats[shooter] then
        PlayerStats[shooter].hits = PlayerStats[shooter].hits + 1
        PlayerStats[shooter].damageDealt = PlayerStats[shooter].damageDealt + damage

        if isHeadshot then
            PlayerStats[shooter].headshots = PlayerStats[shooter].headshots + 1
        end
    end

    if PlayerStats[target] then
        PlayerStats[target].damageTaken = PlayerStats[target].damageTaken + damage
    end

    -- Log hit
    LogRoundEvent(matchId, 'hit', shooter, target, {
        damage = damage,
        headshot = isHeadshot
    })

    return true
end

function ReportKill(matchId, killer, victim)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    print(string.format('^2[TGW-ROUND]^7 Kill reported in match %d: %s killed %s', matchId, killer, victim))

    -- Update stats
    if PlayerStats[killer] then
        PlayerStats[killer].kills = PlayerStats[killer].kills + 1
    end

    if PlayerStats[victim] then
        PlayerStats[victim].deaths = PlayerStats[victim].deaths + 1
    end

    -- Log kill
    LogRoundEvent(matchId, 'kill', killer, victim, {})

    -- End round with killer as winner
    EndRound(matchId, killer, 'kill')
end

function ValidateHit(shooter, target, damage)
    -- Basic validation
    if not shooter or not target or shooter == target then
        return false
    end

    if damage <= 0 or damage > 200 then  -- Reasonable damage range
        return false
    end

    -- Additional validation could be added here
    return true
end

-- =====================================================
-- AFK MONITORING
-- =====================================================

function StartAFKMonitoring(matchId)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    CreateThread(function()
        while ActiveRounds[matchId] and ActiveRounds[matchId].state == RoundConfig.States.ACTIVE do
            Wait(RoundConfig.AFKCheckRate)

            CheckPlayersAFK(matchId)
        end
    end)
end

function CheckPlayersAFK(matchId)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    for _, identifier in ipairs({roundData.player1, roundData.player2}) do
        local playerStats = PlayerStats[identifier]
        if playerStats then
            local timeSinceActivity = os.time() - playerStats.lastActivity

            if timeSinceActivity >= RoundConfig.AFKThreshold then
                print(string.format('^3[TGW-ROUND]^7 Player %s is AFK in match %d', identifier, matchId))
                HandleForfeit(matchId, identifier, 'afk')
                return
            end
        end
    end
end

function UpdatePlayerActivity(identifier)
    if PlayerStats[identifier] then
        PlayerStats[identifier].lastActivity = os.time()
    end
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function InitializePlayerStats(player1, player2)
    local baseStats = {
        health = 100,
        hits = 0,
        kills = 0,
        deaths = 0,
        headshots = 0,
        damageDealt = 0,
        damageTaken = 0,
        lastActivity = os.time()
    }

    PlayerStats[player1] = table.copy(baseStats)
    PlayerStats[player2] = table.copy(baseStats)
end

function GetPlayerFromIdentifier(identifier)
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    return xPlayer and xPlayer.source or nil
end

function UpdateRoundTimer(matchId, remainingTime)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    local player1Id = GetPlayerFromIdentifier(roundData.player1)
    local player2Id = GetPlayerFromIdentifier(roundData.player2)

    if player1Id then
        TriggerClientEvent('tgw:round:timer', player1Id, remainingTime)
    end
    if player2Id then
        TriggerClientEvent('tgw:round:timer', player2Id, remainingTime)
    end
end

function UpdateSuddenDeathTimer(matchId, remainingTime)
    local roundData = ActiveRounds[matchId]
    if not roundData then return end

    local player1Id = GetPlayerFromIdentifier(roundData.player1)
    local player2Id = GetPlayerFromIdentifier(roundData.player2)

    if player1Id then
        TriggerClientEvent('tgw:round:suddenDeathTimer', player1Id, remainingTime)
    end
    if player2Id then
        TriggerClientEvent('tgw:round:suddenDeathTimer', player2Id, remainingTime)
    end
end

function LogRoundEvent(matchId, eventType, actor, target, data)
    if not RoundConfig.LogRoundEvents then return end

    MySQL.query([[
        INSERT INTO tgw_round_events (match_id, type, actor, target, value, metadata)
        VALUES (?, ?, ?, ?, ?, ?)
    ]], {
        matchId,
        eventType,
        actor,
        target,
        data and data.value or nil,
        data and json.encode(data) or nil
    })
end

function GetMatchStatus(matchId)
    return ActiveRounds[matchId]
end

function ForceEnd(matchId, reason)
    reason = reason or 'forced'
    local roundData = ActiveRounds[matchId]
    if roundData then
        EndRound(matchId, nil, reason)
        return true
    end
    return false
end

function GetRoundState(matchId)
    local roundData = ActiveRounds[matchId]
    return roundData and roundData.state or nil
end

function GetRoundTime(matchId)
    local roundData = ActiveRounds[matchId]
    if not roundData or not roundData.roundStartTime then
        return 0
    end
    return os.time() - roundData.roundStartTime
end

-- =====================================================
-- EVENT HANDLERS
-- =====================================================

RegisterNetEvent('tgw:round:reportHit', function(matchId, target, damage, isHeadshot)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    UpdatePlayerActivity(xPlayer.identifier)
    ReportHit(matchId, xPlayer.identifier, target, damage, isHeadshot or false)
end)

RegisterNetEvent('tgw:round:reportKill', function(matchId, victim)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    UpdatePlayerActivity(xPlayer.identifier)
    ReportKill(matchId, xPlayer.identifier, victim)
end)

RegisterNetEvent('tgw:round:updateActivity', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    UpdatePlayerActivity(xPlayer.identifier)
end)

-- =====================================================
-- EXPORTS
-- =====================================================

exports('StartMatch', StartMatch)
exports('EndMatch', EndRound)
exports('ForceEnd', ForceEnd)
exports('GetMatchStatus', GetMatchStatus)
exports('ReportHit', ReportHit)
exports('ReportKill', ReportKill)
exports('CheckAFK', CheckPlayersAFK)
exports('GetRoundState', GetRoundState)
exports('GetRoundTime', GetRoundTime)

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('^3[TGW-ROUND]^7 Shutting down round system...')

        -- End all active rounds
        for matchId, _ in pairs(ActiveRounds) do
            ForceEnd(matchId, 'server_restart')
        end

        -- Clear timers
        RoundTimers = {}
        ActiveRounds = {}
        PlayerStats = {}
    end
end)