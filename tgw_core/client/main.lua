-- =====================================================
-- TGW CORE CLIENT - MAIN ENTRY POINT
-- =====================================================
-- Purpose: Client-side ESX integration, notification wrapper, utilities
-- Dependencies: es_extended
-- =====================================================

local ESX = nil
local PlayerData = {}
local TGWActive = false
local CurrentState = 'lobby'
local HeartbeatThread = nil

-- =====================================================
-- INITIALIZATION
-- =====================================================

-- Initialize ESX
CreateThread(function()
    while ESX == nil do
        ESX = exports['es_extended']:getSharedObject()
        Wait(100)
    end

    -- Register ESX events
    RegisterESXEvents()

    -- Start systems
    StartHeartbeat()
    StartStateManager()

    print('^2[TGW-CORE CLIENT]^7 Initialized successfully')
end)

-- Register ESX event handlers
function RegisterESXEvents()
    RegisterNetEvent('esx:playerLoaded', function(xPlayer)
        PlayerData = xPlayer
        TriggerServerEvent('tgw:player:clientReady')
    end)

    RegisterNetEvent('esx:setJob', function(job)
        PlayerData.job = job
    end)
end

-- =====================================================
-- HEARTBEAT SYSTEM
-- =====================================================

function StartHeartbeat()
    if HeartbeatThread then return end

    HeartbeatThread = CreateThread(function()
        while true do
            Wait(Config.HeartbeatInterval)

            -- Send heartbeat to server
            TriggerServerEvent(Config.Events.PlayerHeartbeat)
        end
    end)
end

function StopHeartbeat()
    if HeartbeatThread then
        HeartbeatThread = nil
    end
end

-- =====================================================
-- STATE MANAGEMENT
-- =====================================================

function StartStateManager()
    CreateThread(function()
        while true do
            Wait(Config.TickRate)

            -- Handle state-specific logic
            HandleCurrentState()
        end
    end)
end

function HandleCurrentState()
    if CurrentState == 'lobby' then
        -- Lobby state logic
        HandleLobbyState()
    elseif CurrentState == 'queue' then
        -- Queue state logic
        HandleQueueState()
    elseif CurrentState == 'spectate' then
        -- Spectate state logic
        HandleSpectateState()
    elseif CurrentState == 'arena' then
        -- Arena state logic
        HandleArenaState()
    end
end

function HandleLobbyState()
    -- Basic lobby state handling
    if TGWActive then
        SetTGWActive(false)
    end
end

function HandleQueueState()
    -- Queue state handling
    if not TGWActive then
        SetTGWActive(true)
    end
end

function HandleSpectateState()
    -- Spectate state handling
    if not TGWActive then
        SetTGWActive(true)
    end

    -- Disable player collision and input
    SetLocalPlayerAsGhost(true)
end

function HandleArenaState()
    -- Arena state handling
    if not TGWActive then
        SetTGWActive(true)
    end

    -- Enable player collision
    SetLocalPlayerAsGhost(false)
end

-- =====================================================
-- TGW STATE CONTROL
-- =====================================================

function SetTGWActive(active)
    TGWActive = active

    if active then
        -- Disable global chat (if configured)
        if Config.RestrictGlobalInMode then
            -- Implementation depends on chat system
        end

        -- Enable TGW-specific controls
        EnableTGWControls(true)
    else
        -- Re-enable global chat
        -- Implementation depends on chat system

        -- Disable TGW-specific controls
        EnableTGWControls(false)

        -- Reset player state
        SetLocalPlayerAsGhost(false)
        CurrentState = 'lobby'
    end
end

function EnableTGWControls(enable)
    -- This will be expanded when UI resource is implemented
    if enable then
        -- Enable TGW keybinds
        RegisterTGWKeybinds()
    else
        -- Disable TGW keybinds
        UnregisterTGWKeybinds()
    end
end

function RegisterTGWKeybinds()
    -- Register keybinds for TGW system
    RegisterKeyMapping('tgw_menu', 'Open TGW Menu', 'keyboard', Config.Keybinds.OpenMenu)
    RegisterKeyMapping('tgw_spectate_next', 'Spectate Next', 'keyboard', Config.Keybinds.SpectateNext)
    RegisterKeyMapping('tgw_spectate_prev', 'Spectate Previous', 'keyboard', Config.Keybinds.SpectatePrev)
    RegisterKeyMapping('tgw_leave', 'Leave TGW', 'keyboard', Config.Keybinds.LeaveQueue)
end

function UnregisterTGWKeybinds()
    -- Keybind cleanup would go here
    -- FiveM doesn't provide direct unregistration, so we handle this via state
end

-- =====================================================
-- NOTIFICATION SYSTEM
-- =====================================================

RegisterNetEvent(Config.Events.NotificationSend, function(message, type, duration)
    ShowTGWNotification(message, type, duration)
end)

function ShowTGWNotification(message, type, duration)
    type = type or 'info'
    duration = duration or 5000

    -- Use ESX notification system
    if ESX and ESX.ShowNotification then
        ESX.ShowNotification(message, type, duration)
    else
        -- Fallback to basic notification
        BeginTextCommandThefeedPost("STRING")
        AddTextComponentSubstringPlayerName(message)
        EndTextCommandThefeedPostTicker(false, true)
    end
end

-- =====================================================
-- PLAYER STATE EVENTS
-- =====================================================

RegisterNetEvent(Config.Events.PlayerJoinedTGW, function(state, data)
    CurrentState = state or 'queue'
    SetTGWActive(true)

    ShowTGWNotification(Config.GetLocale('joining_queue'), 'info')
end)

RegisterNetEvent(Config.Events.PlayerLeftTGW, function()
    CurrentState = 'lobby'
    SetTGWActive(false)

    ShowTGWNotification(Config.GetLocale('queue_left'), 'info')
end)

RegisterNetEvent(Config.Events.QueueStatusUpdate, function(status, data)
    CurrentState = status

    if status == 'spectate' then
        -- Handle spectate mode
        HandleSpectateStart(data)
    elseif status == 'paired' then
        -- Handle match pairing
        ShowTGWNotification(Config.GetLocale('match_found'), 'success')
    end
end)

-- =====================================================
-- SPECTATE SYSTEM
-- =====================================================

RegisterNetEvent(Config.Events.SpectateStart, function(targetId, arenaData)
    CurrentState = 'spectate'

    -- Set camera to spectate target
    SetSpectateTarget(targetId)

    ShowTGWNotification(Config.GetLocale('spectate_mode'), 'info')
end)

RegisterNetEvent(Config.Events.SpectateStop, function()
    -- Stop spectating
    StopSpectating()

    if TGWActive then
        CurrentState = 'queue'
    else
        CurrentState = 'lobby'
    end
end)

function SetSpectateTarget(targetId)
    if not targetId or targetId == 0 then return end

    -- Disable player controls
    SetLocalPlayerAsGhost(true)

    -- Set camera to follow target
    local targetPed = GetPlayerPed(GetPlayerFromServerId(targetId))
    if DoesEntityExist(targetPed) then
        SetFollowPedCamViewMode(0)
        NetworkSetInSpectatorMode(true, targetPed)
    end
end

function StopSpectating()
    -- Re-enable player controls
    SetLocalPlayerAsGhost(false)

    -- Reset camera
    NetworkSetInSpectatorMode(false, PlayerPedId())
    ClearFollowPedCamViewMode()
end

function SetLocalPlayerAsGhost(enable)
    local playerPed = PlayerPedId()

    if enable then
        -- Make player invisible and non-collidable
        SetEntityAlpha(playerPed, 0, false)
        SetEntityCollision(playerPed, false, false)
        SetEntityCanBeDamaged(playerPed, false)
        SetPlayerInvincible(PlayerId(), true)

        -- Disable most controls
        DisableControlAction(0, 24, true) -- Attack
        DisableControlAction(0, 25, true) -- Aim
        DisableControlAction(0, 37, true) -- Select weapon
        DisableControlAction(0, 141, true) -- Melee light
        DisableControlAction(0, 142, true) -- Melee heavy
        DisableControlAction(0, 143, true) -- Melee alternate
    else
        -- Restore player visibility and collision
        SetEntityAlpha(playerPed, 255, false)
        SetEntityCollision(playerPed, true, true)
        SetEntityCanBeDamaged(playerPed, true)
        SetPlayerInvincible(PlayerId(), false)
    end
end

-- =====================================================
-- KEYBIND HANDLERS
-- =====================================================

RegisterCommand('tgw_menu', function()
    if not TGWActive then return end

    -- Trigger menu open event
    TriggerEvent('tgw:ui:openMenu')
end, false)

RegisterCommand('tgw_spectate_next', function()
    if CurrentState ~= 'spectate' then return end

    TriggerServerEvent(Config.Events.SpectateNext)
end, false)

RegisterCommand('tgw_spectate_prev', function()
    if CurrentState ~= 'spectate' then return end

    TriggerServerEvent(Config.Events.SpectatePrev)
end, false)

RegisterCommand('tgw_leave', function()
    if not TGWActive then return end

    TriggerServerEvent(Config.Events.QueueLeave)
end, false)

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function GetPlayerData()
    return PlayerData
end

function IsInTGW()
    return TGWActive
end

function GetCurrentState()
    return CurrentState
end

function GetTGWConfig()
    return Config
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('GetESX', function()
    return ESX
end)

exports('GetPlayerData', function()
    return GetPlayerData()
end)

exports('IsInTGW', function()
    return IsInTGW()
end)

exports('GetCurrentState', function()
    return GetCurrentState()
end)

exports('ShowTGWNotification', function(message, type, duration)
    ShowTGWNotification(message, type, duration)
end)

exports('SetTGWActive', function(active)
    SetTGWActive(active)
end)

exports('GetTGWConfig', function()
    return GetTGWConfig()
end)

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        StopHeartbeat()
        SetTGWActive(false)
        StopSpectating()
    end
end)