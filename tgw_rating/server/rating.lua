-- =====================================================
-- TGW RATING SERVER - ELO RATING AND COMPETITIVE RANKING
-- =====================================================
-- Purpose: Calculate and manage ELO ratings and competitive ranks
-- Dependencies: tgw_core, tgw_ladder, es_extended
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']

-- Rating system state
local PlayerRatings = {}             -- [identifier] = ratingData
local RatingHistory = {}             -- [identifier] = historyArray
local PendingUpdates = {}            -- Queued rating updates
local LeaderboardCache = {}          -- Cached leaderboard data
local SeasonData = {}                -- Current season information

-- Performance tracking
local RatingStats = {
    totalCalculations = 0,
    totalUpdates = 0,
    averageChange = 0,
    suspiciousActivity = 0
}

-- =====================================================
-- INITIALIZATION
-- =====================================================

CreateThread(function()
    while not ESX do
        ESX = exports['tgw_core']:GetESX()
        Wait(100)
    end

    RegisterEventHandlers()
    InitializeRatingSystem()
    StartPerformanceMonitoring()
    StartRatingDecay()
    LoadSeasonData()

    print('^2[TGW-RATING SERVER]^7 ELO rating and competitive ranking system initialized')
end)

function RegisterEventHandlers()
    -- Rating requests
    RegisterNetEvent('tgw:rating:requestData', function()
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            SendPlayerRatingData(xPlayer.identifier, src)
        end
    end)

    RegisterNetEvent('tgw:rating:requestHistory', function(limit)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            local history = GetRatingHistory(xPlayer.identifier, limit)
            TriggerClientEvent('tgw:rating:historyData', src, history)
        end
    end)

    -- Match result processing
    RegisterNetEvent('tgw:round:result', function(resultData)
        ProcessMatchRatingChanges(resultData)
    end)

    -- Player connection events
    RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
        LoadPlayerRating(xPlayer.identifier)
    end)

    RegisterNetEvent('esx:playerDropped', function(playerId, reason)
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            SavePlayerRating(xPlayer.identifier)
            CleanupPlayerData(xPlayer.identifier)
        end
    end)

    -- Admin events
    RegisterNetEvent('tgw:rating:adminSet', function(targetIdentifier, newRating, reason)
        local src = source
        if TGWCore.IsPlayerAdmin(src) then
            SetPlayerRating(targetIdentifier, newRating, reason, 'admin')
        end
    end)

    RegisterNetEvent('tgw:rating:adminRecalibrate', function(targetIdentifier)
        local src = source
        if TGWCore.IsPlayerAdmin(src) then
            RecalibratePlayerRating(targetIdentifier)
        end
    end)
end

-- =====================================================
-- RATING DATA MANAGEMENT
-- =====================================================

function LoadPlayerRating(identifier)
    MySQL.query([[
        SELECT rating, peak_rating, games_played, provisional, last_game_date,
               season_rating, season_games, created_at
        FROM tgw_rating
        WHERE identifier = ?
    ]], {identifier}, function(results)
        if results and #results > 0 then
            local data = results[1]
            PlayerRatings[identifier] = {
                rating = data.rating,
                peakRating = data.peak_rating,
                gamesPlayed = data.games_played,
                provisional = data.provisional == 1,
                lastGameDate = data.last_game_date,
                seasonRating = data.season_rating,
                seasonGames = data.season_games,
                rank = CalculateCompetitiveRank(data.rating),
                lastUpdated = os.time()
            }
        else
            -- Initialize new player
            InitializeNewPlayerRating(identifier)
        end

        -- Load rating history
        LoadPlayerRatingHistory(identifier)

        print(string.format('^2[TGW-RATING]^7 Loaded rating data for %s (Rating: %d)',
            identifier, PlayerRatings[identifier].rating))
    end)
end

function InitializeNewPlayerRating(identifier)
    local startingRating = RatingConfig.DefaultRating

    PlayerRatings[identifier] = {
        rating = startingRating,
        peakRating = startingRating,
        gamesPlayed = 0,
        provisional = true,
        lastGameDate = os.time(),
        seasonRating = startingRating,
        seasonGames = 0,
        rank = CalculateCompetitiveRank(startingRating),
        lastUpdated = os.time()
    }

    -- Insert into database
    MySQL.execute([[
        INSERT INTO tgw_rating (identifier, rating, peak_rating, provisional, season_rating)
        VALUES (?, ?, ?, 1, ?)
    ]], {identifier, startingRating, startingRating, startingRating})

    print(string.format('^2[TGW-RATING]^7 Initialized new player rating: %s (%d)', identifier, startingRating))
end

function SavePlayerRating(identifier)
    local data = PlayerRatings[identifier]
    if not data then
        return
    end

    MySQL.execute([[
        UPDATE tgw_rating SET
            rating = ?, peak_rating = ?, games_played = ?, provisional = ?,
            last_game_date = FROM_UNIXTIME(?), season_rating = ?, season_games = ?,
            updated_at = NOW()
        WHERE identifier = ?
    ]], {
        data.rating, data.peakRating, data.gamesPlayed, data.provisional and 1 or 0,
        data.lastGameDate, data.seasonRating, data.seasonGames, identifier
    })

    print(string.format('^2[TGW-RATING]^7 Saved rating data for %s', identifier))
end

-- =====================================================
-- ELO RATING CALCULATIONS
-- =====================================================

function CalculateRatingChange(player1Id, player2Id, result, matchContext)
    local player1Data = PlayerRatings[player1Id]
    local player2Data = PlayerRatings[player2Id]

    if not player1Data or not player2Data then
        print('^1[TGW-RATING ERROR]^7 Missing player rating data for calculation')
        return 0, 0
    end

    local rating1 = player1Data.rating
    local rating2 = player2Data.rating

    -- Calculate expected scores
    local expectedScore1 = CalculateExpectedScore(rating1, rating2)
    local expectedScore2 = 1 - expectedScore1

    -- Determine actual scores based on result
    local actualScore1, actualScore2 = DetermineActualScores(result, player1Id, player2Id)

    -- Get K-factors for both players
    local kFactor1 = GetKFactor(player1Data)
    local kFactor2 = GetKFactor(player2Data)

    -- Apply modifiers
    local modifier1, modifier2 = CalculateModifiers(player1Id, player2Id, matchContext)
    kFactor1 = kFactor1 * modifier1
    kFactor2 = kFactor2 * modifier2

    -- Calculate rating changes
    local change1 = math.floor(kFactor1 * (actualScore1 - expectedScore1))
    local change2 = math.floor(kFactor2 * (actualScore2 - expectedScore2))

    -- Validate changes
    change1 = ValidateRatingChange(player1Data, change1)
    change2 = ValidateRatingChange(player2Data, change2)

    RatingStats.totalCalculations = RatingStats.totalCalculations + 1

    return change1, change2
end

function CalculateExpectedScore(ratingA, ratingB)
    local ratingDiff = ratingB - ratingA
    local exponent = ratingDiff / RatingConfig.ExpectedScore.scalingFactor
    return 1 / (1 + math.pow(RatingConfig.ExpectedScore.logisticBase, exponent))
end

function DetermineActualScores(result, player1Id, player2Id)
    if result == 'win' and result.winner == player1Id then
        return 1, 0  -- Player 1 wins
    elseif result == 'win' and result.winner == player2Id then
        return 0, 1  -- Player 2 wins
    elseif result == 'draw' then
        return 0.5, 0.5  -- Draw
    elseif type(result) == 'table' and result.winner then
        if result.winner == player1Id then
            return 1, 0
        elseif result.winner == player2Id then
            return 0, 1
        else
            return 0.5, 0.5  -- No clear winner
        end
    else
        return 0.5, 0.5  -- Default to draw
    end
end

function GetKFactor(playerData)
    -- Provisional players get higher K-factor
    if playerData.provisional then
        return RatingConfig.KFactors.provisional
    end

    -- Rating-based K-factors
    if playerData.rating >= RatingConfig.KFactorThresholds.master then
        return RatingConfig.KFactors.master
    elseif playerData.rating >= RatingConfig.KFactorThresholds.high_rated then
        return RatingConfig.KFactors.high_rated
    else
        return RatingConfig.KFactors.standard
    end
end

function CalculateModifiers(player1Id, player2Id, matchContext)
    local modifier1 = 1.0
    local modifier2 = 1.0

    if not matchContext then
        return modifier1, modifier2
    end

    -- Round type modifier
    if matchContext.roundType and RatingConfig.Modifiers.roundType[matchContext.roundType] then
        local roundMod = RatingConfig.Modifiers.roundType[matchContext.roundType]
        modifier1 = modifier1 * roundMod
        modifier2 = modifier2 * roundMod
    end

    -- Match condition modifiers
    if matchContext.conditions then
        for condition, modValue in pairs(RatingConfig.Modifiers.matchConditions) do
            if matchContext.conditions[condition] then
                if matchContext.winner == player1Id then
                    modifier1 = modifier1 * modValue
                elseif matchContext.winner == player2Id then
                    modifier2 = modifier2 * modValue
                end
            end
        end
    end

    -- Win streak bonus
    if RatingConfig.Modifiers.streakBonus.enabled then
        local streak1 = GetPlayerWinStreak(player1Id)
        local streak2 = GetPlayerWinStreak(player2Id)

        if streak1 >= RatingConfig.Modifiers.streakBonus.streakThreshold then
            local bonus = math.min(
                RatingConfig.Modifiers.streakBonus.maxBonus,
                (streak1 - RatingConfig.Modifiers.streakBonus.streakThreshold) * RatingConfig.Modifiers.streakBonus.bonusPerWin
            )
            modifier1 = modifier1 * (1 + bonus)
        end

        if streak2 >= RatingConfig.Modifiers.streakBonus.streakThreshold then
            local bonus = math.min(
                RatingConfig.Modifiers.streakBonus.maxBonus,
                (streak2 - RatingConfig.Modifiers.streakBonus.streakThreshold) * RatingConfig.Modifiers.streakBonus.bonusPerWin
            )
            modifier2 = modifier2 * (1 + bonus)
        end
    end

    return modifier1, modifier2
end

function ValidateRatingChange(playerData, change)
    -- Validate against maximum change
    if math.abs(change) > RatingConfig.Validation.maxChangePerGame then
        RatingStats.suspiciousActivity = RatingStats.suspiciousActivity + 1
        print(string.format('^1[TGW-RATING ANTICHEAT]^7 Suspicious rating change capped: %d -> %d',
            change, RatingConfig.Validation.maxChangePerGame * (change > 0 and 1 or -1)))
        change = RatingConfig.Validation.maxChangePerGame * (change > 0 and 1 or -1)
    end

    -- Ensure rating doesn't go below minimum
    local newRating = playerData.rating + change
    if newRating < RatingConfig.MinRating then
        change = RatingConfig.MinRating - playerData.rating
    elseif newRating > RatingConfig.MaxRating then
        change = RatingConfig.MaxRating - playerData.rating
    end

    return change
end

-- =====================================================
-- RATING UPDATES
-- =====================================================

function UpdateRating(identifier, ratingChange, reason, matchContext)
    local data = PlayerRatings[identifier]
    if not data then
        print(string.format('^1[TGW-RATING ERROR]^7 No rating data for player: %s', identifier))
        return false
    end

    local oldRating = data.rating
    local oldRank = data.rank

    -- Apply rating change
    data.rating = math.max(RatingConfig.MinRating, math.min(RatingConfig.MaxRating, data.rating + ratingChange))
    data.gamesPlayed = data.gamesPlayed + 1
    data.lastGameDate = os.time()
    data.seasonGames = data.seasonGames + 1

    -- Update peak rating
    if data.rating > data.peakRating then
        data.peakRating = data.rating
    end

    -- Check if still provisional
    if data.provisional and data.gamesPlayed >= RatingConfig.ProvisionalGames then
        data.provisional = false
        print(string.format('^2[TGW-RATING]^7 %s is no longer provisional (Rating: %d)', identifier, data.rating))
    end

    -- Update rank
    local newRank = CalculateCompetitiveRank(data.rating)
    local rankChanged = oldRank.name ~= newRank.name or oldRank.tier ~= newRank.tier
    data.rank = newRank

    -- Record rating history
    RecordRatingHistory(identifier, oldRating, data.rating, reason, matchContext)

    -- Queue for database save
    QueueRatingUpdate(identifier)

    -- Notify player
    local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)
    if playerId then
        TriggerClientEvent('tgw:rating:updated', playerId, {
            oldRating = oldRating,
            newRating = data.rating,
            change = ratingChange,
            reason = reason,
            rank = newRank,
            rankChanged = rankChanged,
            provisional = data.provisional
        })
    end

    print(string.format('^2[TGW-RATING UPDATE]^7 %s: %d -> %d (%+d) [%s]',
        identifier, oldRating, data.rating, ratingChange, reason))

    RatingStats.totalUpdates = RatingStats.totalUpdates + 1
    RatingStats.averageChange = (RatingStats.averageChange + math.abs(ratingChange)) / 2

    return true
end

function ProcessMatchRatingChanges(resultData)
    if not resultData.players or #resultData.players ~= 2 then
        return
    end

    local player1 = resultData.players[1]
    local player2 = resultData.players[2]

    -- Prepare match context
    local matchContext = {
        roundType = resultData.roundType,
        duration = resultData.duration,
        winner = resultData.winner,
        conditions = {
            forfeit_win = resultData.reason == 'forfeit',
            sudden_death = resultData.sudden_death,
            quick_win = resultData.duration and resultData.duration < 30,
            comeback = resultData.comeback
        }
    }

    -- Calculate rating changes
    local change1, change2 = CalculateRatingChange(player1.identifier, player2.identifier, resultData, matchContext)

    -- Apply rating changes
    local reason = string.format('match_%s', resultData.winner == player1.identifier and 'win' or
                                           resultData.winner == player2.identifier and 'loss' or 'draw')

    UpdateRating(player1.identifier, change1, reason, matchContext)

    reason = string.format('match_%s', resultData.winner == player2.identifier and 'win' or
                                     resultData.winner == player1.identifier and 'loss' or 'draw')

    UpdateRating(player2.identifier, change2, reason, matchContext)
end

-- =====================================================
-- COMPETITIVE RANKING
-- =====================================================

function CalculateCompetitiveRank(rating)
    local currentRank = RatingConfig.CompetitiveRanks[1]

    for _, rank in ipairs(RatingConfig.CompetitiveRanks) do
        if rating >= rank.rating then
            currentRank = rank
        else
            break
        end
    end

    return currentRank
end

function GetNextRank(currentRating)
    for _, rank in ipairs(RatingConfig.CompetitiveRanks) do
        if currentRating < rank.rating then
            return rank
        end
    end
    return nil -- Already at highest rank
end

function GetRankProgress(currentRating)
    local currentRank = CalculateCompetitiveRank(currentRating)
    local nextRank = GetNextRank(currentRating)

    if not nextRank then
        return 1.0 -- Max rank achieved
    end

    local currentThreshold = currentRank.rating
    local nextThreshold = nextRank.rating
    local progress = (currentRating - currentThreshold) / (nextThreshold - currentThreshold)

    return math.max(0, math.min(1, progress))
end

-- =====================================================
-- RATING HISTORY
-- =====================================================

function RecordRatingHistory(identifier, oldRating, newRating, reason, context)
    if not RatingConfig.History.trackHistory then
        return
    end

    if not RatingHistory[identifier] then
        RatingHistory[identifier] = {}
    end

    local historyEntry = {
        timestamp = os.time(),
        oldRating = oldRating,
        newRating = newRating,
        change = newRating - oldRating,
        reason = reason,
        context = context
    }

    table.insert(RatingHistory[identifier], historyEntry)

    -- Limit history size
    if #RatingHistory[identifier] > RatingConfig.History.historyLimit then
        table.remove(RatingHistory[identifier], 1)
    end

    -- Save to database
    MySQL.execute([[
        INSERT INTO tgw_rating_history (identifier, old_rating, new_rating, rating_change, reason, match_context, created_at)
        VALUES (?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?))
    ]], {
        identifier, oldRating, newRating, newRating - oldRating, reason,
        context and json.encode(context) or null, os.time()
    })
end

function LoadPlayerRatingHistory(identifier)
    if not RatingConfig.History.trackHistory then
        return
    end

    MySQL.query([[
        SELECT old_rating, new_rating, rating_change, reason, match_context, UNIX_TIMESTAMP(created_at) as timestamp
        FROM tgw_rating_history
        WHERE identifier = ?
        ORDER BY created_at DESC
        LIMIT ?
    ]], {identifier, RatingConfig.History.historyLimit}, function(results)
        if results then
            RatingHistory[identifier] = {}
            for _, row in ipairs(results) do
                table.insert(RatingHistory[identifier], {
                    timestamp = row.timestamp,
                    oldRating = row.old_rating,
                    newRating = row.new_rating,
                    change = row.rating_change,
                    reason = row.reason,
                    context = row.match_context and json.decode(row.match_context) or nil
                })
            end
        end
    end)
end

function GetRatingHistory(identifier, limit)
    limit = limit or 20
    local history = RatingHistory[identifier] or {}

    local result = {}
    for i = 1, math.min(limit, #history) do
        table.insert(result, history[i])
    end

    return result
end

-- =====================================================
-- RATING DECAY SYSTEM
-- =====================================================

function StartRatingDecay()
    if not RatingConfig.Decay.enabled then
        return
    end

    CreateThread(function()
        while true do
            Wait(RatingConfig.Decay.decayInterval * 1000)
            ProcessRatingDecay()
        end
    end)
end

function ProcessRatingDecay()
    local currentTime = os.time()
    local decayThreshold = RatingConfig.Decay.inactivityDays * 86400 -- Convert to seconds

    for identifier, data in pairs(PlayerRatings) do
        if data.rating > RatingConfig.Decay.decayThreshold then
            local timeSinceLastGame = currentTime - data.lastGameDate

            if timeSinceLastGame > decayThreshold then
                local daysInactive = math.floor(timeSinceLastGame / 86400)
                local decayAmount = math.min(RatingConfig.Decay.maxDecay,
                                           (daysInactive - RatingConfig.Decay.inactivityDays) * RatingConfig.Decay.decayRate)

                if decayAmount > 0 then
                    UpdateRating(identifier, -decayAmount, 'decay', {decay = true})
                    print(string.format('^3[TGW-RATING DECAY]^7 %s lost %d rating due to inactivity',
                        identifier, decayAmount))
                end
            end
        end
    end
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function GetPlayerWinStreak(identifier)
    -- This would integrate with ladder system to get current win streak
    local ladderExport = exports['tgw_ladder']
    if ladderExport then
        local stats = ladderExport:GetPlayerStats(identifier)
        return stats.current_streak or 0
    end
    return 0
end

function QueueRatingUpdate(identifier)
    PendingUpdates[identifier] = os.time()
end

function SendPlayerRatingData(identifier, playerId)
    local data = PlayerRatings[identifier]
    if data then
        local progress = GetRankProgress(data.rating)
        local nextRank = GetNextRank(data.rating)

        TriggerClientEvent('tgw:rating:playerData', playerId, {
            rating = data.rating,
            peakRating = data.peakRating,
            gamesPlayed = data.gamesPlayed,
            provisional = data.provisional,
            rank = data.rank,
            nextRank = nextRank,
            rankProgress = progress,
            seasonRating = data.seasonRating,
            seasonGames = data.seasonGames
        })
    end
end

function RecalibratePlayerRating(identifier)
    local data = PlayerRatings[identifier]
    if not data then
        return false
    end

    -- Apply soft reset formula
    local formula = RatingConfig.Recalibration.resetFormula
    local newRating = math.floor(
        (data.rating * formula.factor) +
        (formula.baseline * formula.pullStrength)
    )

    newRating = math.max(RatingConfig.MinRating, math.min(RatingConfig.MaxRating, newRating))

    local change = newRating - data.rating
    UpdateRating(identifier, change, 'recalibration', {recalibration = true})

    print(string.format('^2[TGW-RATING RECALIBRATION]^7 %s: %d -> %d', identifier, data.rating, newRating))
    return true
end

function StartPerformanceMonitoring()
    CreateThread(function()
        while true do
            Wait(RatingConfig.Performance.updateInterval)

            -- Process pending updates
            local toSave = {}
            local currentTime = os.time()

            for identifier, queueTime in pairs(PendingUpdates) do
                if currentTime - queueTime >= 2 then -- Save after 2 seconds
                    table.insert(toSave, identifier)
                    PendingUpdates[identifier] = nil
                end
            end

            for _, identifier in ipairs(toSave) do
                SavePlayerRating(identifier)
            end

            -- Log statistics every 5 minutes
            if currentTime % 300 == 0 then
                print(string.format('^2[TGW-RATING STATS]^7 Calculations: %d, Updates: %d, Avg Change: %.1f, Suspicious: %d',
                    RatingStats.totalCalculations,
                    RatingStats.totalUpdates,
                    RatingStats.averageChange,
                    RatingStats.suspiciousActivity
                ))
            end
        end
    end)
end

function InitializeRatingSystem()
    -- Load active players' ratings
    local players = ESX.GetPlayers()
    for _, playerId in ipairs(players) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            LoadPlayerRating(xPlayer.identifier)
        end
    end
end

function LoadSeasonData()
    -- Load current season information
    MySQL.query('SELECT * FROM tgw_seasons WHERE active = 1 LIMIT 1', {}, function(results)
        if results and #results > 0 then
            SeasonData = results[1]
            print(string.format('^2[TGW-RATING]^7 Loaded season data: Season %d', SeasonData.season_number or 1))
        else
            -- Create first season
            CreateNewSeason()
        end
    end)
end

function CreateNewSeason()
    local seasonNumber = 1
    local startDate = os.time()
    local endDate = startDate + (RatingConfig.Recalibration.seasonLength * 86400)

    MySQL.execute([[
        INSERT INTO tgw_seasons (season_number, start_date, end_date, active)
        VALUES (?, FROM_UNIXTIME(?), FROM_UNIXTIME(?), 1)
    ]], {seasonNumber, startDate, endDate})

    SeasonData = {
        season_number = seasonNumber,
        start_date = startDate,
        end_date = endDate,
        active = true
    }

    print(string.format('^2[TGW-RATING]^7 Created new season: Season %d', seasonNumber))
end

function CleanupPlayerData(identifier)
    -- Keep data in memory for a while in case of reconnection
    CreateThread(function()
        Wait(300000) -- 5 minutes
        if PlayerRatings[identifier] then
            PlayerRatings[identifier] = nil
        end
        if RatingHistory[identifier] then
            RatingHistory[identifier] = nil
        end
    end)
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('GetPlayerRating', function(identifier)
    return PlayerRatings[identifier] and PlayerRatings[identifier].rating or RatingConfig.DefaultRating
end)

exports('CalculateRatingChange', CalculateRatingChange)
exports('UpdateRating', UpdateRating)
exports('GetRatingHistory', GetRatingHistory)

exports('GetCompetitiveRank', function(identifier)
    return PlayerRatings[identifier] and PlayerRatings[identifier].rank or CalculateCompetitiveRank(RatingConfig.DefaultRating)
end)

exports('GetSeasonRating', function(identifier)
    return PlayerRatings[identifier] and PlayerRatings[identifier].seasonRating or RatingConfig.DefaultRating
end)

exports('RecalibrateRating', RecalibratePlayerRating)

-- =====================================================
-- ADMIN COMMANDS
-- =====================================================

RegisterCommand('tgw_rating_stats', function(source, args, rawCommand)
    if source == 0 then -- Console only
        print('^2[TGW-RATING STATS]^7')
        print(string.format('  Total Calculations: %d', RatingStats.totalCalculations))
        print(string.format('  Total Updates: %d', RatingStats.totalUpdates))
        print(string.format('  Average Change: %.1f', RatingStats.averageChange))
        print(string.format('  Suspicious Activity: %d', RatingStats.suspiciousActivity))
        print(string.format('  Active Players: %d', GetActivePlayerCount()))
    end
end, true)

RegisterCommand('tgw_rating_info', function(source, args, rawCommand)
    if source == 0 and args[1] then -- Console only
        local identifier = args[1]
        local data = PlayerRatings[identifier]
        if data then
            print(string.format('^2[TGW-RATING INFO]^7 %s:', identifier))
            print(string.format('  Rating: %d (Peak: %d)', data.rating, data.peakRating))
            print(string.format('  Games: %d (Provisional: %s)', data.gamesPlayed, data.provisional and 'Yes' or 'No'))
            print(string.format('  Rank: %s %s %s', data.rank.icon, data.rank.name, data.rank.tier or ''))
            print(string.format('  Season: %d rating, %d games', data.seasonRating, data.seasonGames))
        else
            print(string.format('^1[TGW-RATING]^7 No data found for: %s', identifier))
        end
    end
end, true)

function GetActivePlayerCount()
    local count = 0
    for _ in pairs(PlayerRatings) do
        count = count + 1
    end
    return count
end

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Save all player ratings
        for identifier, _ in pairs(PlayerRatings) do
            SavePlayerRating(identifier)
        end

        print('^2[TGW-RATING]^7 Rating system stopped, all data saved')
    end
end)