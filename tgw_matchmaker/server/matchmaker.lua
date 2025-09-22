-- =====================================================
-- TGW MATCHMAKER SERVER - PLAYER PAIRING SYSTEM
-- =====================================================
-- Purpose: Advanced matchmaking based on rating and preferences
-- Dependencies: tgw_core, tgw_queue
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']
local TGWQueue = exports['tgw_queue']

-- Matchmaker state
local MatchmakerActive = false
local MatchmakerThread = nil
local MatchmakingStats = {
    totalMatches = 0,
    avgMatchTime = 0,
    avgRatingDiff = 0,
    preferenceMatchRate = 0,
    lastReset = os.time()
}

-- Match history for anti-avoidance
local RecentMatches = {}
local ArenaUsageHistory = {}

-- =====================================================
-- INITIALIZATION
-- =====================================================

CreateThread(function()
    -- Wait for dependencies
    while not ESX do
        ESX = exports['tgw_core']:GetESX()
        Wait(100)
    end

    -- Initialize matchmaker
    InitializeMatchmaker()
    StartMatchmaker()

    print('^2[TGW-MATCHMAKER]^7 Matchmaker system initialized')
end)

function InitializeMatchmaker()
    -- Load matchmaking statistics
    LoadMatchmakingStats()

    -- Initialize arena usage tracking
    InitializeArenaTracking()

    -- Register event handlers
    RegisterEventHandlers()
end

function LoadMatchmakingStats()
    MySQL.query([[
        SELECT
            COUNT(*) as total_matches,
            AVG(TIMESTAMPDIFF(SECOND, m.start_time, m.end_time)) as avg_match_duration,
            AVG(ABS(m.player_a_rating_before - m.player_b_rating_before)) as avg_rating_diff
        FROM tgw_matches m
        WHERE m.start_time > DATE_SUB(NOW(), INTERVAL 24 HOUR)
    ]], {}, function(result)
        if result and result[1] then
            MatchmakingStats.totalMatches = result[1].total_matches or 0
            MatchmakingStats.avgMatchTime = result[1].avg_match_duration or 0
            MatchmakingStats.avgRatingDiff = result[1].avg_rating_diff or 0
        end
    end)
end

function InitializeArenaTracking()
    -- Track arena usage for optimal assignment
    MySQL.query('SELECT id FROM tgw_arenas WHERE active = 1', {}, function(result)
        if result then
            for _, arena in ipairs(result) do
                ArenaUsageHistory[arena.id] = {
                    lastUsed = 0,
                    totalUses = 0,
                    avgMatchDuration = 0
                }
            end
        end
    end)
end

function RegisterEventHandlers()
    -- Handle queue events
    AddEventHandler('tgw:matchmaker:createMatch', function(player1, player2, arena)
        CreateMatch(player1.identifier, player2.identifier, arena.id)
    end)

    -- Handle match completion
    AddEventHandler('tgw:match:completed', function(matchData)
        UpdateMatchHistory(matchData)
    end)
end

-- =====================================================
-- MAIN MATCHMAKER LOOP
-- =====================================================

function StartMatchmaker()
    if MatchmakerThread then return end

    MatchmakerActive = true
    MatchmakerThread = CreateThread(function()
        while MatchmakerActive do
            Wait(MatchmakerConfig.TickPairingSec * 1000)

            if MatchmakerActive then
                ProcessMatchmaking()
            end
        end
    end)

    print('^2[TGW-MATCHMAKER]^7 Matchmaker thread started')
end

function StopMatchmaker()
    MatchmakerActive = false
    if MatchmakerThread then
        MatchmakerThread = nil
    end
    print('^3[TGW-MATCHMAKER]^7 Matchmaker thread stopped')
end

function ProcessMatchmaking()
    -- Get waiting players from queue
    local waitingPlayers = GetWaitingPlayersFromQueue()
    if #waitingPlayers < 2 then
        return
    end

    -- Get available arenas
    local availableArenas = GetAvailableArenas()
    if #availableArenas == 0 then
        return
    end

    -- Process matches up to the limit
    local matchesCreated = 0
    local maxMatches = math.min(MatchmakerConfig.MaxPairsPerTick, #availableArenas)

    while matchesCreated < maxMatches and #waitingPlayers >= 2 do
        local bestPair = FindBestPair(waitingPlayers)
        if not bestPair then
            break
        end

        local arena = SelectOptimalArena(availableArenas, bestPair)
        if not arena then
            break
        end

        -- Create the match
        local success = CreateMatch(bestPair.player1.identifier, bestPair.player2.identifier, arena.id)
        if success then
            matchesCreated = matchesCreated + 1

            -- Remove paired players from waiting list
            RemovePlayersFromList(waitingPlayers, { bestPair.player1, bestPair.player2 })

            -- Remove used arena from available list
            RemoveArenaFromList(availableArenas, arena)

            -- Update statistics
            UpdateMatchmakingStats(bestPair, arena)
        else
            -- If match creation failed, stop trying
            break
        end
    end

    if MatchmakerConfig.Performance.enableDebugLogging and matchesCreated > 0 then
        print(string.format('^5[TGW-MATCHMAKER]^7 Created %d matches this tick', matchesCreated))
    end
end

-- =====================================================
-- PLAYER PAIRING ALGORITHM
-- =====================================================

function FindBestPair(waitingPlayers)
    local bestPair = nil
    local bestScore = -1

    for i = 1, #waitingPlayers - 1 do
        for j = i + 1, #waitingPlayers do
            local player1 = waitingPlayers[i]
            local player2 = waitingPlayers[j]

            if CanPairPlayers(player1, player2) then
                local score = CalculatePairScore(player1, player2)
                if score > bestScore then
                    bestScore = score
                    bestPair = {
                        player1 = player1,
                        player2 = player2,
                        score = score
                    }
                end
            end
        end
    end

    return bestPair
end

function CanPairPlayers(player1, player2)
    -- Basic validation
    if not player1 or not player2 or player1.identifier == player2.identifier then
        return false
    end

    -- Check if players are online
    if MatchmakerConfig.Match.validatePlayers then
        if not IsPlayerOnline(player1.identifier) or not IsPlayerOnline(player2.identifier) then
            return false
        end
    end

    -- Check anti-avoidance
    if MatchmakerConfig.Algorithm.antiAvoidance.enabled then
        if HaveRecentlyPlayed(player1.identifier, player2.identifier) then
            return false
        end
    end

    -- Check minimum wait time
    local currentTime = os.time()
    local minWaitTime = MatchmakerConfig.QualityControl.minWaitTime

    if (currentTime - player1.queuedAt) < minWaitTime or
       (currentTime - player2.queuedAt) < minWaitTime then
        return false
    end

    -- Check rating compatibility
    if not AreRatingsCompatible(player1, player2) then
        return false
    end

    -- Check round type compatibility
    return AreRoundTypesCompatible(player1, player2)
end

function CalculatePairScore(player1, player2)
    local score = 0
    local factors = MatchmakerConfig.Algorithm.balanceFactors

    -- Rating proximity score (higher is better for closer ratings)
    local ratingDiff = math.abs(player1.ratingSnapshot - player2.ratingSnapshot)
    local ratingScore = math.max(0, 1000 - ratingDiff) / 1000
    score = score + (ratingScore * factors.rating)

    -- Wait time score (higher for longer waiting players)
    local currentTime = os.time()
    local avgWaitTime = ((currentTime - player1.queuedAt) + (currentTime - player2.queuedAt)) / 2
    local waitScore = math.min(avgWaitTime / 300, 1) -- Normalize to 5 minutes max
    score = score + (waitScore * factors.waitTime)

    -- Preference compatibility score
    local prefScore = GetPreferenceCompatibilityScore(player1, player2)
    score = score + (prefScore * factors.preferences)

    return score
end

function AreRatingsCompatible(player1, player2)
    local ratingDiff = math.abs(player1.ratingSnapshot - player2.ratingSnapshot)
    local currentTime = os.time()

    -- Calculate max allowed rating difference based on wait time
    local maxWaitTime = math.max(
        currentTime - player1.queuedAt,
        currentTime - player2.queuedAt
    )

    local maxRatingDiff = MatchmakerConfig.ELO.minRatingDiff +
                         math.floor(maxWaitTime / MatchmakerConfig.ELO.ratingGrowthInterval) *
                         MatchmakerConfig.ELO.ratingGrowthRate

    maxRatingDiff = math.min(maxRatingDiff, MatchmakerConfig.ELO.maxRatingDiff)

    return ratingDiff <= maxRatingDiff
end

function AreRoundTypesCompatible(player1, player2)
    if not MatchmakerConfig.RoundTypes.allowMismatch then
        return player1.preferredRound == player2.preferredRound
    end

    -- If mismatch is allowed, check if enough time has passed
    if player1.preferredRound ~= player2.preferredRound then
        local currentTime = os.time()
        local minWaitForMismatch = MatchmakerConfig.RoundTypes.mismatchPenalty

        return (currentTime - player1.queuedAt) >= minWaitForMismatch and
               (currentTime - player2.queuedAt) >= minWaitForMismatch
    end

    return true
end

function GetPreferenceCompatibilityScore(player1, player2)
    if player1.preferredRound == player2.preferredRound then
        return 1.0
    elseif MatchmakerConfig.RoundTypes.allowMismatch then
        return 0.5
    else
        return 0.0
    end
end

function HaveRecentlyPlayed(identifier1, identifier2)
    if not MatchmakerConfig.Algorithm.antiAvoidance.enabled then
        return false
    end

    local recentWindow = MatchmakerConfig.Algorithm.antiAvoidance.avoidanceWindow
    local currentTime = os.time()

    for _, match in ipairs(RecentMatches) do
        if currentTime - match.timestamp > recentWindow then
            -- Remove old matches
            table.remove(RecentMatches, _)
        elseif (match.player1 == identifier1 and match.player2 == identifier2) or
               (match.player1 == identifier2 and match.player2 == identifier1) then
            return true
        end
    end

    return false
end

-- =====================================================
-- ARENA SELECTION
-- =====================================================

function SelectOptimalArena(availableArenas, playerPair)
    if #availableArenas == 0 then return nil end

    -- Sort arenas by preference
    table.sort(availableArenas, function(a, b)
        return GetArenaScore(a) > GetArenaScore(b)
    end)

    return availableArenas[1]
end

function GetArenaScore(arena)
    local score = 0
    local usage = ArenaUsageHistory[arena.id]

    if MatchmakerConfig.ReuseEmptyArenaFirst then
        -- Prefer recently used arenas (they're already "warmed up")
        local timeSinceLastUse = os.time() - (usage and usage.lastUsed or 0)
        if timeSinceLastUse < 300 then -- 5 minutes
            score = score + 100
        end
    else
        -- Prefer least recently used arenas
        local timeSinceLastUse = os.time() - (usage and usage.lastUsed or 0)
        score = score + timeSinceLastUse / 60 -- Score increases with time
    end

    return score
end

-- =====================================================
-- MATCH CREATION
-- =====================================================

function CreateMatch(identifier1, identifier2, arenaId)
    -- Validate inputs
    if not identifier1 or not identifier2 or not arenaId then
        return false
    end

    -- Get player data
    local player1Data = GetPlayerTGWData(identifier1)
    local player2Data = GetPlayerTGWData(identifier2)

    if not player1Data or not player2Data then
        return false
    end

    -- Determine round type
    local roundType = DetermineRoundType(identifier1, identifier2)

    -- Create match in database
    MySQL.query([[
        INSERT INTO tgw_matches (
            arena_id, player_a, player_b, round_type,
            player_a_rating_before, player_b_rating_before, status
        ) VALUES (?, ?, ?, ?, ?, ?, 'running')
    ]], {
        arenaId,
        identifier1,
        identifier2,
        roundType,
        player1Data.rating,
        player2Data.rating
    }, function(result)
        if result and result.insertId then
            local matchId = result.insertId

            -- Remove players from queue
            TGWQueue.LeaveQueue(identifier1)
            TGWQueue.LeaveQueue(identifier2)

            -- Trigger arena assignment
            TriggerEvent('tgw:arena:assignPlayers', {
                matchId = matchId,
                arenaId = arenaId,
                player1 = identifier1,
                player2 = identifier2,
                roundType = roundType
            })

            -- Log match creation
            TGWCore.LogTGWEvent('match_created', identifier1, {
                opponent = identifier2,
                arena = arenaId,
                roundType = roundType,
                matchId = matchId
            })

            -- Update arena usage
            UpdateArenaUsage(arenaId)

            -- Add to recent matches for anti-avoidance
            AddToRecentMatches(identifier1, identifier2)

            return true
        else
            print('^1[TGW-MATCHMAKER ERROR]^7 Failed to create match in database')
            return false
        end
    end)

    return true
end

function DetermineRoundType(identifier1, identifier2)
    -- Get player preferences
    local prefs1 = GetPlayerPreferences(identifier1)
    local prefs2 = GetPlayerPreferences(identifier2)

    if prefs1 and prefs2 then
        -- Try to match preferred round types
        if prefs1.preferred_round == prefs2.preferred_round then
            return prefs1.preferred_round
        end

        -- Check if both players allow each other's preference
        if prefs1.preferred_round == 'pistol' and prefs2.allow_pistol == 1 then
            return 'pistol'
        elseif prefs1.preferred_round == 'sniper' and prefs2.allow_sniper == 1 then
            return 'sniper'
        elseif prefs2.preferred_round == 'pistol' and prefs1.allow_pistol == 1 then
            return 'pistol'
        elseif prefs2.preferred_round == 'sniper' and prefs1.allow_sniper == 1 then
            return 'sniper'
        end
    end

    -- Fallback to server priority
    for _, roundType in ipairs(MatchmakerConfig.RoundTypes.priority) do
        if CanPlayRoundType(identifier1, roundType) and CanPlayRoundType(identifier2, roundType) then
            return roundType
        end
    end

    -- Ultimate fallback
    return 'rifle'
end

function CanPlayRoundType(identifier, roundType)
    local prefs = GetPlayerPreferences(identifier)
    if not prefs then return true end -- No preferences = allow all

    if roundType == 'pistol' then
        return prefs.allow_pistol == 1
    elseif roundType == 'sniper' then
        return prefs.allow_sniper == 1
    end

    return true -- Rifle is always allowed
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function GetWaitingPlayersFromQueue()
    -- This would normally call the queue system
    -- For now, we'll simulate with database query
    local result = MySQL.query.await([[
        SELECT
            q.identifier,
            q.queued_at,
            q.preferred_round,
            q.rating_snapshot,
            UNIX_TIMESTAMP(q.queued_at) as queuedAt
        FROM tgw_queue q
        WHERE q.state = 'waiting'
        ORDER BY q.queued_at ASC
    ]], {})

    return result or {}
end

function GetAvailableArenas()
    local result = MySQL.query.await([[
        SELECT a.* FROM tgw_arenas a
        LEFT JOIN tgw_matches m ON a.id = m.arena_id AND m.status = 'running'
        WHERE a.active = 1 AND m.id IS NULL
        ORDER BY a.id ASC
    ]], {})

    return result or {}
end

function GetPlayerTGWData(identifier)
    local result = MySQL.query.await('SELECT * FROM tgw_players WHERE identifier = ?', { identifier })
    return result and result[1] or nil
end

function GetPlayerPreferences(identifier)
    local result = MySQL.query.await('SELECT * FROM tgw_preferences WHERE identifier = ?', { identifier })
    return result and result[1] or nil
end

function IsPlayerOnline(identifier)
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    return xPlayer ~= nil
end

function RemovePlayersFromList(playerList, playersToRemove)
    for i = #playerList, 1, -1 do
        for _, removePlayer in ipairs(playersToRemove) do
            if playerList[i].identifier == removePlayer.identifier then
                table.remove(playerList, i)
                break
            end
        end
    end
end

function RemoveArenaFromList(arenaList, arenaToRemove)
    for i = #arenaList, 1, -1 do
        if arenaList[i].id == arenaToRemove.id then
            table.remove(arenaList, i)
            break
        end
    end
end

function UpdateArenaUsage(arenaId)
    local usage = ArenaUsageHistory[arenaId]
    if usage then
        usage.lastUsed = os.time()
        usage.totalUses = usage.totalUses + 1
    end
end

function AddToRecentMatches(identifier1, identifier2)
    table.insert(RecentMatches, {
        player1 = identifier1,
        player2 = identifier2,
        timestamp = os.time()
    })

    -- Limit history size
    local maxHistory = MatchmakerConfig.Algorithm.antiAvoidance.trackRecentMatches
    while #RecentMatches > maxHistory do
        table.remove(RecentMatches, 1)
    end
end

function UpdateMatchmakingStats(bestPair, arena)
    MatchmakingStats.totalMatches = MatchmakingStats.totalMatches + 1

    local ratingDiff = math.abs(bestPair.player1.ratingSnapshot - bestPair.player2.ratingSnapshot)
    MatchmakingStats.avgRatingDiff = (MatchmakingStats.avgRatingDiff + ratingDiff) / 2

    if bestPair.player1.preferredRound == bestPair.player2.preferredRound then
        MatchmakingStats.preferenceMatchRate = MatchmakingStats.preferenceMatchRate + 0.1
    end
end

function UpdateMatchHistory(matchData)
    -- Update statistics when match completes
    if matchData and matchData.duration then
        MatchmakingStats.avgMatchTime = (MatchmakingStats.avgMatchTime + matchData.duration) / 2
    end
end

-- =====================================================
-- ADMIN FUNCTIONS
-- =====================================================

function PairNow(identifier)
    -- Force immediate pairing for a specific player
    local playerQueue = MySQL.query.await([[
        SELECT * FROM tgw_queue WHERE identifier = ? AND state = 'waiting'
    ]], { identifier })

    if not playerQueue or #playerQueue == 0 then
        return false, 'Player not in queue'
    end

    local waitingPlayers = GetWaitingPlayersFromQueue()
    local targetPlayer = nil

    for _, player in ipairs(waitingPlayers) do
        if player.identifier == identifier then
            targetPlayer = player
            break
        end
    end

    if not targetPlayer then
        return false, 'Player not found in waiting list'
    end

    -- Find best opponent
    for _, opponent in ipairs(waitingPlayers) do
        if opponent.identifier ~= identifier and CanPairPlayers(targetPlayer, opponent) then
            local availableArenas = GetAvailableArenas()
            if #availableArenas > 0 then
                return CreateMatch(identifier, opponent.identifier, availableArenas[1].id), 'Match created'
            end
        end
    end

    return false, 'No suitable opponent or arena found'
end

function ForceMatch(identifier1, identifier2, arenaId)
    -- Force a specific match (admin only)
    return CreateMatch(identifier1, identifier2, arenaId)
end

function GetCompatiblePlayers(identifier)
    -- Get list of players compatible with the specified player
    local waitingPlayers = GetWaitingPlayersFromQueue()
    local targetPlayer = nil
    local compatible = {}

    for _, player in ipairs(waitingPlayers) do
        if player.identifier == identifier then
            targetPlayer = player
            break
        end
    end

    if not targetPlayer then
        return {}
    end

    for _, opponent in ipairs(waitingPlayers) do
        if opponent.identifier ~= identifier and CanPairPlayers(targetPlayer, opponent) then
            table.insert(compatible, {
                identifier = opponent.identifier,
                rating = opponent.ratingSnapshot,
                waitTime = os.time() - opponent.queuedAt,
                score = CalculatePairScore(targetPlayer, opponent)
            })
        end
    end

    -- Sort by compatibility score
    table.sort(compatible, function(a, b) return a.score > b.score end)

    return compatible
end

function GetMatchmakingStats()
    return MatchmakingStats
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('CreateMatch', CreateMatch)
exports('PairNow', PairNow)
exports('GetMatchmakingStats', GetMatchmakingStats)
exports('ForceMatch', ForceMatch)
exports('GetCompatiblePlayers', GetCompatiblePlayers)

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('^3[TGW-MATCHMAKER]^7 Shutting down matchmaker...')
        StopMatchmaker()
    end
end)