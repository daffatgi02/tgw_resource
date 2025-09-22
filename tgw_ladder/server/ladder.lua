-- =====================================================
-- TGW LADDER SERVER - LEVEL PROGRESSION AND RANKING
-- =====================================================
-- Purpose: Manage player levels, XP, ranks, and leaderboards
-- Dependencies: tgw_core, tgw_rating, es_extended
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']

-- Ladder system state
local PlayerLadderData = {}       -- [identifier] = {level, xp, rank, etc.}
local LeaderboardCache = {}       -- Cached leaderboard data
local AchievementCache = {}       -- Player achievement tracking
local XPQueue = {}                -- Queued XP updates

-- Statistics tracking
local LadderStats = {
    totalXPAwarded = 0,
    totalLevelUps = 0,
    totalAchievements = 0,
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
    InitializeLadderSystem()
    StartPerformanceMonitoring()
    StartLeaderboardUpdates()

    print('^2[TGW-LADDER SERVER]^7 Ladder and progression system initialized')
end)

function RegisterEventHandlers()
    -- XP and level events
    RegisterNetEvent('tgw:ladder:requestData', function()
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            SendPlayerLadderData(xPlayer.identifier, src)
        end
    end)

    RegisterNetEvent('tgw:ladder:requestLeaderboard', function(leaderboardType)
        local src = source
        local leaderboard = GetLeaderboard(leaderboardType)
        TriggerClientEvent('tgw:ladder:leaderboardData', src, leaderboardType, leaderboard)
    end)

    -- Match result events for XP rewards
    RegisterNetEvent('tgw:round:result', function(resultData)
        ProcessMatchResult(resultData)
    end)

    RegisterNetEvent('tgw:round:killEvent', function(killerIdentifier, victimIdentifier, killType, distance)
        ProcessKillEvent(killerIdentifier, victimIdentifier, killType, distance)
    end)

    -- Player connection events
    RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
        LoadPlayerLadderData(xPlayer.identifier)
    end)

    RegisterNetEvent('esx:playerDropped', function(playerId, reason)
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            SavePlayerLadderData(xPlayer.identifier)
            CleanupPlayerData(xPlayer.identifier)
        end
    end)

    -- Admin events
    RegisterNetEvent('tgw:ladder:adminAddXP', function(targetIdentifier, amount, reason)
        local src = source
        if TGWCore.IsPlayerAdmin(src) then
            AddXP(targetIdentifier, amount, reason, 'admin')
        end
    end)
end

-- =====================================================
-- LADDER DATA MANAGEMENT
-- =====================================================

function LoadPlayerLadderData(identifier)
    MySQL.query([[
        SELECT level, xp, total_matches, wins, losses, draws, current_streak, best_streak,
               total_kills, headshot_kills, long_range_kills, close_range_kills, clutch_kills,
               perfect_rounds, comeback_wins, upset_victories, total_playtime
        FROM tgw_ladder
        WHERE identifier = ?
    ]], {identifier}, function(results)
        if results and #results > 0 then
            local data = results[1]
            PlayerLadderData[identifier] = {
                level = data.level,
                xp = data.xp,
                rank = CalculateRank(data.level),
                stats = {
                    total_matches = data.total_matches,
                    wins = data.wins,
                    losses = data.losses,
                    draws = data.draws,
                    current_streak = data.current_streak,
                    best_streak = data.best_streak,
                    total_kills = data.total_kills,
                    headshot_kills = data.headshot_kills,
                    long_range_kills = data.long_range_kills,
                    close_range_kills = data.close_range_kills,
                    clutch_kills = data.clutch_kills,
                    perfect_rounds = data.perfect_rounds,
                    comeback_wins = data.comeback_wins,
                    upset_victories = data.upset_victories,
                    total_playtime = data.total_playtime
                },
                lastUpdated = os.time()
            }
        else
            -- Initialize new player
            InitializeNewPlayer(identifier)
        end

        -- Load achievements
        LoadPlayerAchievements(identifier)

        print(string.format('^2[TGW-LADDER]^7 Loaded ladder data for %s (Level %d)',
            identifier, PlayerLadderData[identifier].level))
    end)
end

function InitializeNewPlayer(identifier)
    PlayerLadderData[identifier] = {
        level = 1,
        xp = 0,
        rank = CalculateRank(1),
        stats = {},
        lastUpdated = os.time()
    }

    -- Initialize all tracked stats to 0
    for _, stat in ipairs(LadderConfig.TrackedStats) do
        PlayerLadderData[identifier].stats[stat] = 0
    end

    -- Insert into database
    MySQL.execute([[
        INSERT INTO tgw_ladder (identifier, level, xp)
        VALUES (?, 1, 0)
    ]], {identifier})

    print(string.format('^2[TGW-LADDER]^7 Initialized new player: %s', identifier))
end

function SavePlayerLadderData(identifier)
    local data = PlayerLadderData[identifier]
    if not data then
        return
    end

    local stats = data.stats

    MySQL.execute([[
        UPDATE tgw_ladder SET
            level = ?, xp = ?, total_matches = ?, wins = ?, losses = ?, draws = ?,
            current_streak = ?, best_streak = ?, total_kills = ?, headshot_kills = ?,
            long_range_kills = ?, close_range_kills = ?, clutch_kills = ?,
            perfect_rounds = ?, comeback_wins = ?, upset_victories = ?, total_playtime = ?,
            updated_at = NOW()
        WHERE identifier = ?
    ]], {
        data.level, data.xp, stats.total_matches or 0, stats.wins or 0, stats.losses or 0, stats.draws or 0,
        stats.current_streak or 0, stats.best_streak or 0, stats.total_kills or 0, stats.headshot_kills or 0,
        stats.long_range_kills or 0, stats.close_range_kills or 0, stats.clutch_kills or 0,
        stats.perfect_rounds or 0, stats.comeback_wins or 0, stats.upset_victories or 0, stats.total_playtime or 0,
        identifier
    })

    print(string.format('^2[TGW-LADDER]^7 Saved ladder data for %s', identifier))
end

-- =====================================================
-- XP SYSTEM
-- =====================================================

function AddXP(identifier, amount, reason, source)
    if not PlayerLadderData[identifier] then
        print(string.format('^1[TGW-LADDER ERROR]^7 Player data not found: %s', identifier))
        return false
    end

    -- Anti-cheat validation
    if not ValidateXPGain(identifier, amount, source) then
        print(string.format('^1[TGW-LADDER ANTICHEAT]^7 Suspicious XP gain blocked: %s (+%d)', identifier, amount))
        return false
    end

    local data = PlayerLadderData[identifier]
    local oldLevel = data.level
    local oldXP = data.xp

    -- Apply XP multipliers
    local multipliedAmount = ApplyXPMultipliers(identifier, amount)

    -- Add XP
    data.xp = data.xp + multipliedAmount
    data.lastUpdated = os.time()

    -- Check for level up
    local newLevel = CalculateLevelFromXP(data.xp)
    if newLevel > data.level then
        ProcessLevelUp(identifier, data.level, newLevel)
        data.level = newLevel
        data.rank = CalculateRank(newLevel)
    end

    -- Queue for database save
    QueueXPUpdate(identifier)

    -- Notify player
    local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)
    if playerId then
        TriggerClientEvent('tgw:ladder:xpGained', playerId, multipliedAmount, reason, data.level, data.xp)
    end

    -- Log XP gain
    if LadderConfig.Performance.enableXPLogging then
        print(string.format('^2[TGW-LADDER XP]^7 %s +%d XP (%s) -> Level %d (%d XP)',
            identifier, multipliedAmount, reason, data.level, data.xp))
    end

    LadderStats.totalXPAwarded = LadderStats.totalXPAwarded + multipliedAmount

    return true
end

function ValidateXPGain(identifier, amount, source)
    if amount <= 0 or amount > LadderConfig.AntiCheat.maxXPPerMatch then
        LadderStats.suspiciousActivity = LadderStats.suspiciousActivity + 1
        return false
    end

    -- Check hourly XP limit
    if CheckHourlyXPLimit(identifier, amount) then
        LadderStats.suspiciousActivity = LadderStats.suspiciousActivity + 1
        return false
    end

    return true
end

function CheckHourlyXPLimit(identifier, amount)
    -- This would implement hourly XP tracking
    -- For now, just basic validation
    return amount > LadderConfig.AntiCheat.maxXPPerHour
end

function ApplyXPMultipliers(identifier, amount)
    local multiplier = 1.0
    local data = PlayerLadderData[identifier]

    -- New player bonus
    if data.level <= 10 then
        multiplier = multiplier * LadderConfig.XPMultipliers.new_player
    end

    -- Weekend bonus
    local currentDay = os.date('%w')
    if currentDay == '0' or currentDay == '6' then -- Sunday or Saturday
        multiplier = multiplier * LadderConfig.XPMultipliers.weekend
    end

    -- Comeback bonus (after losses)
    if data.stats.current_streak and data.stats.current_streak < -2 then
        multiplier = multiplier * LadderConfig.XPMultipliers.comeback
    end

    return math.floor(amount * multiplier)
end

function CalculateLevelFromXP(xp)
    -- Check configured levels first
    for level = LadderConfig.MaxLevel, 1, -1 do
        local requiredXP = LadderConfig.XPRequirements[level]
        if requiredXP and xp >= requiredXP then
            return level
        end
    end

    -- Use formula for levels beyond configured
    local level = 1
    local requiredXP = 0

    while requiredXP <= xp and level < LadderConfig.MaxLevel do
        level = level + 1
        requiredXP = CalculateXPRequirement(level)
    end

    return math.min(level - 1, LadderConfig.MaxLevel)
end

function CalculateXPRequirement(level)
    if LadderConfig.XPRequirements[level] then
        return LadderConfig.XPRequirements[level]
    end

    -- Use formula
    local formula = LadderConfig.XPFormula
    return math.floor(formula.baseXP * (formula.multiplier ^ (level - 1)) + (formula.linearBonus * level))
end

function CalculateRank(level)
    local currentRank = LadderConfig.Ranks[1]

    for _, rank in ipairs(LadderConfig.Ranks) do
        if level >= rank.level then
            currentRank = rank
        else
            break
        end
    end

    return currentRank
end

-- =====================================================
-- LEVEL UP SYSTEM
-- =====================================================

function ProcessLevelUp(identifier, oldLevel, newLevel)
    print(string.format('^2[TGW-LADDER LEVELUP]^7 %s leveled up from %d to %d', identifier, oldLevel, newLevel))

    LadderStats.totalLevelUps = LadderStats.totalLevelUps + 1

    -- Check for level rewards
    for level = oldLevel + 1, newLevel do
        local reward = LadderConfig.LevelRewards[level]
        if reward then
            ProcessLevelReward(identifier, level, reward)
        end
    end

    -- Notify player
    local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)
    if playerId then
        local rank = CalculateRank(newLevel)
        TriggerClientEvent('tgw:ladder:levelUp', playerId, oldLevel, newLevel, rank)

        -- Global announcement for significant levels
        if newLevel % 10 == 0 or newLevel >= 50 then
            TriggerClientEvent('tgw:ladder:globalLevelUp', -1, identifier, newLevel, rank)
        end
    end

    -- Check achievements
    CheckAchievements(identifier)
end

function ProcessLevelReward(identifier, level, reward)
    print(string.format('^2[TGW-LADDER REWARD]^7 %s received level %d reward', identifier, level))

    -- Give bonus XP
    if reward.xp then
        AddXP(identifier, reward.xp, 'level_reward', 'system')
    end

    -- Set title
    if reward.title then
        -- This would integrate with a title system
        print(string.format('^2[TGW-LADDER TITLE]^7 %s earned title: %s', identifier, reward.title))
    end

    -- Special rewards
    if reward.specialReward then
        -- This would integrate with an item/reward system
        print(string.format('^2[TGW-LADDER SPECIAL]^7 %s earned special reward: %s', identifier, reward.specialReward))
    end

    -- Global announcement
    if reward.announcement then
        local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)
        if playerId then
            TriggerClientEvent('tgw:ladder:levelReward', -1, identifier, level, reward)
        end
    end
end

-- =====================================================
-- MATCH RESULT PROCESSING
-- =====================================================

function ProcessMatchResult(resultData)
    if not resultData.players or #resultData.players ~= 2 then
        return
    end

    local player1 = resultData.players[1]
    local player2 = resultData.players[2]

    -- Update match statistics
    UpdateMatchStats(player1.identifier, player2.identifier, resultData)

    -- Award XP based on result
    AwardMatchXP(player1.identifier, player2.identifier, resultData)

    -- Check for achievements
    CheckAchievements(player1.identifier)
    CheckAchievements(player2.identifier)
end

function UpdateMatchStats(player1Id, player2Id, resultData)
    -- Update match counts
    IncrementStat(player1Id, 'total_matches')
    IncrementStat(player2Id, 'total_matches')

    -- Update win/loss records
    if resultData.winner == player1Id then
        IncrementStat(player1Id, 'wins')
        IncrementStat(player2Id, 'losses')
        UpdateWinStreak(player1Id, true)
        UpdateWinStreak(player2Id, false)
    elseif resultData.winner == player2Id then
        IncrementStat(player2Id, 'wins')
        IncrementStat(player1Id, 'losses')
        UpdateWinStreak(player2Id, true)
        UpdateWinStreak(player1Id, false)
    else
        IncrementStat(player1Id, 'draws')
        IncrementStat(player2Id, 'draws')
    end

    -- Update playtime
    if resultData.duration then
        IncrementStat(player1Id, 'total_playtime', resultData.duration)
        IncrementStat(player2Id, 'total_playtime', resultData.duration)
    end
end

function AwardMatchXP(player1Id, player2Id, resultData)
    local baseXP = {
        win = LadderConfig.XPRewards.win,
        lose = LadderConfig.XPRewards.lose,
        draw = LadderConfig.XPRewards.draw
    }

    if resultData.winner == player1Id then
        AddXP(player1Id, baseXP.win, 'match_win', 'match')
        AddXP(player2Id, baseXP.lose, 'match_loss', 'match')

        -- Bonus XP for specific win conditions
        AwardWinBonusXP(player1Id, resultData)

    elseif resultData.winner == player2Id then
        AddXP(player2Id, baseXP.win, 'match_win', 'match')
        AddXP(player1Id, baseXP.lose, 'match_loss', 'match')

        -- Bonus XP for specific win conditions
        AwardWinBonusXP(player2Id, resultData)

    else
        AddXP(player1Id, baseXP.draw, 'match_draw', 'match')
        AddXP(player2Id, baseXP.draw, 'match_draw', 'match')
    end

    -- Participation XP
    AddXP(player1Id, LadderConfig.XPRewards.match_completed, 'match_completed', 'match')
    AddXP(player2Id, LadderConfig.XPRewards.match_completed, 'match_completed', 'match')
end

function AwardWinBonusXP(identifier, resultData)
    -- Quick win bonus
    if resultData.duration and resultData.duration < 30 then
        AddXP(identifier, LadderConfig.XPRewards.quick_win, 'quick_win', 'bonus')
    end

    -- Sudden death win
    if resultData.sudden_death then
        AddXP(identifier, LadderConfig.XPRewards.sudden_death_win, 'sudden_death_win', 'bonus')
    end

    -- Perfect round (no damage taken)
    if resultData.perfect_round then
        AddXP(identifier, LadderConfig.XPRewards.perfect_round, 'perfect_round', 'bonus')
        IncrementStat(identifier, 'perfect_rounds')
    end

    -- Check win streak bonuses
    local data = PlayerLadderData[identifier]
    if data and data.stats.current_streak then
        local streak = data.stats.current_streak
        if streak >= 10 then
            AddXP(identifier, LadderConfig.XPRewards.win_streak_10, 'win_streak_10', 'bonus')
        elseif streak >= 5 then
            AddXP(identifier, LadderConfig.XPRewards.win_streak_5, 'win_streak_5', 'bonus')
        elseif streak >= 2 then
            AddXP(identifier, LadderConfig.XPRewards.win_streak_2, 'win_streak_2', 'bonus')
        end
    end
end

function ProcessKillEvent(killerIdentifier, victimIdentifier, killType, distance)
    -- Award kill XP
    IncrementStat(killerIdentifier, 'total_kills')

    -- Specific kill type bonuses
    if killType == 'headshot' then
        AddXP(killerIdentifier, LadderConfig.XPRewards.headshot_kill, 'headshot_kill', 'kill')
        IncrementStat(killerIdentifier, 'headshot_kills')
    end

    if distance and distance > 50 then
        AddXP(killerIdentifier, LadderConfig.XPRewards.long_range_kill, 'long_range_kill', 'kill')
        IncrementStat(killerIdentifier, 'long_range_kills')
    elseif distance and distance < 5 then
        AddXP(killerIdentifier, LadderConfig.XPRewards.close_range_kill, 'close_range_kill', 'kill')
        IncrementStat(killerIdentifier, 'close_range_kills')
    end
end

-- =====================================================
-- STATISTICS MANAGEMENT
-- =====================================================

function IncrementStat(identifier, statName, amount)
    if not PlayerLadderData[identifier] then
        return
    end

    amount = amount or 1
    local stats = PlayerLadderData[identifier].stats

    if not stats[statName] then
        stats[statName] = 0
    end

    stats[statName] = stats[statName] + amount

    if LadderConfig.Performance.enableStatLogging then
        print(string.format('^2[TGW-LADDER STAT]^7 %s: %s +%d -> %d', identifier, statName, amount, stats[statName]))
    end
end

function UpdateWinStreak(identifier, isWin)
    local data = PlayerLadderData[identifier]
    if not data then
        return
    end

    local stats = data.stats

    if isWin then
        if stats.current_streak and stats.current_streak >= 0 then
            stats.current_streak = (stats.current_streak or 0) + 1
        else
            stats.current_streak = 1
        end

        if stats.current_streak > (stats.best_streak or 0) then
            stats.best_streak = stats.current_streak
        end
    else
        if stats.current_streak and stats.current_streak <= 0 then
            stats.current_streak = (stats.current_streak or 0) - 1
        else
            stats.current_streak = -1
        end

        if math.abs(stats.current_streak) > math.abs(stats.worst_loss_streak or 0) then
            stats.worst_loss_streak = stats.current_streak
        end
    end
end

-- =====================================================
-- LEADERBOARD SYSTEM
-- =====================================================

function GetLeaderboard(leaderboardType)
    local config = LadderConfig.Leaderboards[leaderboardType]
    if not config then
        return {}
    end

    -- Check cache first
    if LeaderboardCache[leaderboardType] and
       os.time() - LeaderboardCache[leaderboardType].lastUpdate < LadderConfig.LeaderboardRefresh[leaderboardType] then
        return LeaderboardCache[leaderboardType].data
    end

    -- Generate leaderboard
    local leaderboard = GenerateLeaderboard(config)

    -- Cache result
    LeaderboardCache[leaderboardType] = {
        data = leaderboard,
        lastUpdate = os.time()
    }

    return leaderboard
end

function GenerateLeaderboard(config)
    local query = string.format([[
        SELECT identifier, level, xp, wins, losses, draws, current_streak, best_streak,
               CASE WHEN (wins + losses + draws) > 0
                    THEN ROUND((wins * 100.0) / (wins + losses + draws), 2)
                    ELSE 0
               END as win_rate
        FROM tgw_ladder
        %s
        ORDER BY %s %s
        LIMIT %d
    ]],
        config.minGames and string.format('WHERE (wins + losses + draws) >= %d', config.minGames) or '',
        config.sortBy,
        config.sortOrder,
        config.limit
    )

    local results = {}
    MySQL.query(query, {}, function(queryResults)
        if queryResults then
            for i, row in ipairs(queryResults) do
                table.insert(results, {
                    rank = i,
                    identifier = row.identifier,
                    level = row.level,
                    xp = row.xp,
                    wins = row.wins,
                    losses = row.losses,
                    draws = row.draws,
                    current_streak = row.current_streak,
                    best_streak = row.best_streak,
                    win_rate = row.win_rate
                })
            end
        end
    end)

    return results
end

-- =====================================================
-- ACHIEVEMENT SYSTEM
-- =====================================================

function CheckAchievements(identifier)
    local data = PlayerLadderData[identifier]
    if not data then
        return
    end

    for achievementId, achievement in pairs(LadderConfig.Achievements) do
        if not AchievementCache[identifier] then
            AchievementCache[identifier] = {}
        end

        local hasAchievement = AchievementCache[identifier][achievementId]

        if not hasAchievement and achievement.condition(data.stats) then
            AwardAchievement(identifier, achievementId, achievement)
            AchievementCache[identifier][achievementId] = true
        end
    end
end

function AwardAchievement(identifier, achievementId, achievement)
    print(string.format('^2[TGW-LADDER ACHIEVEMENT]^7 %s earned achievement: %s', identifier, achievement.name))

    LadderStats.totalAchievements = LadderStats.totalAchievements + 1

    -- Award XP
    if achievement.xp then
        AddXP(identifier, achievement.xp, 'achievement_' .. achievementId, 'achievement')
    end

    -- Notify player
    local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)
    if playerId then
        TriggerClientEvent('tgw:ladder:achievement', playerId, achievementId, achievement)
    end

    -- Save achievement to database
    MySQL.execute([[
        INSERT INTO tgw_achievements (identifier, achievement_id, earned_at)
        VALUES (?, ?, NOW())
    ]], {identifier, achievementId})
end

function LoadPlayerAchievements(identifier)
    MySQL.query('SELECT achievement_id FROM tgw_achievements WHERE identifier = ?', {identifier}, function(results)
        if results then
            AchievementCache[identifier] = {}
            for _, row in ipairs(results) do
                AchievementCache[identifier][row.achievement_id] = true
            end
        end
    end)
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function QueueXPUpdate(identifier)
    XPQueue[identifier] = os.time()
end

function StartPerformanceMonitoring()
    CreateThread(function()
        while true do
            Wait(LadderConfig.Performance.xpUpdateInterval)

            -- Process queued XP updates
            local toSave = {}
            local currentTime = os.time()

            for identifier, queueTime in pairs(XPQueue) do
                if currentTime - queueTime >= 1 then -- Save after 1 second
                    table.insert(toSave, identifier)
                    XPQueue[identifier] = nil
                end
            end

            for _, identifier in ipairs(toSave) do
                SavePlayerLadderData(identifier)
            end

            -- Log statistics every 5 minutes
            if currentTime % 300 == 0 then
                print(string.format('^2[TGW-LADDER STATS]^7 XP Awarded: %d, Level Ups: %d, Achievements: %d, Suspicious: %d',
                    LadderStats.totalXPAwarded,
                    LadderStats.totalLevelUps,
                    LadderStats.totalAchievements,
                    LadderStats.suspiciousActivity
                ))
            end
        end
    end)
end

function StartLeaderboardUpdates()
    CreateThread(function()
        while true do
            Wait(60000) -- Check every minute

            -- Clear expired leaderboard cache
            for leaderboardType, cacheData in pairs(LeaderboardCache) do
                local refreshInterval = LadderConfig.LeaderboardRefresh[leaderboardType] or 300
                if os.time() - cacheData.lastUpdate > refreshInterval then
                    LeaderboardCache[leaderboardType] = nil
                end
            end
        end
    end)
end

function SendPlayerLadderData(identifier, playerId)
    local data = PlayerLadderData[identifier]
    if data then
        TriggerClientEvent('tgw:ladder:playerData', playerId, data)
    end
end

function CleanupPlayerData(identifier)
    -- Keep data in memory for a while in case of reconnection
    CreateThread(function()
        Wait(300000) -- 5 minutes
        if PlayerLadderData[identifier] then
            PlayerLadderData[identifier] = nil
        end
    end)
end

function InitializeLadderSystem()
    -- Load active players' data
    local players = ESX.GetPlayers()
    for _, playerId in ipairs(players) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            LoadPlayerLadderData(xPlayer.identifier)
        end
    end
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('GetPlayerLevel', function(identifier)
    return PlayerLadderData[identifier] and PlayerLadderData[identifier].level or 1
end)

exports('GetPlayerXP', function(identifier)
    return PlayerLadderData[identifier] and PlayerLadderData[identifier].xp or 0
end)

exports('AddXP', AddXP)

exports('GetLevelInfo', function(level)
    return {
        level = level,
        requiredXP = CalculateXPRequirement(level),
        rank = CalculateRank(level)
    }
end)

exports('GetLeaderboard', GetLeaderboard)

exports('GetPlayerStats', function(identifier)
    return PlayerLadderData[identifier] and PlayerLadderData[identifier].stats or {}
end)

exports('CalculateNextLevel', function(identifier)
    local data = PlayerLadderData[identifier]
    if not data then
        return nil
    end

    local nextLevel = data.level + 1
    local requiredXP = CalculateXPRequirement(nextLevel)
    local remainingXP = requiredXP - data.xp

    return {
        nextLevel = nextLevel,
        requiredXP = requiredXP,
        remainingXP = math.max(0, remainingXP),
        progress = data.xp / requiredXP
    }
end)

exports('GetLevelRewards', function(level)
    return LadderConfig.LevelRewards[level]
end)

-- =====================================================
-- ADMIN COMMANDS
-- =====================================================

RegisterCommand('tgw_ladder_stats', function(source, args, rawCommand)
    if source == 0 then -- Console only
        print('^2[TGW-LADDER STATS]^7')
        print(string.format('  Total XP Awarded: %d', LadderStats.totalXPAwarded))
        print(string.format('  Total Level Ups: %d', LadderStats.totalLevelUps))
        print(string.format('  Total Achievements: %d', LadderStats.totalAchievements))
        print(string.format('  Suspicious Activity: %d', LadderStats.suspiciousActivity))
        print(string.format('  Active Players: %d', GetActivePlayerCount()))
    end
end, true)

function GetActivePlayerCount()
    local count = 0
    for _ in pairs(PlayerLadderData) do
        count = count + 1
    end
    return count
end

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Save all player data
        for identifier, _ in pairs(PlayerLadderData) do
            SavePlayerLadderData(identifier)
        end

        print('^2[TGW-LADDER]^7 Ladder system stopped, all data saved')
    end
end)