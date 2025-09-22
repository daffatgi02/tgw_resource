-- =====================================================
-- TGW QUEUE CLIENT - UI AND INTERACTION
-- =====================================================
-- Purpose: Queue UI, spectate controls, status display
-- Dependencies: tgw_core, esx_menu_default
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']
local QueueUI = {}

-- State management
local CurrentQueueState = nil
local QueueMenuOpen = false
local SpectateHUD = {
    visible = false,
    targetName = '',
    arenaName = '',
    matchTime = 0
}

-- =====================================================
-- INITIALIZATION
-- =====================================================

CreateThread(function()
    while not ESX do
        ESX = exports['tgw_core']:GetESX()
        Wait(100)
    end

    InitializeQueueUI()
    StartQueueHUD()

    print('^2[TGW-QUEUE CLIENT]^7 Queue UI initialized')
end)

function InitializeQueueUI()
    -- Register menu close handler
    RegisterNetEvent('esx_menu_default:hasExited', function()
        QueueMenuOpen = false
    end)

    -- Register queue status updates
    RegisterNetEvent(Config.Events.QueueStatusUpdate, function(state, data)
        CurrentQueueState = state
        UpdateQueueHUD(state, data)
    end)
end

-- =====================================================
-- QUEUE MENU SYSTEM
-- =====================================================

function OpenQueueMenu()
    if QueueMenuOpen then return end

    ESX.TriggerServerCallback(Config.Events.GetPlayerData, function(playerData)
        if not playerData then
            TGWCore.ShowTGWNotification('Failed to load player data', 'error')
            return
        end

        ESX.TriggerServerCallback(Config.Events.GetPreferences, function(preferences)
            ShowMainQueueMenu(playerData, preferences)
        end)
    end)
end

function ShowMainQueueMenu(playerData, preferences)
    QueueMenuOpen = true

    local elements = {}

    -- Add menu options based on current state
    if not CurrentQueueState then
        -- Not in queue - can join
        table.insert(elements, {
            label = Config.GetLocale('join_queue') or 'Join Queue',
            value = 'join_queue'
        })
    else
        -- In queue - show status and leave option
        table.insert(elements, {
            label = string.format('Queue Status: %s', CurrentQueueState),
            value = 'queue_status'
        })

        table.insert(elements, {
            label = Config.GetLocale('leave_queue') or 'Leave Queue',
            value = 'leave_queue'
        })

        if CurrentQueueState == 'spectate' then
            table.insert(elements, {
                label = 'Switch Spectate Target',
                value = 'switch_spectate'
            })
        end
    end

    -- Always show preferences
    table.insert(elements, {
        label = 'Preferences',
        value = 'preferences'
    })

    -- Show statistics
    table.insert(elements, {
        label = 'Statistics',
        value = 'statistics'
    })

    -- Show leaderboard
    table.insert(elements, {
        label = 'Leaderboard',
        value = 'leaderboard'
    })

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'tgw_queue_menu', {
        title = 'TGW Queue System',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        HandleMenuSelection(data.current.value, menu, playerData, preferences)
    end, function(data, menu)
        menu.close()
        QueueMenuOpen = false
    end)
end

function HandleMenuSelection(value, menu, playerData, preferences)
    if value == 'join_queue' then
        menu.close()
        QueueMenuOpen = false
        ShowJoinQueueMenu(preferences)
    elseif value == 'leave_queue' then
        menu.close()
        QueueMenuOpen = false
        TriggerServerEvent(Config.Events.QueueLeave)
    elseif value == 'switch_spectate' then
        ShowSpectateMenu(menu)
    elseif value == 'preferences' then
        ShowPreferencesMenu(menu, preferences)
    elseif value == 'statistics' then
        ShowStatisticsMenu(menu, playerData)
    elseif value == 'leaderboard' then
        ShowLeaderboardMenu(menu)
    elseif value == 'queue_status' then
        ShowQueueStatusMenu(menu)
    end
end

function ShowJoinQueueMenu(preferences)
    local elements = {}

    -- Add round type options
    for _, roundType in ipairs(Config.RoundTypes) do
        if preferences then
            -- Check if player allows this round type
            local allowed = true
            if roundType == 'pistol' and preferences.allow_pistol == 0 then
                allowed = false
            elseif roundType == 'sniper' and preferences.allow_sniper == 0 then
                allowed = false
            end

            if allowed then
                local isPreferred = preferences.preferred_round == roundType
                table.insert(elements, {
                    label = string.format('%s%s',
                        roundType:gsub("^%l", string.upper),
                        isPreferred and ' (Preferred)' or ''
                    ),
                    value = roundType
                })
            end
        else
            table.insert(elements, {
                label = roundType:gsub("^%l", string.upper),
                value = roundType
            })
        end
    end

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'join_queue_menu', {
        title = 'Select Round Type',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        menu.close()
        TriggerServerEvent(Config.Events.QueueJoin, data.current.value)
    end, function(data, menu)
        menu.close()
        OpenQueueMenu()
    end)
end

function ShowSpectateMenu(parentMenu)
    local elements = {
        { label = 'Next Target', value = 'next' },
        { label = 'Previous Target', value = 'prev' },
        { label = 'Stop Spectating', value = 'stop' },
        { label = 'Back', value = 'back' }
    }

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'spectate_menu', {
        title = 'Spectate Controls',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        if data.current.value == 'next' then
            TriggerServerEvent(Config.Events.SpectateNext)
            menu.close()
        elseif data.current.value == 'prev' then
            TriggerServerEvent(Config.Events.SpectatePrev)
            menu.close()
        elseif data.current.value == 'stop' then
            TriggerServerEvent(Config.Events.QueueLeave)
            menu.close()
        elseif data.current.value == 'back' then
            menu.close()
            ShowMainQueueMenu()
        end
    end, function(data, menu)
        menu.close()
        parentMenu.close()
        QueueMenuOpen = false
    end)
end

function ShowQueueStatusMenu(parentMenu)
    ESX.TriggerServerCallback(Config.Events.GetQueueStatus, function(queueData)
        local elements = {}

        if queueData and #queueData > 0 then
            table.insert(elements, {
                label = string.format('Queue Size: %d players', #queueData)
            })

            -- Find player position
            local playerIdentifier = ESX.GetPlayerData().identifier
            for i, entry in ipairs(queueData) do
                if entry.identifier == playerIdentifier then
                    table.insert(elements, {
                        label = string.format('Your Position: %d', i)
                    })
                    table.insert(elements, {
                        label = string.format('Wait Time: %ds', entry.wait_time_seconds or 0)
                    })
                    break
                end
            end
        else
            table.insert(elements, {
                label = 'Queue is empty'
            })
        end

        table.insert(elements, { label = 'Back', value = 'back' })

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'queue_status_menu', {
            title = 'Queue Status',
            align = 'top-left',
            elements = elements
        }, function(data, menu)
            if data.current.value == 'back' then
                menu.close()
                ShowMainQueueMenu()
            end
        end, function(data, menu)
            menu.close()
            parentMenu.close()
            QueueMenuOpen = false
        end)
    end)
end

function ShowStatisticsMenu(parentMenu, playerData)
    local elements = {
        { label = string.format('Rating: %d', playerData.rating or 0) },
        { label = string.format('Ladder Level: %d', playerData.ladder_level or 0) },
        { label = string.format('Wins: %d', playerData.wins or 0) },
        { label = string.format('Losses: %d', playerData.losses or 0) },
        { label = string.format('Win Rate: %.1f%%', playerData.win_rate or 0) },
        { label = 'Back', value = 'back' }
    }

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'statistics_menu', {
        title = 'Your Statistics',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        if data.current.value == 'back' then
            menu.close()
            ShowMainQueueMenu()
        end
    end, function(data, menu)
        menu.close()
        parentMenu.close()
        QueueMenuOpen = false
    end)
end

function ShowLeaderboardMenu(parentMenu)
    ESX.TriggerServerCallback(Config.Events.GetLeaderboard, function(leaderboard)
        local elements = {}

        if leaderboard and #leaderboard > 0 then
            for i, player in ipairs(leaderboard) do
                table.insert(elements, {
                    label = string.format('#%d - %s (%d rating)',
                        i,
                        player.firstname or 'Unknown',
                        player.rating or 0
                    )
                })
            end
        else
            table.insert(elements, {
                label = 'No data available'
            })
        end

        table.insert(elements, { label = 'Back', value = 'back' })

        ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'leaderboard_menu', {
            title = 'Top Players',
            align = 'top-left',
            elements = elements
        }, function(data, menu)
            if data.current.value == 'back' then
                menu.close()
                ShowMainQueueMenu()
            end
        end, function(data, menu)
            menu.close()
            parentMenu.close()
            QueueMenuOpen = false
        end)
    end, 10)
end

-- =====================================================
-- SPECTATE HUD
-- =====================================================

function StartQueueHUD()
    CreateThread(function()
        while true do
            Wait(0)

            if SpectateHUD.visible then
                DrawSpectateHUD()
            end

            -- Handle spectate controls
            if CurrentQueueState == 'spectate' then
                HandleSpectateControls()
            end
        end
    end)
end

function DrawSpectateHUD()
    -- Draw spectate info
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.5, 0.5)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry("STRING")
    AddTextComponentString(string.format('Spectating: %s', SpectateHUD.targetName))
    DrawText(0.02, 0.02)

    -- Draw arena info
    SetTextEntry("STRING")
    AddTextComponentString(string.format('Arena: %s', SpectateHUD.arenaName))
    DrawText(0.02, 0.05)

    -- Draw controls hint
    SetTextScale(0.4, 0.4)
    SetTextColour(200, 200, 200, 255)
    SetTextEntry("STRING")
    AddTextComponentString('LEFT/RIGHT: Switch Target | BACK: Leave')
    DrawText(0.02, 0.08)
end

function UpdateQueueHUD(state, data)
    if state == 'spectate' then
        SpectateHUD.visible = true
        SpectateHUD.targetName = data.targetName or 'Unknown'
        SpectateHUD.arenaName = data.arenaName or 'Unknown Arena'
        SpectateHUD.matchTime = data.matchTime or 0
    else
        SpectateHUD.visible = false
    end
end

function HandleSpectateControls()
    -- Disable certain controls while spectating
    DisableControlAction(0, 24, true)  -- Attack
    DisableControlAction(0, 25, true)  -- Aim
    DisableControlAction(0, 37, true)  -- Select weapon
    DisableControlAction(0, 44, true)  -- Cover
    DisableControlAction(0, 45, true)  -- Reload
end

-- =====================================================
-- EVENT HANDLERS
-- =====================================================

RegisterNetEvent(Config.Events.SpectateStart, function(targetId, arenaData)
    SpectateHUD.visible = true
    SpectateHUD.targetName = GetPlayerName(targetId) or 'Unknown'
    SpectateHUD.arenaName = arenaData.name or 'Unknown Arena'

    TGWCore.ShowTGWNotification('Started spectating', 'info')
end)

RegisterNetEvent(Config.Events.SpectateStop, function()
    SpectateHUD.visible = false

    TGWCore.ShowTGWNotification('Stopped spectating', 'info')
end)

RegisterNetEvent('tgw:ui:openMenu', function()
    OpenQueueMenu()
end)

-- =====================================================
-- EXPORTS
-- =====================================================

exports('OpenQueueMenu', OpenQueueMenu)
exports('IsQueueMenuOpen', function()
    return QueueMenuOpen
end)
exports('GetSpectateHUD', function()
    return SpectateHUD
end)

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Close any open menus
        ESX.UI.Menu.CloseAll()
        QueueMenuOpen = false
        SpectateHUD.visible = false
    end
end)