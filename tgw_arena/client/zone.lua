-- =====================================================
-- TGW ARENA CLIENT - ZONE MONITORING AND CONTROLS
-- =====================================================
-- Purpose: Boundary checking, out-of-bounds warnings, client-side arena logic
-- Dependencies: tgw_core
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']

-- Client state
local CurrentArena = nil
local InArena = false
local ArenaCenter = nil
local ArenaRadius = 0
local BoundaryThread = nil
local ViolationWarning = {
    active = false,
    startTime = 0,
    duration = 0
}

-- Teleport state
local TeleportInProgress = false

-- =====================================================
-- INITIALIZATION
-- =====================================================

CreateThread(function()
    while not ESX do
        ESX = exports['tgw_core']:GetESX()
        Wait(100)
    end

    RegisterEventHandlers()

    print('^2[TGW-ARENA CLIENT]^7 Arena zone monitoring initialized')
end)

function RegisterEventHandlers()
    -- Handle arena teleport
    RegisterNetEvent(Config.Events.MatchTeleport, function(arenaId, spawnSide, teleportData)
        HandleArenaTeleport(arenaId, spawnSide, teleportData)
    end)

    -- Handle arena exit
    RegisterNetEvent('tgw:arena:exit', function()
        ExitArena()
    end)

    -- Handle round start (enable boundary checking)
    RegisterNetEvent('tgw:round:started', function(arenaId)
        if CurrentArena == arenaId then
            EnableBoundaryChecking()
        end
    end)

    -- Handle round end (disable boundary checking)
    RegisterNetEvent('tgw:round:ended', function(arenaId)
        if CurrentArena == arenaId then
            DisableBoundaryChecking()
        end
    end)
end

-- =====================================================
-- ARENA TELEPORTATION
-- =====================================================

function HandleArenaTeleport(arenaId, spawnSide, teleportData)
    if TeleportInProgress then return end

    TeleportInProgress = true
    CurrentArena = arenaId
    InArena = true

    print(string.format('^2[TGW-ARENA CLIENT]^7 Teleporting to arena %d (side %s)', arenaId, spawnSide))

    -- Disable controls during teleport
    DisablePlayerControls(true)

    -- Fade out screen
    DoScreenFadeOut(500)
    Wait(500)

    -- Teleport player
    local playerPed = PlayerPedId()
    SetEntityCoords(playerPed, teleportData.position.x, teleportData.position.y, teleportData.position.z, false, false, false, true)
    SetEntityHeading(playerPed, teleportData.heading)

    -- Wait for world to load
    Wait(1000)

    -- Set arena parameters for boundary checking
    SetArenaParameters(arenaId)

    -- Fade in screen
    DoScreenFadeIn(500)
    Wait(500)

    -- Re-enable controls
    DisablePlayerControls(false)

    TeleportInProgress = false

    -- Notify successful teleport
    TGWCore.ShowTGWNotification(string.format('Memasuki Arena %d', arenaId), 'info')

    -- Enable spawn protection
    EnableSpawnProtection()
end

function SetArenaParameters(arenaId)
    -- Get arena data from template (since all arenas use same coordinates)
    local template = ArenaConfig.Template
    ArenaCenter = template.center
    ArenaRadius = template.radius

    print(string.format('^5[TGW-ARENA CLIENT]^7 Arena %d parameters set - Center: %.1f,%.1f,%.1f Radius: %.1f',
        arenaId, ArenaCenter.x, ArenaCenter.y, ArenaCenter.z, ArenaRadius))
end

function EnableSpawnProtection()
    local playerPed = PlayerPedId()

    CreateThread(function()
        local protectionTime = ArenaConfig.SpawnProtection * 1000
        local startTime = GetGameTimer()

        while GetGameTimer() - startTime < protectionTime do
            Wait(0)

            -- Make player temporarily invincible
            SetPlayerInvincible(PlayerId(), true)
            SetEntityCanBeDamaged(playerPed, false)

            -- Show protection indicator
            if GetGameTimer() % 1000 < 500 then  -- Blink every 500ms
                DrawProtectionIndicator()
            end
        end

        -- Remove protection
        SetPlayerInvincible(PlayerId(), false)
        SetEntityCanBeDamaged(playerPed, true)

        print('^2[TGW-ARENA CLIENT]^7 Spawn protection ended')
    end)
end

function DrawProtectionIndicator()
    -- Draw simple protection indicator
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.5, 0.5)
    SetTextColour(0, 255, 0, 255)
    SetTextEntry("STRING")
    AddTextComponentString("SPAWN PROTECTION")
    DrawText(0.5, 0.1)
end

-- =====================================================
-- BOUNDARY CHECKING SYSTEM
-- =====================================================

function EnableBoundaryChecking()
    if BoundaryThread then return end

    print('^2[TGW-ARENA CLIENT]^7 Enabling boundary checking')

    BoundaryThread = CreateThread(function()
        while InArena and CurrentArena do
            Wait(500)  -- Check every 500ms

            if not TeleportInProgress then
                CheckBoundaryViolation()
            end
        end
    end)
end

function DisableBoundaryChecking()
    if BoundaryThread then
        BoundaryThread = nil
        print('^3[TGW-ARENA CLIENT]^7 Disabling boundary checking')
    end

    -- Clear any active warnings
    if ViolationWarning.active then
        ViolationWarning.active = false
    end
end

function CheckBoundaryViolation()
    if not ArenaCenter or not ArenaRadius then return end

    local playerPed = PlayerPedId()
    local playerPos = GetEntityCoords(playerPed)
    local distance = #(playerPos - ArenaCenter)

    if distance > ArenaRadius then
        -- Player is out of bounds
        if not ViolationWarning.active then
            StartBoundaryWarning()
        end
    else
        -- Player is in bounds
        if ViolationWarning.active then
            StopBoundaryWarning()
        end
    end
end

function StartBoundaryWarning()
    ViolationWarning.active = true
    ViolationWarning.startTime = GetGameTimer()
    ViolationWarning.duration = ArenaConfig.OutOfBoundsWarnSec * 1000

    print('^3[TGW-ARENA CLIENT]^7 Out of bounds warning started')

    -- Show warning to player
    TGWCore.ShowTGWNotification('Kembali ke area arena!', 'warning')

    -- Start warning thread
    CreateThread(function()
        local warningEnd = ViolationWarning.startTime + ViolationWarning.duration

        while ViolationWarning.active and GetGameTimer() < warningEnd do
            Wait(0)

            -- Draw warning HUD
            DrawBoundaryWarning()

            -- Check if still out of bounds
            if not IsPlayerOutOfBounds() then
                StopBoundaryWarning()
                break
            end
        end

        -- If warning expires while still out of bounds
        if ViolationWarning.active and GetGameTimer() >= warningEnd then
            ReportBoundaryViolation()
        end
    end)
end

function StopBoundaryWarning()
    if not ViolationWarning.active then return end

    ViolationWarning.active = false
    print('^2[TGW-ARENA CLIENT]^7 Out of bounds warning stopped - player returned to arena')
end

function DrawBoundaryWarning()
    local timeLeft = math.max(0, (ViolationWarning.startTime + ViolationWarning.duration - GetGameTimer()) / 1000)

    -- Draw warning box
    local boxWidth = 0.3
    local boxHeight = 0.08
    local boxX = 0.5 - (boxWidth / 2)
    local boxY = 0.1

    -- Background
    DrawRect(boxX + (boxWidth / 2), boxY + (boxHeight / 2), boxWidth, boxHeight, 255, 0, 0, 150)

    -- Warning text
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.6, 0.6)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString(string.format("KELUAR ZONA ARENA!\nKembali dalam %.1f detik", timeLeft))
    DrawText(0.5, boxY + 0.02)

    -- Warning border
    DrawRect(boxX + (boxWidth / 2), boxY + (boxHeight / 2), boxWidth + 0.002, boxHeight + 0.002, 255, 255, 255, 255)
end

function IsPlayerOutOfBounds()
    if not ArenaCenter or not ArenaRadius then return false end

    local playerPed = PlayerPedId()
    local playerPos = GetEntityCoords(playerPed)
    local distance = #(playerPos - ArenaCenter)

    return distance > ArenaRadius
end

function ReportBoundaryViolation()
    print('^1[TGW-ARENA CLIENT]^7 Boundary violation - reporting to server')

    -- Report violation to server
    TriggerServerEvent('tgw:arena:reportViolation', 'out_of_bounds')

    -- Stop warning
    ViolationWarning.active = false

    -- Show forfeit notification
    TGWCore.ShowTGWNotification('Forfeit - Keluar dari zona arena', 'error')
end

-- =====================================================
-- ARENA EXIT
-- =====================================================

function ExitArena()
    print('^3[TGW-ARENA CLIENT]^7 Exiting arena')

    InArena = false
    CurrentArena = nil
    ArenaCenter = nil
    ArenaRadius = 0

    -- Disable boundary checking
    DisableBoundaryChecking()

    -- Clear any active warnings
    ViolationWarning.active = false

    -- Teleport to lobby (this would be handled by core system)
    -- The actual teleport will be handled by tgw_core when bucket changes
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function DisablePlayerControls(disable)
    local playerId = PlayerId()

    CreateThread(function()
        while disable and TeleportInProgress do
            Wait(0)

            -- Disable movement and actions during teleport
            DisableControlAction(0, 30, true)   -- Move Left/Right
            DisableControlAction(0, 31, true)   -- Move Forward/Back
            DisableControlAction(0, 21, true)   -- Sprint
            DisableControlAction(0, 22, true)   -- Jump
            DisableControlAction(0, 23, true)   -- Enter Vehicle
            DisableControlAction(0, 24, true)   -- Attack
            DisableControlAction(0, 25, true)   -- Aim
            DisableControlAction(0, 44, true)   -- Cover
            DisableControlAction(0, 37, true)   -- Select Weapon
        end
    end)
end

function GetCurrentArena()
    return CurrentArena
end

function IsInArena()
    return InArena
end

function GetArenaDistance()
    if not ArenaCenter then return -1 end

    local playerPos = GetEntityCoords(PlayerPedId())
    return #(playerPos - ArenaCenter)
end

function IsOutOfBounds()
    if not ArenaCenter or not ArenaRadius then return false end
    return GetArenaDistance() > ArenaRadius
end

-- =====================================================
-- DEBUG FUNCTIONS
-- =====================================================

function DrawArenaDebugMarkers()
    if not ArenaConfig.EnableDebugMarkers or not ArenaCenter then return end

    CreateThread(function()
        while InArena and CurrentArena do
            Wait(0)

            -- Draw arena center
            DrawMarker(1, ArenaCenter.x, ArenaCenter.y, ArenaCenter.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 1.0, 0, 255, 0, 100, false, true, 2, false, nil, nil, false)

            -- Draw arena boundary (simplified)
            local playerPos = GetEntityCoords(PlayerPedId())
            local distance = #(playerPos - ArenaCenter)
            local color = distance > ArenaRadius and {255, 0, 0} or {0, 255, 0}

            -- Draw boundary circle (approximated with markers)
            for i = 0, 360, 30 do
                local angle = math.rad(i)
                local x = ArenaCenter.x + (ArenaRadius * math.cos(angle))
                local y = ArenaCenter.y + (ArenaRadius * math.sin(angle))
                DrawMarker(1, x, y, ArenaCenter.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, color[1], color[2], color[3], 100, false, true, 2, false, nil, nil, false)
            end
        end
    end)
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('GetCurrentArena', GetCurrentArena)
exports('IsInArena', IsInArena)
exports('GetArenaDistance', GetArenaDistance)
exports('IsOutOfBounds', IsOutOfBounds)

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        DisableBoundaryChecking()
        InArena = false
        CurrentArena = nil
    end
end)