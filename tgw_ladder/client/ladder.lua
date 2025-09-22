-- =====================================================
-- TGW LADDER CLIENT - LADDER UI AND PROGRESSION DISPLAY
-- =====================================================
-- Purpose: Display level progression, XP gains, and leaderboards
-- Dependencies: tgw_core
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']

-- Client ladder state
local PlayerLadderData = nil
local LeaderboardData = {}
local ActiveNotifications = {}

-- Display settings
local ShowLadderHUD = true
local XPAnimationQueue = {}
local LevelUpAnimation = false

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
    RequestLadderData()
    StartHUDSystem()

    print('^2[TGW-LADDER CLIENT]^7 Ladder client system initialized')
end)

function RegisterEventHandlers()
    -- Ladder data events
    RegisterNetEvent('tgw:ladder:playerData', function(data)
        PlayerLadderData = data
        print(string.format('^2[TGW-LADDER CLIENT]^7 Received ladder data: Level %d (%d XP)', data.level, data.xp))
    end)

    RegisterNetEvent('tgw:ladder:xpGained', function(amount, reason, newLevel, newXP)
        HandleXPGain(amount, reason, newLevel, newXP)
    end)

    RegisterNetEvent('tgw:ladder:levelUp', function(oldLevel, newLevel, rank)
        HandleLevelUp(oldLevel, newLevel, rank)
    end)

    RegisterNetEvent('tgw:ladder:globalLevelUp', function(identifier, level, rank)
        HandleGlobalLevelUp(identifier, level, rank)
    end)

    RegisterNetEvent('tgw:ladder:achievement', function(achievementId, achievement)
        HandleAchievement(achievementId, achievement)
    end)

    RegisterNetEvent('tgw:ladder:leaderboardData', function(leaderboardType, data)
        LeaderboardData[leaderboardType] = data
        if CurrentLeaderboardMenu == leaderboardType then
            RefreshLeaderboardMenu()
        end
    end)

    RegisterNetEvent('tgw:ladder:levelReward', function(identifier, level, reward)
        HandleLevelReward(identifier, level, reward)
    end)

    -- Game state events
    RegisterNetEvent('tgw:queue:joined', function()
        RequestLadderData() -- Refresh data when joining queue
    end)

    RegisterNetEvent('tgw:round:result', function(resultData)
        -- XP will be awarded server-side, just refresh display
        Wait(2000) -- Wait for server processing
        RequestLadderData()
    end)
end

function RegisterCommands()
    -- Main ladder command
    RegisterCommand('ladder', function(source, args, rawCommand)
        if args[1] then
            if args[1] == 'leaderboard' or args[1] == 'lb' then
                OpenLeaderboardMenu(args[2])
            elseif args[1] == 'stats' then
                ShowPlayerStats()
            elseif args[1] == 'progress' then
                ShowProgressInfo()
            else
                ShowLadderHelp()
            end
        else
            OpenLadderMenu()
        end
    end, false)

    -- Quick leaderboard commands
    RegisterCommand('leaderboard', function(source, args, rawCommand)
        OpenLeaderboardMenu(args[1])
    end, false)

    RegisterCommand('lb', function(source, args, rawCommand)
        OpenLeaderboardMenu(args[1])
    end, false)

    -- Stats command
    RegisterCommand('stats', function(source, args, rawCommand)
        ShowPlayerStats()
    end, false)

    -- Progress command
    RegisterCommand('progress', function(source, args, rawCommand)
        ShowProgressInfo()
    end, false)

    -- Toggle HUD command
    RegisterCommand('toggle_ladder_hud', function(source, args, rawCommand)
        ShowLadderHUD = not ShowLadderHUD
        TGWCore.ShowTGWNotification(
            string.format('Ladder HUD %s', ShowLadderHUD and 'enabled' or 'disabled'),
            'info',
            2000
        )
    end, false)
end

-- =====================================================
-- DATA MANAGEMENT
-- =====================================================

function RequestLadderData()
    TriggerServerEvent('tgw:ladder:requestData')
end

function RequestLeaderboard(leaderboardType)
    TriggerServerEvent('tgw:ladder:requestLeaderboard', leaderboardType)
end

-- =====================================================
-- XP AND LEVEL NOTIFICATIONS
-- =====================================================

function HandleXPGain(amount, reason, newLevel, newXP)
    -- Update local data
    if PlayerLadderData then
        PlayerLadderData.xp = newXP
        PlayerLadderData.level = newLevel
    end

    -- Queue XP animation
    table.insert(XPAnimationQueue, {
        amount = amount,
        reason = reason,
        timestamp = GetGameTimer()
    })

    -- Show notification if configured
    if LadderConfig.Display.showXPGains then
        local reasonText = FormatXPReason(reason)
        TGWCore.ShowTGWNotification(
            string.format('+%d XP (%s)', amount, reasonText),
            'success',
            LadderConfig.Display.xpGainDuration
        )
    end
end

function HandleLevelUp(oldLevel, newLevel, rank)
    print(string.format('^2[TGW-LADDER CLIENT]^7 Level up! %d -> %d (Rank: %s)', oldLevel, newLevel, rank.name))

    LevelUpAnimation = true

    -- Update local data
    if PlayerLadderData then
        PlayerLadderData.level = newLevel
        PlayerLadderData.rank = rank
    end

    -- Show level up notification
    if LadderConfig.Display.showLevelUps then
        TGWCore.ShowTGWNotification(
            string.format('🎉 LEVEL UP! 🎉\nLevel %d -> %d\n%s %s', oldLevel, newLevel, rank.icon, rank.name),
            'success',
            LadderConfig.Display.levelUpDuration
        )

        -- Play level up sound
        PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', 1)
    end

    -- Start level up animation
    CreateThread(function()
        Wait(LadderConfig.Display.levelUpDuration)
        LevelUpAnimation = false
    end)
end

function HandleGlobalLevelUp(identifier, level, rank)
    -- Show global notification for significant levels
    if level % 25 == 0 or level >= 75 then
        local playerName = GetPlayerNameByIdentifier(identifier)
        TGWCore.ShowTGWNotification(
            string.format('%s reached Level %d!\n%s %s', playerName, level, rank.icon, rank.name),
            'info',
            4000
        )
    end
end

function HandleAchievement(achievementId, achievement)
    print(string.format('^2[TGW-LADDER CLIENT]^7 Achievement unlocked: %s', achievement.name))

    -- Show achievement notification
    if LadderConfig.Display.showAchievements then
        TGWCore.ShowTGWNotification(
            string.format('🏆 ACHIEVEMENT UNLOCKED! 🏆\n%s\n%s\n+%d XP',
                achievement.name,
                achievement.description,
                achievement.xp or 0
            ),
            'success',
            6000
        )

        -- Play achievement sound
        PlaySoundFrontend(-1, 'MEDAL_UP', 'HUD_MINI_GAME_SOUNDSET', 1)
    end
end

function HandleLevelReward(identifier, level, reward)
    if GetPlayerNameByIdentifier(identifier) == GetPlayerName(PlayerId()) then
        -- Player's own level reward
        TGWCore.ShowTGWNotification(
            string.format('🎁 LEVEL %d REWARD! 🎁\nTitle: %s', level, reward.title or 'None'),
            'success',
            5000
        )
    else
        -- Other player's level reward (global announcement)
        local playerName = GetPlayerNameByIdentifier(identifier)
        TGWCore.ShowTGWNotification(
            string.format('%s earned Level %d rewards!', playerName, level),
            'info',
            3000
        )
    end
end

-- =====================================================
-- HUD SYSTEM
-- =====================================================

function StartHUDSystem()
    CreateThread(function()
        while true do
            Wait(0)

            if ShowLadderHUD and PlayerLadderData then
                DrawLadderHUD()
            end

            -- Draw XP animations
            DrawXPAnimations()

            -- Draw level up animation
            if LevelUpAnimation then
                DrawLevelUpAnimation()
            end
        end
    end)
end

function DrawLadderHUD()
    if not LadderConfig.Display.showLevelInHUD then
        return
    end

    local data = PlayerLadderData
    local rank = data.rank or {name = 'Unknown', icon = '?', color = {255, 255, 255}}

    -- Calculate level progress
    local nextLevelXP = CalculateNextLevelXP(data.level)
    local currentLevelXP = CalculateCurrentLevelXP(data.level)
    local progress = 0

    if nextLevelXP > currentLevelXP then
        progress = (data.xp - currentLevelXP) / (nextLevelXP - currentLevelXP)
    end

    -- HUD position
    local hudX = 0.02
    local hudY = 0.85

    -- Background
    DrawRect(hudX + 0.08, hudY + 0.03, 0.16, 0.06, 0, 0, 0, 150)

    -- Level text
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.4, 0.4)
    SetTextColour(rank.color[1], rank.color[2], rank.color[3], 255)
    SetTextEntry('STRING')
    AddTextComponentString(string.format('%s Level %d', rank.icon, data.level))
    DrawText(hudX, hudY)

    -- XP text
    SetTextScale(0.35, 0.35)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry('STRING')
    AddTextComponentString(string.format('%d / %d XP', data.xp, nextLevelXP))
    DrawText(hudX, hudY + 0.025)

    -- Progress bar
    local barWidth = 0.15
    local barHeight = 0.008
    local barX = hudX + 0.005
    local barY = hudY + 0.045

    -- Progress bar background
    DrawRect(barX + (barWidth / 2), barY + (barHeight / 2), barWidth, barHeight, 50, 50, 50, 200)

    -- Progress bar fill
    local fillWidth = barWidth * progress
    if fillWidth > 0 then
        DrawRect(barX + (fillWidth / 2), barY + (barHeight / 2), fillWidth, barHeight, rank.color[1], rank.color[2], rank.color[3], 255)
    end
end

function DrawXPAnimations()
    if not LadderConfig.Display.animateXPGains then
        return
    end

    local currentTime = GetGameTimer()
    local animationDuration = LadderConfig.Display.xpGainDuration

    for i = #XPAnimationQueue, 1, -1 do
        local animation = XPAnimationQueue[i]
        local elapsed = currentTime - animation.timestamp

        if elapsed > animationDuration then
            table.remove(XPAnimationQueue, i)
        else
            -- Calculate animation position
            local progress = elapsed / animationDuration
            local alpha = math.floor((1 - progress) * 255)
            local yOffset = progress * 0.1

            -- Draw floating XP text
            SetTextFont(4)
            SetTextProportional(true)
            SetTextScale(0.5, 0.5)
            SetTextColour(0, 255, 0, alpha)
            SetTextCentre(true)
            SetTextEntry('STRING')
            AddTextComponentString(string.format('+%d XP', animation.amount))
            DrawText(0.85, 0.75 - yOffset)
        end
    end
end

function DrawLevelUpAnimation()
    -- Simple level up animation - could be enhanced with particles, etc.
    local alpha = math.floor((math.sin(GetGameTimer() / 200) * 0.5 + 0.5) * 255)

    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(1.0, 1.0)
    SetTextColour(255, 215, 0, alpha)
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString('✨ LEVEL UP! ✨')
    DrawText(0.5, 0.3)
end

-- =====================================================
-- MENU SYSTEMS
-- =====================================================

CurrentLeaderboardMenu = nil

function OpenLadderMenu()
    local elements = {}

    if PlayerLadderData then
        local rank = PlayerLadderData.rank or {name = 'Unknown', icon = '?'}
        local nextLevel = CalculateNextLevelXP(PlayerLadderData.level)
        local progress = CalculateProgressToNextLevel()

        table.insert(elements, {
            label = string.format('Level: %d (%s %s)', PlayerLadderData.level, rank.icon, rank.name),
            description = string.format('XP: %d / %d (%.1f%%)', PlayerLadderData.xp, nextLevel, progress * 100)
        })

        table.insert(elements, {label = '─────────────────'})
    end

    table.insert(elements, {label = 'View Leaderboards', value = 'leaderboards'})
    table.insert(elements, {label = 'Player Statistics', value = 'stats'})
    table.insert(elements, {label = 'Progress Information', value = 'progress'})
    table.insert(elements, {label = 'Achievement List', value = 'achievements'})

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'tgw_ladder_main', {
        title = 'TGW Ladder System',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        if data.current.value == 'leaderboards' then
            menu.close()
            OpenLeaderboardMenu()
        elseif data.current.value == 'stats' then
            menu.close()
            ShowPlayerStats()
        elseif data.current.value == 'progress' then
            menu.close()
            ShowProgressInfo()
        elseif data.current.value == 'achievements' then
            menu.close()
            ShowAchievements()
        end
    end, function(data, menu)
        menu.close()
    end)
end

function OpenLeaderboardMenu(leaderboardType)
    CurrentLeaderboardMenu = leaderboardType or 'level'

    local elements = {}

    -- Add leaderboard type selector
    for lbType, config in pairs(LadderConfig.Leaderboards) do
        local selected = lbType == CurrentLeaderboardMenu
        table.insert(elements, {
            label = (selected and '>>> ' or '') .. config.name .. (selected and ' <<<' or ''),
            value = 'type_' .. lbType
        })
    end

    table.insert(elements, {label = '─────────────────'})

    -- Add leaderboard data
    local leaderboard = LeaderboardData[CurrentLeaderboardMenu] or {}
    if #leaderboard == 0 then
        RequestLeaderboard(CurrentLeaderboardMenu)
        table.insert(elements, {label = 'Loading...', description = 'Fetching leaderboard data'})
    else
        for _, entry in ipairs(leaderboard) do
            local playerName = GetPlayerNameByIdentifier(entry.identifier) or 'Unknown'
            local description = FormatLeaderboardEntry(entry, CurrentLeaderboardMenu)

            table.insert(elements, {
                label = string.format('#%d %s', entry.rank, playerName),
                description = description
            })
        end
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'tgw_leaderboard', {
        title = 'TGW Leaderboards - ' .. (LadderConfig.Leaderboards[CurrentLeaderboardMenu].name or 'Unknown'),
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        if data.current.value and string.find(data.current.value, 'type_') then
            local newType = string.gsub(data.current.value, 'type_', '')
            CurrentLeaderboardMenu = newType
            RequestLeaderboard(newType)
            menu.close()
            Wait(500)
            OpenLeaderboardMenu(newType)
        end
    end, function(data, menu)
        menu.close()
        CurrentLeaderboardMenu = nil
    end)
end

function RefreshLeaderboardMenu()
    if CurrentLeaderboardMenu then
        ESX.UI.Menu.CloseAll()
        OpenLeaderboardMenu(CurrentLeaderboardMenu)
    end
end

-- =====================================================
-- INFORMATION DISPLAYS
-- =====================================================

function ShowPlayerStats()
    if not PlayerLadderData or not PlayerLadderData.stats then
        TGWCore.ShowTGWNotification('No statistics available', 'error', 2000)
        return
    end

    local stats = PlayerLadderData.stats
    local elements = {}

    -- Match statistics
    table.insert(elements, {label = 'MATCH STATISTICS', description = ''})
    table.insert(elements, {
        label = string.format('Total Matches: %d', stats.total_matches or 0),
        description = string.format('W: %d | L: %d | D: %d', stats.wins or 0, stats.losses or 0, stats.draws or 0)
    })

    local winRate = 0
    if (stats.wins or 0) + (stats.losses or 0) + (stats.draws or 0) > 0 then
        winRate = ((stats.wins or 0) * 100) / ((stats.wins or 0) + (stats.losses or 0) + (stats.draws or 0))
    end

    table.insert(elements, {
        label = string.format('Win Rate: %.1f%%', winRate),
        description = string.format('Current Streak: %d | Best Streak: %d', stats.current_streak or 0, stats.best_streak or 0)
    })

    table.insert(elements, {label = '─────────────────'})

    -- Kill statistics
    table.insert(elements, {label = 'COMBAT STATISTICS', description = ''})
    table.insert(elements, {
        label = string.format('Total Kills: %d', stats.total_kills or 0),
        description = string.format('Headshots: %d | Long Range: %d | Close Range: %d',
            stats.headshot_kills or 0, stats.long_range_kills or 0, stats.close_range_kills or 0)
    })

    table.insert(elements, {
        label = string.format('Special Achievements', ''),
        description = string.format('Perfect Rounds: %d | Comeback Wins: %d | Clutch Kills: %d',
            stats.perfect_rounds or 0, stats.comeback_wins or 0, stats.clutch_kills or 0)
    })

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'tgw_stats', {
        title = 'Player Statistics',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        -- No action needed for stats display
    end, function(data, menu)
        menu.close()
    end)
end

function ShowProgressInfo()
    if not PlayerLadderData then
        TGWCore.ShowTGWNotification('No progression data available', 'error', 2000)
        return
    end

    local data = PlayerLadderData
    local nextLevelXP = CalculateNextLevelXP(data.level)
    local currentLevelXP = CalculateCurrentLevelXP(data.level)
    local remainingXP = nextLevelXP - data.xp
    local progress = CalculateProgressToNextLevel()

    local elements = {}

    table.insert(elements, {
        label = string.format('Current Level: %d', data.level),
        description = string.format('Rank: %s %s', data.rank.icon, data.rank.name)
    })

    table.insert(elements, {
        label = string.format('Experience Points: %d', data.xp),
        description = string.format('Next Level: %d XP (Need %d more)', nextLevelXP, remainingXP)
    })

    table.insert(elements, {
        label = string.format('Progress: %.1f%%', progress * 100),
        description = string.format('XP for this level: %d / %d', data.xp - currentLevelXP, nextLevelXP - currentLevelXP)
    })

    table.insert(elements, {label = '─────────────────'})

    -- Show next rank information
    local nextRank = GetNextRank(data.level)
    if nextRank then
        table.insert(elements, {
            label = string.format('Next Rank: %s %s', nextRank.icon, nextRank.name),
            description = string.format('Required Level: %d (%d levels to go)', nextRank.level, nextRank.level - data.level)
        })
    else
        table.insert(elements, {
            label = 'Maximum Rank Achieved!',
            description = 'You have reached the highest rank available'
        })
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'tgw_progress', {
        title = 'Progression Information',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        -- No action needed for progress display
    end, function(data, menu)
        menu.close()
    end)
end

function ShowAchievements()
    TGWCore.ShowTGWNotification('Achievement system coming soon!', 'info', 3000)
end

function ShowLadderHelp()
    local helpText = [[
TGW Ladder System Commands:

/ladder - Open main ladder menu
/ladder leaderboard - View leaderboards
/ladder stats - View your statistics
/ladder progress - View progression info

/leaderboard [type] - Quick leaderboard access
/lb [type] - Short leaderboard command
/stats - Quick stats display
/progress - Quick progress display

/toggle_ladder_hud - Toggle HUD display
]]

    TGWCore.ShowTGWNotification(helpText, 'info', 10000)
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function FormatXPReason(reason)
    local reasonMap = {
        match_win = 'Match Victory',
        match_loss = 'Match Participation',
        match_draw = 'Match Draw',
        quick_win = 'Quick Victory',
        sudden_death_win = 'Sudden Death',
        perfect_round = 'Perfect Round',
        headshot_kill = 'Headshot',
        long_range_kill = 'Long Range',
        close_range_kill = 'Close Range',
        win_streak_2 = 'Win Streak',
        win_streak_5 = 'Hot Streak',
        win_streak_10 = 'Unstoppable',
        level_reward = 'Level Reward',
        achievement = 'Achievement'
    }

    return reasonMap[reason] or reason:gsub('_', ' '):gsub('^%l', string.upper)
end

function FormatLeaderboardEntry(entry, leaderboardType)
    if leaderboardType == 'level' then
        return string.format('Level %d (%d XP)', entry.level, entry.xp)
    elseif leaderboardType == 'rating' then
        return string.format('Rating: %d', entry.rating or 0)
    elseif leaderboardType == 'wins' then
        return string.format('%d Wins', entry.wins)
    elseif leaderboardType == 'winrate' then
        return string.format('%.1f%% Win Rate (%d games)', entry.win_rate, (entry.wins + entry.losses + entry.draws))
    elseif leaderboardType == 'streak' then
        return string.format('%d Win Streak', entry.current_streak)
    end

    return 'Unknown'
end

function CalculateNextLevelXP(level)
    -- This should match server-side calculation
    if LadderConfig.XPRequirements[level + 1] then
        return LadderConfig.XPRequirements[level + 1]
    end

    local formula = LadderConfig.XPFormula
    return math.floor(formula.baseXP * (formula.multiplier ^ level) + (formula.linearBonus * (level + 1)))
end

function CalculateCurrentLevelXP(level)
    if LadderConfig.XPRequirements[level] then
        return LadderConfig.XPRequirements[level]
    end

    if level <= 1 then
        return 0
    end

    local formula = LadderConfig.XPFormula
    return math.floor(formula.baseXP * (formula.multiplier ^ (level - 1)) + (formula.linearBonus * level))
end

function CalculateProgressToNextLevel()
    if not PlayerLadderData then
        return 0
    end

    local currentXP = PlayerLadderData.xp
    local currentLevelXP = CalculateCurrentLevelXP(PlayerLadderData.level)
    local nextLevelXP = CalculateNextLevelXP(PlayerLadderData.level)

    if nextLevelXP <= currentLevelXP then
        return 1 -- Max level
    end

    return (currentXP - currentLevelXP) / (nextLevelXP - currentLevelXP)
end

function GetNextRank(currentLevel)
    for _, rank in ipairs(LadderConfig.Ranks) do
        if rank.level > currentLevel then
            return rank
        end
    end
    return nil
end

function GetPlayerNameByIdentifier(identifier)
    -- This would normally get the player name from the server
    -- For now, return a simplified version
    return identifier:sub(-8) -- Last 8 characters of identifier
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('GetPlayerLadderData', function()
    return PlayerLadderData
end)

exports('IsLevelUpAnimationActive', function()
    return LevelUpAnimation
end)

exports('GetXPAnimationQueue', function()
    return XPAnimationQueue
end)

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        ESX.UI.Menu.CloseAll()
    end
end)