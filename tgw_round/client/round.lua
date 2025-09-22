-- =====================================================
-- TGW ROUND CLIENT - ROUND UI AND CONTROLS
-- =====================================================
-- Purpose: Countdown display, HUD, freeze controls, sudden death UI
-- Dependencies: tgw_core
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']

-- Round state
local CurrentMatch = nil
local RoundState = nil
local RoundStarted = false
local InFreeze = false
local InSuddenDeath = false

-- Timer and countdown
local RoundTimer = 0
local SuddenDeathTimer = 0
local CountdownActive = false
local CountdownTime = 0

-- HUD state
local ShowRoundHUD = false
local OpponentName = ''
local RoundType = ''

-- Sudden death
local ArenaRadius = 30.0
local OriginalRadius = 30.0

-- Activity tracking
local LastActivityTime = 0
local ActivityCheckInterval = 5000

-- =====================================================
-- INITIALIZATION
-- =====================================================

CreateThread(function()
    while not ESX do
        ESX = exports['tgw_core']:GetESX()
        Wait(100)
    end

    RegisterEventHandlers()
    StartActivityTracker()
    StartRoundHUD()

    print('^2[TGW-ROUND CLIENT]^7 Round client system initialized')
end)

function RegisterEventHandlers()
    -- Freeze phase events
    RegisterNetEvent('tgw:round:freezeStart', function(freezeTime, opponentIdentifier)
        StartFreezePhase(freezeTime, opponentIdentifier)
    end)

    -- Round start event
    RegisterNetEvent('tgw:round:started', function(matchId, roundTime)
        StartRound(matchId, roundTime)
    end)

    -- Timer updates
    RegisterNetEvent('tgw:round:timer', function(remainingTime)
        UpdateRoundTimer(remainingTime)
    end)

    -- Sudden death events
    RegisterNetEvent('tgw:round:suddenDeath', function(suddenDeathTime)
        StartSuddenDeath(suddenDeathTime)
    end)

    RegisterNetEvent('tgw:round:suddenDeathTimer', function(remainingTime)
        UpdateSuddenDeathTimer(remainingTime)
    end)

    RegisterNetEvent('tgw:round:radiusUpdate', function(newRadius)
        UpdateArenaRadius(newRadius)
    end)

    -- Round end event
    RegisterNetEvent('tgw:round:result', function(resultData)
        ShowRoundResult(resultData)
    end)

    -- Out of bounds check
    RegisterNetEvent('tgw:round:checkOutOfBounds', function(currentRadius, damagePerSec)
        CheckOutOfBounds(currentRadius, damagePerSec)
    end)

    -- Activity update
    RegisterNetEvent('tgw:round:updateActivity', function()
        UpdateActivity()
    end)
end

-- =====================================================
-- FREEZE PHASE
-- =====================================================

function StartFreezePhase(freezeTime, opponentIdentifier)
    InFreeze = true
    CountdownActive = true
    CountdownTime = freezeTime

    -- Get opponent name
    local opponentName = GetPlayerNameByIdentifier(opponentIdentifier)
    OpponentName = opponentName or 'Unknown'

    print(string.format('^2[TGW-ROUND CLIENT]^7 Freeze phase started - %d seconds', freezeTime))

    -- Disable controls
    EnableFreezeControls(true)

    -- Start countdown display
    StartCountdownDisplay(freezeTime)

    -- Play countdown audio
    PlayCountdownAudio()
end

function StartCountdownDisplay(freezeTime)
    CreateThread(function()
        local remainingTime = freezeTime

        while remainingTime > 0 and CountdownActive do
            Wait(1000)
            remainingTime = remainingTime - 1

            -- Update countdown display
            if remainingTime > 0 then
                ShowCountdownNumber(remainingTime)
            else
                ShowCountdownGO()
                Wait(1000)
                CountdownActive = false
                InFreeze = false
                EnableFreezeControls(false)
            end
        end
    end)
end

function ShowCountdownNumber(number)
    -- This will be enhanced with proper HUD rendering
    TGWCore.ShowTGWNotification(tostring(number), 'info', 1000)
end

function ShowCountdownGO()
    TGWCore.ShowTGWNotification('GO!', 'success', 1000)
end

function PlayCountdownAudio()
    -- Placeholder for audio implementation
    -- This would play countdown sounds (bip bip bip GO)
    CreateThread(function()
        for i = 3, 1, -1 do
            -- Play countdown beep
            PlaySoundFrontend(-1, "TIMER_STOP", "HUD_MINI_GAME_SOUNDSET", 1)
            Wait(1000)
        end
        -- Play GO sound
        PlaySoundFrontend(-1, "RACE_PLACED", "HUD_AWARDS", 1)
    end)
end

function EnableFreezeControls(enable)
    if not enable then return end

    CreateThread(function()
        while InFreeze do
            Wait(0)

            -- Disable movement and actions during freeze
            if RoundConfig.FreezeControls.movement then
                DisableControlAction(0, 30, true)   -- Move Left/Right
                DisableControlAction(0, 31, true)   -- Move Forward/Back
                DisableControlAction(0, 21, true)   -- Sprint
                DisableControlAction(0, 22, true)   -- Jump
            end

            if RoundConfig.FreezeControls.weapons then
                DisableControlAction(0, 24, true)   -- Attack
                DisableControlAction(0, 25, true)   -- Aim
                DisableControlAction(0, 37, true)   -- Select Weapon
                DisableControlAction(0, 44, true)   -- Cover
                DisableControlAction(0, 45, true)   -- Reload
            end

            if RoundConfig.FreezeControls.vehicle then
                DisableControlAction(0, 23, true)   -- Enter Vehicle
                DisableControlAction(0, 75, true)   -- Exit Vehicle
            end

            if RoundConfig.FreezeControls.interaction then
                DisableControlAction(0, 38, true)   -- Interaction
            end
        end
    end)
end

-- =====================================================
-- ROUND ACTIVE PHASE
-- =====================================================

function StartRound(matchId, roundTime)
    CurrentMatch = matchId
    RoundState = 'active'
    RoundStarted = true
    RoundTimer = roundTime
    ShowRoundHUD = true

    print(string.format('^2[TGW-ROUND CLIENT]^7 Round started - %d seconds', roundTime))

    -- Update activity
    UpdateActivity()

    -- Start input monitoring for AFK detection
    StartInputMonitoring()
end

function UpdateRoundTimer(remainingTime)
    RoundTimer = remainingTime
end

function StartInputMonitoring()
    CreateThread(function()
        while RoundStarted and RoundState == 'active' do
            Wait(100)

            -- Check for any input activity
            if IsControlPressed(0, 30) or IsControlPressed(0, 31) or  -- Movement
               IsControlPressed(0, 24) or IsControlPressed(0, 25) or  -- Attack/Aim
               IsControlPressed(0, 21) or IsControlPressed(0, 22) then -- Sprint/Jump
                UpdateActivity()
            end
        end
    end)
end

-- =====================================================
-- SUDDEN DEATH PHASE
-- =====================================================

function StartSuddenDeath(suddenDeathTime)
    InSuddenDeath = true
    SuddenDeathTimer = suddenDeathTime
    RoundState = 'sudden_death'

    print('^3[TGW-ROUND CLIENT]^7 Sudden Death phase started')

    -- Show sudden death notification
    TGWCore.ShowTGWNotification(RoundConfig.Messages.sudden_death, 'warning', 3000)

    -- Play sudden death sound
    PlaySoundFrontend(-1, "MP_WAVE_COMPLETE", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
end

function UpdateSuddenDeathTimer(remainingTime)
    SuddenDeathTimer = remainingTime
end

function UpdateArenaRadius(newRadius)
    ArenaRadius = newRadius

    -- Show radius update notification
    TGWCore.ShowTGWNotification(string.format('Arena menyusut! Radius: %.1fm', newRadius), 'warning', 2000)
end

function CheckOutOfBounds(currentRadius, damagePerSec)
    local playerPed = PlayerPedId()
    local arenaExport = exports['tgw_arena']

    if arenaExport and arenaExport:IsOutOfBounds() then
        -- Player is out of bounds during sudden death
        -- Apply damage (this would be handled server-side in production)
        local currentHealth = GetEntityHealth(playerPed)
        local newHealth = math.max(0, currentHealth - damagePerSec)

        -- Show damage effect
        SetEntityHealth(playerPed, newHealth)

        -- Show out of bounds warning
        TGWCore.ShowTGWNotification('Di luar zona! Mengambil damage!', 'error', 1000)

        -- Screen damage effect
        SetTimecycleModifier("damage")
        Wait(200)
        ClearTimecycleModifier()
    end
end

-- =====================================================
-- ROUND HUD SYSTEM
-- =====================================================

function StartRoundHUD()
    CreateThread(function()
        while true do
            Wait(0)

            if ShowRoundHUD and RoundStarted then
                DrawRoundHUD()
            end
        end
    end)
end

function DrawRoundHUD()
    -- Main round info
    DrawRoundInfo()

    -- Timer
    DrawRoundTimer()

    -- Sudden death indicator
    if InSuddenDeath then
        DrawSuddenDeathIndicator()
    end

    -- Opponent info
    DrawOpponentInfo()
end

function DrawRoundInfo()
    -- Round type indicator
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.5, 0.5)
    SetTextColour(255, 255, 255, 255)
    SetTextEntry("STRING")
    AddTextComponentString(string.format("Round Type: %s", RoundType:upper()))
    DrawText(0.02, 0.02)
end

function DrawRoundTimer()
    local timerText = ""
    local timerColor = {255, 255, 255, 255}

    if InSuddenDeath then
        timerText = string.format("SUDDEN DEATH: %02d", math.ceil(SuddenDeathTimer))
        timerColor = {255, 0, 0, 255}
    else
        local minutes = math.floor(RoundTimer / 60)
        local seconds = math.floor(RoundTimer % 60)
        timerText = string.format("%02d:%02d", minutes, seconds)

        -- Change color when time is low
        if RoundTimer <= 10 then
            timerColor = {255, 0, 0, 255}
        elseif RoundTimer <= 30 then
            timerColor = {255, 255, 0, 255}
        end
    end

    -- Draw timer background
    DrawRect(0.5, 0.05, 0.15, 0.06, 0, 0, 0, 150)

    -- Draw timer text
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.8, 0.8)
    SetTextColour(timerColor[1], timerColor[2], timerColor[3], timerColor[4])
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString(timerText)
    DrawText(0.5, 0.03)
end

function DrawSuddenDeathIndicator()
    -- Flashing sudden death indicator
    local alpha = math.floor((GetGameTimer() % 1000) / 500) * 100 + 100

    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.6, 0.6)
    SetTextColour(255, 0, 0, alpha)
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString("⚡ SUDDEN DEATH ⚡")
    DrawText(0.5, 0.10)

    -- Arena radius indicator
    if ArenaRadius < OriginalRadius then
        SetTextScale(0.4, 0.4)
        SetTextColour(255, 255, 0, 255)
        SetTextEntry("STRING")
        AddTextComponentString(string.format("Arena Radius: %.1fm", ArenaRadius))
        DrawText(0.5, 0.13)
    end
end

function DrawOpponentInfo()
    if OpponentName and OpponentName ~= '' then
        SetTextFont(4)
        SetTextProportional(true)
        SetTextScale(0.5, 0.5)
        SetTextColour(255, 255, 255, 255)
        SetTextEntry("STRING")
        AddTextComponentString(string.format("VS: %s", OpponentName))
        DrawText(0.02, 0.05)
    end
end

-- =====================================================
-- ROUND RESULT DISPLAY
-- =====================================================

function ShowRoundResult(resultData)
    RoundStarted = false
    ShowRoundHUD = false
    InSuddenDeath = false

    print(string.format('^2[TGW-ROUND CLIENT]^7 Round ended - Result: %s', resultData.result))

    -- Show result notification
    local resultMessage = ""
    local notifType = "info"

    if resultData.result == 'win' then
        resultMessage = "🏆 MENANG!"
        notifType = "success"
        PlaySoundFrontend(-1, "RACE_PLACED", "HUD_AWARDS", 1)
    elseif resultData.result == 'lose' then
        resultMessage = "💀 KALAH"
        notifType = "error"
        PlaySoundFrontend(-1, "LOSER", "HUD_AWARDS", 1)
    else
        resultMessage = "🤝 SERI"
        notifType = "info"
    end

    TGWCore.ShowTGWNotification(resultMessage, notifType, 5000)

    -- Show detailed result overlay
    ShowResultOverlay(resultData)

    -- Reset state
    CreateThread(function()
        Wait(5000)
        ResetRoundState()
    end)
end

function ShowResultOverlay(resultData)
    CreateThread(function()
        local overlayTime = 5000
        local startTime = GetGameTimer()

        while GetGameTimer() - startTime < overlayTime do
            Wait(0)

            -- Background overlay
            DrawRect(0.5, 0.5, 1.0, 1.0, 0, 0, 0, 100)

            -- Result panel
            local panelWidth = 0.4
            local panelHeight = 0.3
            local panelX = 0.5 - (panelWidth / 2)
            local panelY = 0.5 - (panelHeight / 2)

            -- Panel background
            DrawRect(0.5, 0.5, panelWidth, panelHeight, 0, 0, 0, 200)
            DrawRect(0.5, 0.5, panelWidth + 0.005, panelHeight + 0.005, 255, 255, 255, 255)

            -- Result text
            local resultColor = {255, 255, 255}
            if resultData.result == 'win' then
                resultColor = {0, 255, 0}
            elseif resultData.result == 'lose' then
                resultColor = {255, 0, 0}
            end

            SetTextFont(4)
            SetTextProportional(true)
            SetTextScale(1.0, 1.0)
            SetTextColour(resultColor[1], resultColor[2], resultColor[3], 255)
            SetTextCentre(true)
            SetTextEntry("STRING")
            AddTextComponentString(resultData.result:upper())
            DrawText(0.5, 0.42)

            -- Details
            SetTextScale(0.5, 0.5)
            SetTextColour(255, 255, 255, 255)
            SetTextEntry("STRING")
            AddTextComponentString(string.format("Duration: %02d:%02d",
                math.floor(resultData.duration / 60),
                math.floor(resultData.duration % 60)
            ))
            DrawText(0.5, 0.50)

            SetTextEntry("STRING")
            AddTextComponentString(string.format("Round Type: %s", resultData.roundType:upper()))
            DrawText(0.5, 0.53)

            SetTextEntry("STRING")
            AddTextComponentString(string.format("Reason: %s", (resultData.reason or ''):upper()))
            DrawText(0.5, 0.56)

            -- Press ENTER to continue
            SetTextScale(0.4, 0.4)
            SetTextColour(200, 200, 200, 255)
            SetTextEntry("STRING")
            AddTextComponentString("Press ENTER to continue")
            DrawText(0.5, 0.62)
        end
    end)
end

-- =====================================================
-- ACTIVITY TRACKING
-- =====================================================

function StartActivityTracker()
    CreateThread(function()
        while true do
            Wait(ActivityCheckInterval)

            if RoundStarted then
                TriggerServerEvent('tgw:round:updateActivity')
            end
        end
    end)
end

function UpdateActivity()
    LastActivityTime = GetGameTimer()
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function GetPlayerNameByIdentifier(identifier)
    -- This would normally get player name from server
    -- For now, return simplified version
    return "Opponent"
end

function ResetRoundState()
    CurrentMatch = nil
    RoundState = nil
    RoundStarted = false
    InFreeze = false
    InSuddenDeath = false
    ShowRoundHUD = false
    OpponentName = ''
    RoundType = ''
    RoundTimer = 0
    SuddenDeathTimer = 0
    CountdownActive = false
    ArenaRadius = OriginalRadius
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('IsInRound', function()
    return RoundStarted
end)

exports('GetRoundState', function()
    return RoundState
end)

exports('GetRoundTimer', function()
    return RoundTimer
end)

exports('IsInFreeze', function()
    return InFreeze
end)

exports('IsInSuddenDeath', function()
    return InSuddenDeath
end)

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        ResetRoundState()
    end
end)