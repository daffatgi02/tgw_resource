-- =====================================================
-- TGW RATING CLIENT - RATING DISPLAY AND UI
-- =====================================================
-- Purpose: Display ELO ratings, ranks, and rating changes
-- Dependencies: tgw_core
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']

-- Client rating state
local PlayerRatingData = nil
local RatingHistory = {}
local ActiveRatingAnimations = {}

-- Display settings
local ShowRatingHUD = true
local RatingChangeQueue = {}
local RankUpAnimation = false

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
    RequestRatingData()
    StartHUDSystem()

    print('^2[TGW-RATING CLIENT]^7 Rating client system initialized')
end)

function RegisterEventHandlers()
    -- Rating data events
    RegisterNetEvent('tgw:rating:playerData', function(data)
        PlayerRatingData = data
        print(string.format('^2[TGW-RATING CLIENT]^7 Received rating data: %d (%s %s)',
            data.rating, data.rank.name, data.rank.tier or ''))
    end)

    RegisterNetEvent('tgw:rating:updated', function(updateData)
        HandleRatingUpdate(updateData)
    end)

    RegisterNetEvent('tgw:rating:historyData', function(history)
        RatingHistory = history
        if CurrentRatingMenu then
            RefreshRatingMenu()
        end
    end)

    -- Game state events
    RegisterNetEvent('tgw:queue:joined', function()
        RequestRatingData() -- Refresh rating when joining queue
    end)

    RegisterNetEvent('tgw:round:result', function(resultData)
        -- Rating will be updated server-side, wait for update
        Wait(3000)
        RequestRatingData()
    end)
end

function RegisterCommands()
    -- Main rating command
    RegisterCommand('rating', function(source, args, rawCommand)
        if args[1] then
            if args[1] == 'history' then
                ShowRatingHistory()
            elseif args[1] == 'leaderboard' or args[1] == 'lb' then
                ShowRatingLeaderboard()
            elseif args[1] == 'rank' then
                ShowRankInfo()
            else
                ShowRatingHelp()
            end
        else
            OpenRatingMenu()
        end
    end, false)

    -- Quick rating commands
    RegisterCommand('rank', function(source, args, rawCommand)
        ShowRankInfo()
    end, false)

    RegisterCommand('elo', function(source, args, rawCommand)
        ShowCurrentRating()
    end, false)

    RegisterCommand('rating_history', function(source, args, rawCommand)
        ShowRatingHistory()
    end, false)

    -- Toggle HUD command
    RegisterCommand('toggle_rating_hud', function(source, args, rawCommand)
        ShowRatingHUD = not ShowRatingHUD
        TGWCore.ShowTGWNotification(
            string.format('Rating HUD %s', ShowRatingHUD and 'enabled' or 'disabled'),
            'info',
            2000
        )
    end, false)
end

-- =====================================================
-- DATA MANAGEMENT
-- =====================================================

function RequestRatingData()
    TriggerServerEvent('tgw:rating:requestData')
end

function RequestRatingHistory(limit)
    TriggerServerEvent('tgw:rating:requestHistory', limit or 20)
end

-- =====================================================
-- RATING UPDATE HANDLING
-- =====================================================

function HandleRatingUpdate(updateData)
    -- Update local data
    if PlayerRatingData then
        PlayerRatingData.rating = updateData.newRating
        PlayerRatingData.rank = updateData.rank
    end

    -- Queue rating change animation
    table.insert(RatingChangeQueue, {
        oldRating = updateData.oldRating,
        newRating = updateData.newRating,
        change = updateData.change,
        reason = updateData.reason,
        timestamp = GetGameTimer()
    })

    -- Show rating change notification
    if RatingConfig.Display.ratingChangeNotifications then
        local changeText = FormatRatingChange(updateData.change)
        local reasonText = FormatRatingReason(updateData.reason)

        local notifType = updateData.change > 0 and 'success' or updateData.change < 0 and 'error' or 'info'
        TGWCore.ShowTGWNotification(
            string.format('Rating: %s (%s)\n%d -> %d', changeText, reasonText, updateData.oldRating, updateData.newRating),
            notifType,
            4000
        )
    end

    -- Handle rank change
    if updateData.rankChanged then
        HandleRankChange(updateData)
    end

    print(string.format('^2[TGW-RATING CLIENT]^7 Rating updated: %d -> %d (%+d)',
        updateData.oldRating, updateData.newRating, updateData.change))
end

function HandleRankChange(updateData)
    local rank = updateData.rank

    if RatingConfig.Display.rankUpNotifications and updateData.change > 0 then
        RankUpAnimation = true
        TGWCore.ShowTGWNotification(
            string.format('🎉 RANK UP! 🎉\n%s %s %s\nRating: %d',
                rank.icon, rank.name, rank.tier or '', updateData.newRating),
            'success',
            6000
        )

        -- Play rank up sound
        PlaySoundFrontend(-1, 'RANK_UP', 'HUD_AWARDS', 1)

        -- Stop animation after delay
        CreateThread(function()
            Wait(6000)
            RankUpAnimation = false
        end)

    elseif RatingConfig.Display.rankDownNotifications and updateData.change < 0 then
        TGWCore.ShowTGWNotification(
            string.format('📉 Rank Down\n%s %s %s\nRating: %d',
                rank.icon, rank.name, rank.tier or '', updateData.newRating),
            'warning',
            4000
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

            if ShowRatingHUD and PlayerRatingData then
                DrawRatingHUD()
            end

            -- Draw rating change animations
            DrawRatingAnimations()

            -- Draw rank up animation
            if RankUpAnimation then
                DrawRankUpAnimation()
            end
        end
    end)
end

function DrawRatingHUD()
    if not RatingConfig.Display.showRatingChanges then
        return
    end

    local data = PlayerRatingData
    local rank = data.rank or {name = 'Unknown', tier = '', icon = '?', color = {255, 255, 255}}

    -- HUD position
    local hudX = 0.02
    local hudY = 0.92

    -- Background
    DrawRect(hudX + 0.08, hudY + 0.025, 0.16, 0.05, 0, 0, 0, 150)

    -- Rank icon and name
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.35, 0.35)
    SetTextColour(rank.color[1], rank.color[2], rank.color[3], 255)
    SetTextEntry('STRING')
    AddTextComponentString(string.format('%s %s %s', rank.icon, rank.name, rank.tier or ''))
    DrawText(hudX, hudY)

    -- Rating text
    SetTextScale(0.4, 0.4)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry('STRING')
    local ratingText = string.format('Rating: %d', data.rating)
    if data.provisional then
        ratingText = ratingText .. ' (Provisional)'
    end
    AddTextComponentString(ratingText)
    DrawText(hudX, hudY + 0.02)

    -- Rank progress bar
    if RatingConfig.Display.showRankProgress and data.nextRank then
        local progress = data.rankProgress or 0
        local barWidth = 0.15
        local barHeight = 0.006
        local barX = hudX + 0.005
        local barY = hudY + 0.04

        -- Progress bar background
        DrawRect(barX + (barWidth / 2), barY + (barHeight / 2), barWidth, barHeight, 50, 50, 50, 200)

        -- Progress bar fill
        local fillWidth = barWidth * progress
        if fillWidth > 0 then
            DrawRect(barX + (fillWidth / 2), barY + (barHeight / 2), fillWidth, barHeight,
                rank.color[1], rank.color[2], rank.color[3], 255)
        end
    end
end

function DrawRatingAnimations()
    if not RatingConfig.Display.animateRatingChanges then
        return
    end

    local currentTime = GetGameTimer()
    local animationDuration = 4000

    for i = #RatingChangeQueue, 1, -1 do
        local animation = RatingChangeQueue[i]
        local elapsed = currentTime - animation.timestamp

        if elapsed > animationDuration then
            table.remove(RatingChangeQueue, i)
        else
            -- Calculate animation position
            local progress = elapsed / animationDuration
            local alpha = math.floor((1 - progress) * 255)
            local yOffset = progress * 0.1

            -- Choose color based on change
            local r, g, b = 255, 255, 255
            if animation.change > 0 then
                r, g, b = 0, 255, 0  -- Green for positive
            elseif animation.change < 0 then
                r, g, b = 255, 0, 0  -- Red for negative
            end

            -- Draw floating rating change text
            SetTextFont(4)
            SetTextProportional(true)
            SetTextScale(0.5, 0.5)
            SetTextColour(r, g, b, alpha)
            SetTextCentre(true)
            SetTextEntry('STRING')
            AddTextComponentString(FormatRatingChange(animation.change))
            DrawText(0.85, 0.85 - yOffset)
        end
    end
end

function DrawRankUpAnimation()
    -- Animated rank up text
    local alpha = math.floor((math.sin(GetGameTimer() / 150) * 0.5 + 0.5) * 255)

    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(1.2, 1.2)
    SetTextColour(255, 215, 0, alpha)
    SetTextCentre(true)
    SetTextEntry('STRING')
    AddTextComponentString('🎉 RANK UP! 🎉')
    DrawText(0.5, 0.25)
end

-- =====================================================
-- MENU SYSTEMS
-- =====================================================

CurrentRatingMenu = nil

function OpenRatingMenu()
    local elements = {}

    if PlayerRatingData then
        local rank = PlayerRatingData.rank
        local nextRank = PlayerRatingData.nextRank

        table.insert(elements, {
            label = string.format('Rating: %d', PlayerRatingData.rating),
            description = string.format('Peak: %d | Games: %d%s',
                PlayerRatingData.peakRating,
                PlayerRatingData.gamesPlayed,
                PlayerRatingData.provisional and ' | Provisional' or '')
        })

        table.insert(elements, {
            label = string.format('Rank: %s %s %s', rank.icon, rank.name, rank.tier or ''),
            description = nextRank and string.format('Next: %s %s (%.1f%% progress)',
                nextRank.name, nextRank.tier or '', (PlayerRatingData.rankProgress or 0) * 100) or 'Maximum rank achieved'
        })

        if PlayerRatingData.seasonGames > 0 then
            table.insert(elements, {
                label = string.format('Season Rating: %d', PlayerRatingData.seasonRating),
                description = string.format('Season Games: %d', PlayerRatingData.seasonGames)
            })
        end

        table.insert(elements, {label = '─────────────────'})
    end

    table.insert(elements, {label = 'Rating History', value = 'history'})
    table.insert(elements, {label = 'Rating Leaderboard', value = 'leaderboard'})
    table.insert(elements, {label = 'Rank Information', value = 'rank_info'})
    table.insert(elements, {label = 'Rating System Help', value = 'help'})

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'tgw_rating_main', {
        title = 'TGW Rating System',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        if data.current.value == 'history' then
            menu.close()
            ShowRatingHistory()
        elseif data.current.value == 'leaderboard' then
            menu.close()
            ShowRatingLeaderboard()
        elseif data.current.value == 'rank_info' then
            menu.close()
            ShowRankInfo()
        elseif data.current.value == 'help' then
            menu.close()
            ShowRatingHelp()
        end
    end, function(data, menu)
        menu.close()
        CurrentRatingMenu = nil
    end)

    CurrentRatingMenu = 'main'
end

function ShowRatingHistory()
    if #RatingHistory == 0 then
        RequestRatingHistory(20)
        TGWCore.ShowTGWNotification('Loading rating history...', 'info', 2000)
        return
    end

    local elements = {}

    for _, entry in ipairs(RatingHistory) do
        local changeText = FormatRatingChange(entry.change)
        local reasonText = FormatRatingReason(entry.reason)
        local timeText = os.date('%m/%d %H:%M', entry.timestamp)

        table.insert(elements, {
            label = string.format('%s %s (%s)', timeText, changeText, reasonText),
            description = string.format('%d -> %d', entry.oldRating, entry.newRating)
        })
    end

    if #elements == 0 then
        table.insert(elements, {label = 'No rating history available', description = 'Play some matches to see your rating changes'})
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'tgw_rating_history', {
        title = 'Rating History',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        -- No action needed for history display
    end, function(data, menu)
        menu.close()
    end)
end

function ShowRatingLeaderboard()
    TGWCore.ShowTGWNotification('Rating leaderboard coming soon!', 'info', 3000)
end

function ShowRankInfo()
    if not PlayerRatingData then
        TGWCore.ShowTGWNotification('No rating data available', 'error', 2000)
        return
    end

    local elements = {}
    local currentRank = PlayerRatingData.rank

    -- Current rank info
    table.insert(elements, {
        label = string.format('Current Rank: %s %s %s', currentRank.icon, currentRank.name, currentRank.tier or ''),
        description = string.format('Rating: %d', PlayerRatingData.rating)
    })

    -- Next rank info
    if PlayerRatingData.nextRank then
        local nextRank = PlayerRatingData.nextRank
        local progress = PlayerRatingData.rankProgress or 0
        local ratingNeeded = math.ceil(nextRank.rating - PlayerRatingData.rating)

        table.insert(elements, {
            label = string.format('Next Rank: %s %s %s', nextRank.icon, nextRank.name, nextRank.tier or ''),
            description = string.format('Need %d more rating (%.1f%% progress)', ratingNeeded, progress * 100)
        })
    else
        table.insert(elements, {
            label = 'Maximum Rank Achieved!',
            description = 'You have reached the highest competitive rank'
        })
    end

    table.insert(elements, {label = '─────────────────'})

    -- Show rank system overview
    local currentIndex = 1
    for i, rank in ipairs(RatingConfig.CompetitiveRanks) do
        if rank.name == currentRank.name and rank.tier == currentRank.tier then
            currentIndex = i
            break
        end
    end

    -- Show 3 ranks before and after current rank
    local startIndex = math.max(1, currentIndex - 3)
    local endIndex = math.min(#RatingConfig.CompetitiveRanks, currentIndex + 3)

    for i = startIndex, endIndex do
        local rank = RatingConfig.CompetitiveRanks[i]
        local isCurrent = (i == currentIndex)
        local prefix = isCurrent and '>>> ' or '    '
        local suffix = isCurrent and ' <<<' or ''

        table.insert(elements, {
            label = string.format('%s%s %s %s%s', prefix, rank.icon, rank.name, rank.tier or '', suffix),
            description = string.format('Rating: %d+', rank.rating)
        })
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'tgw_rank_info', {
        title = 'Competitive Ranks',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        -- No action needed for rank info display
    end, function(data, menu)
        menu.close()
    end)
end

function RefreshRatingMenu()
    if CurrentRatingMenu == 'main' then
        ESX.UI.Menu.CloseAll()
        OpenRatingMenu()
    elseif CurrentRatingMenu == 'history' then
        ESX.UI.Menu.CloseAll()
        ShowRatingHistory()
    end
end

-- =====================================================
-- INFORMATION DISPLAYS
-- =====================================================

function ShowCurrentRating()
    if not PlayerRatingData then
        TGWCore.ShowTGWNotification('No rating data available', 'error', 2000)
        return
    end

    local data = PlayerRatingData
    local rank = data.rank

    local message = string.format(
        'Rating: %d%s\nRank: %s %s %s\nPeak: %d | Games: %d',
        data.rating,
        data.provisional and ' (Provisional)' or '',
        rank.icon, rank.name, rank.tier or '',
        data.peakRating, data.gamesPlayed
    )

    TGWCore.ShowTGWNotification(message, 'info', 5000)
end

function ShowRatingHelp()
    local helpText = [[
TGW Rating System Commands:

/rating - Open main rating menu
/rating history - View rating history
/rating leaderboard - View leaderboards
/rating rank - View rank information

/rank - Quick rank display
/elo - Show current rating
/rating_history - Quick history view

/toggle_rating_hud - Toggle HUD display

Rating System:
- New players start with provisional rating
- Rating changes based on wins/losses and opponent rating
- Ranks progress from Iron to Champion
- Seasonal rating resets occur periodically
]]

    TGWCore.ShowTGWNotification(helpText, 'info', 12000)
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function FormatRatingChange(change)
    if RatingConfig.Formatting.showSign then
        if change > 0 then
            return string.format('+%d', change)
        elseif change < 0 then
            return string.format('%d', change)
        else
            return '±0'
        end
    else
        return tostring(math.abs(change))
    end
end

function FormatRatingReason(reason)
    local reasonMap = {
        match_win = 'Match Win',
        match_loss = 'Match Loss',
        match_draw = 'Match Draw',
        decay = 'Inactivity Decay',
        recalibration = 'Season Reset',
        admin = 'Admin Adjustment'
    }

    return reasonMap[reason] or reason:gsub('_', ' '):gsub('^%l', string.upper)
end

function GetRatingColor(change)
    if RatingConfig.Formatting.colorCodeChanges then
        if change > 0 then
            return {0, 255, 0}  -- Green
        elseif change < 0 then
            return {255, 0, 0}  -- Red
        else
            return {255, 255, 255}  -- White
        end
    else
        return {255, 255, 255}
    end
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('GetPlayerRatingData', function()
    return PlayerRatingData
end)

exports('IsRankUpAnimationActive', function()
    return RankUpAnimation
end)

exports('GetRatingChangeQueue', function()
    return RatingChangeQueue
end)

exports('GetRatingHistory', function()
    return RatingHistory
end)

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        ESX.UI.Menu.CloseAll()
        CurrentRatingMenu = nil
    end
end)