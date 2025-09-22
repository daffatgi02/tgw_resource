-- =====================================================
-- TGW INTEGRITY CLIENT - ANTI-CHEAT MONITORING
-- =====================================================
-- Purpose: Client-side monitoring and data collection for anti-cheat
-- Dependencies: tgw_core
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']

-- Client monitoring state
local MonitoringActive = false
local LastDataSend = 0
local MonitoringData = {
    position = {x = 0, y = 0, z = 0},
    health = {current = 200, max = 200, armor = 0},
    weapon = {current = 'WEAPON_UNARMED', ammo = 0},
    movement = {speed = 0, velocity = vector3(0, 0, 0)},
    performance = {fps = 60, ping = 0}
}

-- Violation tracking
local ViolationWarnings = {}
local TrustStatus = 'GOOD'

-- =====================================================
-- INITIALIZATION
-- =====================================================

CreateThread(function()
    while not ESX do
        ESX = exports['tgw_core']:GetESX()
        Wait(100)
    end

    RegisterEventHandlers()
    StartMonitoringSystem()

    print('^2[TGW-INTEGRITY CLIENT]^7 Integrity monitoring client initialized')
end)

function RegisterEventHandlers()
    -- Server requests for monitoring data
    RegisterNetEvent('tgw:integrity:requestData', function()
        if MonitoringActive then
            SendMonitoringData()
        end
    end)

    -- Violation warnings
    RegisterNetEvent('tgw:integrity:warning', function(violationType)
        HandleViolationWarning(violationType)
    end)

    -- Admin notifications
    RegisterNetEvent('tgw:integrity:adminNotification', function(notification)
        HandleAdminNotification(notification)
    end)

    -- Trust status updates
    RegisterNetEvent('tgw:integrity:trustUpdate', function(newStatus, score)
        UpdateTrustStatus(newStatus, score)
    end)

    -- Game state events
    RegisterNetEvent('tgw:round:started', function()
        StartRoundMonitoring()
    end)

    RegisterNetEvent('tgw:round:result', function()
        StopRoundMonitoring()
    end)

    RegisterNetEvent('tgw:queue:joined', function()
        MonitoringActive = true
    end)

    RegisterNetEvent('tgw:queue:left', function()
        MonitoringActive = false
    end)
end

-- =====================================================
-- MONITORING SYSTEM
-- =====================================================

function StartMonitoringSystem()
    CreateThread(function()
        while true do
            Wait(IntegrityConfig.Performance.processingInterval or 1000)

            if MonitoringActive then
                CollectMonitoringData()

                -- Send data periodically
                local currentTime = GetGameTimer()
                if currentTime - LastDataSend > (IntegrityConfig.Performance.processingInterval or 1000) then
                    SendMonitoringData()
                    LastDataSend = currentTime
                end
            end
        end
    end)

    -- Start specific monitoring threads
    StartMovementMonitoring()
    StartWeaponMonitoring()
    StartHealthMonitoring()
    StartPerformanceMonitoring()
end

function CollectMonitoringData()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerHealth = GetEntityHealth(playerPed)
    local playerArmor = GetPedArmour(playerPed)
    local currentWeapon = GetSelectedPedWeapon(playerPed)

    -- Update position data
    MonitoringData.position = {
        x = playerCoords.x,
        y = playerCoords.y,
        z = playerCoords.z
    }

    -- Update health data
    MonitoringData.health = {
        current = playerHealth,
        max = GetEntityMaxHealth(playerPed),
        armor = playerArmor,
        damageReceived = CalculateDamageReceived(playerHealth)
    }

    -- Update weapon data
    MonitoringData.weapon = {
        current = currentWeapon,
        ammo = GetAmmoInPedWeapon(playerPed, currentWeapon),
        reloaded = false -- This would need more sophisticated tracking
    }

    -- Update movement data
    local velocity = GetEntityVelocity(playerPed)
    MonitoringData.movement = {
        speed = math.sqrt(velocity.x^2 + velocity.y^2 + velocity.z^2),
        velocity = velocity,
        onGround = not IsPedFalling(playerPed) and not IsPedInParachuteFreeFall(playerPed)
    }

    -- Update performance data
    MonitoringData.performance = {
        fps = math.floor(1.0 / GetFrameTime()),
        ping = GetPlayerPing(PlayerId())
    }
end

function SendMonitoringData()
    -- Only send if there's meaningful data or changes
    if not MonitoringActive then
        return
    end

    TriggerServerEvent('tgw:integrity:playerData', MonitoringData)
end

-- =====================================================
-- SPECIALIZED MONITORING
-- =====================================================

function StartMovementMonitoring()
    if not IntegrityConfig.Detection.movement.enabled then
        return
    end

    CreateThread(function()
        local lastPosition = nil
        local lastTime = GetGameTimer()

        while true do
            Wait(IntegrityConfig.Detection.movement.checkInterval or 500)

            if MonitoringActive then
                local playerPed = PlayerPedId()
                local currentPosition = GetEntityCoords(playerPed)
                local currentTime = GetGameTimer()

                if lastPosition then
                    local distance = #(currentPosition - lastPosition)
                    local timeDiff = (currentTime - lastTime) / 1000 -- Convert to seconds

                    if timeDiff > 0 then
                        local speed = distance / timeDiff

                        -- Check for speed anomalies
                        if speed > (IntegrityConfig.Detection.movement.maxSpeed or 15) then
                            -- This could be a speed hack, but also could be legitimate (vehicle, teleport by server, etc.)
                            -- We let the server decide based on context
                        end

                        -- Check for teleportation
                        if distance > (IntegrityConfig.Detection.movement.teleportDistanceThreshold or 50) and timeDiff < 1 then
                            -- Potential teleportation detected
                            -- Server will validate this based on game state
                        end
                    end
                end

                lastPosition = currentPosition
                lastTime = currentTime
            end
        end
    end)
end

function StartWeaponMonitoring()
    if not IntegrityConfig.Detection.weapon.enabled then
        return
    end

    CreateThread(function()
        local lastWeapon = 'WEAPON_UNARMED'
        local lastAmmo = 0

        while true do
            Wait(100) -- Check weapons frequently

            if MonitoringActive then
                local playerPed = PlayerPedId()
                local currentWeapon = GetSelectedPedWeapon(playerPed)
                local currentAmmo = GetAmmoInPedWeapon(playerPed, currentWeapon)

                -- Check for weapon changes
                if currentWeapon ~= lastWeapon then
                    -- Weapon changed - validate authorization
                    ValidateWeaponAuthorization(currentWeapon)
                end

                -- Check for ammo anomalies
                if currentWeapon == lastWeapon and currentAmmo > lastAmmo + 1 then
                    -- Ammo increased without reloading - potential infinite ammo
                    if not IsPlayerReloading(PlayerId()) then
                        -- Report potential infinite ammo
                        ReportSuspiciousActivity('INFINITE_AMMO', {
                            weapon = currentWeapon,
                            oldAmmo = lastAmmo,
                            newAmmo = currentAmmo
                        })
                    end
                end

                lastWeapon = currentWeapon
                lastAmmo = currentAmmo
            end
        end
    end)
end

function StartHealthMonitoring()
    if not IntegrityConfig.Detection.health.enabled then
        return
    end

    CreateThread(function()
        local lastHealth = GetEntityHealth(PlayerPedId())
        local lastArmor = GetPedArmour(PlayerPedId())
        local damageEvents = {}

        while true do
            Wait(100) -- Check health frequently

            if MonitoringActive then
                local playerPed = PlayerPedId()
                local currentHealth = GetEntityHealth(playerPed)
                local currentArmor = GetPedArmour(playerPed)

                -- Check for health anomalies
                if currentHealth > (IntegrityConfig.Detection.health.maxHealthThreshold or 200) then
                    ReportSuspiciousActivity('HEALTH_HACK', {
                        health = currentHealth,
                        maxAllowed = IntegrityConfig.Detection.health.maxHealthThreshold or 200
                    })
                end

                -- Check for god mode (no damage taken when it should be)
                if HasEntityBeenDamagedByAnyPed(playerPed) or HasEntityBeenDamagedByAnyVehicle(playerPed) then
                    table.insert(damageEvents, {
                        timestamp = GetGameTimer(),
                        healthBefore = lastHealth,
                        healthAfter = currentHealth,
                        armorBefore = lastArmor,
                        armorAfter = currentArmor
                    })

                    -- Keep only recent damage events
                    if #damageEvents > 10 then
                        table.remove(damageEvents, 1)
                    end

                    -- Check if health didn't decrease despite damage
                    if currentHealth >= lastHealth and currentArmor >= lastArmor then
                        ReportSuspiciousActivity('DAMAGE_IMMUNITY', {
                            healthBefore = lastHealth,
                            healthAfter = currentHealth,
                            armorBefore = lastArmor,
                            armorAfter = currentArmor,
                            damageEvents = #damageEvents
                        })
                    end

                    ClearEntityLastDamageEntity(playerPed)
                end

                lastHealth = currentHealth
                lastArmor = currentArmor
            end
        end
    end)
end

function StartPerformanceMonitoring()
    if not IntegrityConfig.Detection.statistical.enabled then
        return
    end

    CreateThread(function()
        local performanceData = {
            totalShots = 0,
            headshots = 0,
            kills = 0,
            deaths = 0,
            matchesPlayed = 0
        }

        while true do
            Wait(5000) -- Check every 5 seconds

            if MonitoringActive then
                -- Calculate performance metrics
                local headshotRate = performanceData.totalShots > 0 and performanceData.headshots / performanceData.totalShots or 0
                local kdr = performanceData.deaths > 0 and performanceData.kills / performanceData.deaths or performanceData.kills

                -- Update monitoring data with performance stats
                MonitoringData.performance.headshotRate = headshotRate
                MonitoringData.performance.kdr = kdr
                MonitoringData.performance.totalShots = performanceData.totalShots
                MonitoringData.performance.totalMatches = performanceData.matchesPlayed
            end
        end
    end)
end

-- =====================================================
-- ROUND-SPECIFIC MONITORING
-- =====================================================

function StartRoundMonitoring()
    MonitoringActive = true

    -- Reset round-specific counters
    RoundData = {
        startTime = GetGameTimer(),
        shots = 0,
        hits = 0,
        headshots = 0,
        kills = 0,
        deaths = 0,
        damageDealt = 0,
        damageReceived = 0
    }

    print('^2[TGW-INTEGRITY CLIENT]^7 Started round monitoring')
end

function StopRoundMonitoring()
    if not RoundData then
        return
    end

    local duration = (GetGameTimer() - RoundData.startTime) / 1000

    -- Calculate round statistics
    local roundStats = {
        duration = duration,
        shots = RoundData.shots,
        hits = RoundData.hits,
        headshots = RoundData.headshots,
        kills = RoundData.kills,
        deaths = RoundData.deaths,
        accuracy = RoundData.shots > 0 and RoundData.hits / RoundData.shots or 0,
        headshotRate = RoundData.hits > 0 and RoundData.headshots / RoundData.hits or 0,
        damageDealt = RoundData.damageDealt,
        damageReceived = RoundData.damageReceived
    }

    -- Send round statistics to server for analysis
    TriggerServerEvent('tgw:integrity:roundStats', roundStats)

    RoundData = nil
    MonitoringActive = false

    print('^2[TGW-INTEGRITY CLIENT]^7 Stopped round monitoring')
end

-- =====================================================
-- VIOLATION HANDLING
-- =====================================================

function HandleViolationWarning(violationType)
    local violationConfig = IntegrityConfig.ViolationTypes[violationType]
    if not violationConfig then
        return
    end

    -- Track warnings
    if not ViolationWarnings[violationType] then
        ViolationWarnings[violationType] = 0
    end
    ViolationWarnings[violationType] = ViolationWarnings[violationType] + 1

    -- Show warning to player
    local warningMessage = string.format(
        'TGW Anti-Cheat Warning\n%s\nWarning %d for this violation type',
        violationConfig.description,
        ViolationWarnings[violationType]
    )

    TGWCore.ShowTGWNotification(warningMessage, 'warning', 8000)

    -- Play warning sound
    PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 1)

    print(string.format('^3[TGW-INTEGRITY WARNING]^7 %s - Warning %d', violationType, ViolationWarnings[violationType]))
end

function HandleAdminNotification(notification)
    -- Only show to admins
    if not TGWCore.IsPlayerAdmin(PlayerId()) then
        return
    end

    local message = ''
    if notification.type == 'violation' then
        message = string.format(
            'TGW Anti-Cheat Alert\nPlayer: %s\nViolation: %s (%s)\nTime: %s',
            notification.player,
            notification.violation,
            notification.severity,
            os.date('%H:%M:%S', notification.timestamp)
        )
    elseif notification.type == 'report' then
        message = string.format(
            'Player Report\nReporter: %s\nTarget: %s\nReason: %s\nTime: %s',
            notification.reporter,
            notification.target,
            notification.reason,
            os.date('%H:%M:%S', notification.timestamp)
        )
    end

    TGWCore.ShowTGWNotification(message, 'warning', 10000)
    PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', 1)
end

function UpdateTrustStatus(newStatus, score)
    TrustStatus = newStatus

    if IntegrityConfig.Notifications.notifyOnTrustScoreChange then
        local statusColor = {
            GOOD = 'success',
            NEUTRAL = 'info',
            SUSPICIOUS = 'warning',
            PROBLEMATIC = 'error',
            BANNED = 'error'
        }

        TGWCore.ShowTGWNotification(
            string.format('Trust Status: %s (Score: %d)', newStatus, score),
            statusColor[newStatus] or 'info',
            5000
        )
    end

    print(string.format('^2[TGW-INTEGRITY]^7 Trust status updated: %s (Score: %d)', newStatus, score))
end

-- =====================================================
-- VALIDATION FUNCTIONS
-- =====================================================

function ValidateWeaponAuthorization(weaponHash)
    -- Check if player should have this weapon based on current loadout
    local loadoutExport = exports['tgw_loadout']
    if loadoutExport and loadoutExport:IsLoadoutActive() then
        local loadout = loadoutExport:GetCurrentLoadout()
        if loadout then
            local authorized = false

            if loadout.weapons.primary and GetHashKey(loadout.weapons.primary) == weaponHash then
                authorized = true
            elseif loadout.weapons.secondary and GetHashKey(loadout.weapons.secondary) == weaponHash then
                authorized = true
            elseif weaponHash == GetHashKey('WEAPON_UNARMED') then
                authorized = true
            end

            if not authorized then
                ReportSuspiciousActivity('UNAUTHORIZED_WEAPON', {
                    weapon = weaponHash,
                    authorizedWeapons = loadout.weapons
                })
            end

            return authorized
        end
    end

    return true -- Allow if no loadout system active
end

function CalculateDamageReceived(currentHealth)
    -- This would calculate damage received since last check
    -- Simplified for now
    return 0
end

function ReportSuspiciousActivity(violationType, evidence)
    TriggerServerEvent('tgw:integrity:reportViolation', violationType, evidence)
    print(string.format('^3[TGW-INTEGRITY]^7 Reported suspicious activity: %s', violationType))
end

-- =====================================================
-- PLAYER REPORTING SYSTEM
-- =====================================================

RegisterCommand('report', function(source, args, rawCommand)
    if #args < 2 then
        TGWCore.ShowTGWNotification('Usage: /report <player> <reason>', 'error', 3000)
        return
    end

    local targetPlayer = args[1]
    local reason = table.concat(args, ' ', 2)

    -- Simple evidence collection (this could be enhanced)
    local evidence = {
        reporterPosition = GetEntityCoords(PlayerPedId()),
        timestamp = os.time(),
        gameTime = GetGameTimer()
    }

    TriggerServerEvent('tgw:integrity:playerReport', targetPlayer, reason, evidence)
    TGWCore.ShowTGWNotification(string.format('Reported %s for: %s', targetPlayer, reason), 'success', 3000)
end, false)

-- =====================================================
-- HUD INTEGRATION
-- =====================================================

function DrawIntegrityHUD()
    if not IntegrityConfig.Display or not IntegrityConfig.Display.showTrustStatus then
        return
    end

    local trustColor = {
        GOOD = {0, 255, 0},
        NEUTRAL = {255, 255, 0},
        SUSPICIOUS = {255, 165, 0},
        PROBLEMATIC = {255, 0, 0},
        BANNED = {128, 0, 128}
    }

    local color = trustColor[TrustStatus] or {255, 255, 255}

    -- Draw trust status indicator
    SetTextFont(4)
    SetTextProportional(true)
    SetTextScale(0.3, 0.3)
    SetTextColour(color[1], color[2], color[3], 255)
    SetTextEntry('STRING')
    AddTextComponentString(string.format('Trust: %s', TrustStatus))
    DrawText(0.02, 0.02)
end

-- Start HUD drawing if configured
CreateThread(function()
    while true do
        Wait(0)
        DrawIntegrityHUD()
    end
end)

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function GetTrustStatus()
    return TrustStatus
end

function IsMonitoringActive()
    return MonitoringActive
end

function GetViolationWarnings()
    return ViolationWarnings
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('GetTrustStatus', GetTrustStatus)
exports('IsMonitoringActive', IsMonitoringActive)
exports('GetViolationWarnings', GetViolationWarnings)
exports('ReportSuspiciousActivity', ReportSuspiciousActivity)

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        MonitoringActive = false
        RoundData = nil
    end
end)