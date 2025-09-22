-- =====================================================
-- TGW INTEGRITY SERVER - ANTI-CHEAT AND MONITORING
-- =====================================================
-- Purpose: Monitor player behavior and detect cheating/exploits
-- Dependencies: tgw_core, tgw_round, tgw_rating, es_extended
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']

-- Integrity monitoring state
local PlayerTrustScores = {}        -- [identifier] = trustScore
local ViolationHistory = {}         -- [identifier] = violationArray
local ActiveMonitoring = {}         -- [identifier] = monitoringData
local DetectionQueue = {}           -- Queued detections for processing

-- Performance tracking
local IntegrityStats = {
    totalChecks = 0,
    violationsDetected = 0,
    falsePositives = 0,
    trustedPlayers = 0,
    bannedPlayers = 0
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
    InitializeIntegritySystem()
    StartMonitoringThreads()
    StartPerformanceTracking()

    print('^2[TGW-INTEGRITY SERVER]^7 Anti-cheat and integrity monitoring system initialized')
end)

function RegisterEventHandlers()
    -- Player monitoring events
    RegisterNetEvent('tgw:integrity:playerData', function(data)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            ProcessPlayerData(xPlayer.identifier, data, src)
        end
    end)

    RegisterNetEvent('tgw:integrity:reportViolation', function(violationType, evidence)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            ReportViolation(xPlayer.identifier, violationType, evidence, 'automatic')
        end
    end)

    RegisterNetEvent('tgw:integrity:playerReport', function(targetPlayer, reason, evidence)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            ProcessPlayerReport(xPlayer.identifier, targetPlayer, reason, evidence)
        end
    end)

    -- Game state events
    RegisterNetEvent('tgw:round:started', function(matchData)
        for _, playerData in pairs(matchData.players) do
            StartMatchMonitoring(playerData.identifier, matchData.matchId)
        end
    end)

    RegisterNetEvent('tgw:round:result', function(resultData)
        for _, playerData in pairs(resultData.players) do
            AnalyzeMatchPerformance(playerData.identifier, resultData)
        end
    end)

    RegisterNetEvent('tgw:round:killEvent', function(killerIdentifier, victimIdentifier, killData)
        ValidateKillEvent(killerIdentifier, victimIdentifier, killData)
    end)

    -- Player connection events
    RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
        LoadPlayerTrustScore(xPlayer.identifier)
        InitializePlayerMonitoring(xPlayer.identifier, playerId)
    end)

    RegisterNetEvent('esx:playerDropped', function(playerId, reason)
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            SavePlayerTrustScore(xPlayer.identifier)
            CleanupPlayerMonitoring(xPlayer.identifier)
        end
    end)

    -- Admin events
    RegisterNetEvent('tgw:integrity:adminAction', function(action, targetIdentifier, reason)
        local src = source
        if TGWCore.IsPlayerAdmin(src) then
            ProcessAdminAction(action, targetIdentifier, reason, src)
        end
    end)
end

-- =====================================================
-- TRUST SCORE SYSTEM
-- =====================================================

function LoadPlayerTrustScore(identifier)
    MySQL.query('SELECT trust_score, total_violations, last_violation FROM tgw_integrity WHERE identifier = ?',
        {identifier}, function(results)
        if results and #results > 0 then
            local data = results[1]
            PlayerTrustScores[identifier] = {
                score = data.trust_score,
                totalViolations = data.total_violations,
                lastViolation = data.last_violation,
                status = CalculateTrustStatus(data.trust_score),
                lastUpdated = os.time()
            }
        else
            -- Initialize new player
            InitializePlayerTrustScore(identifier)
        end

        -- Load violation history
        LoadPlayerViolationHistory(identifier)

        print(string.format('^2[TGW-INTEGRITY]^7 Loaded trust score for %s: %d (%s)',
            identifier, PlayerTrustScores[identifier].score, PlayerTrustScores[identifier].status))
    end)
end

function InitializePlayerTrustScore(identifier)
    local defaultScore = IntegrityConfig.TrustScore.defaultScore

    PlayerTrustScores[identifier] = {
        score = defaultScore,
        totalViolations = 0,
        lastViolation = nil,
        status = CalculateTrustStatus(defaultScore),
        lastUpdated = os.time()
    }

    -- Insert into database
    MySQL.execute('INSERT INTO tgw_integrity (identifier, trust_score) VALUES (?, ?)',
        {identifier, defaultScore})

    print(string.format('^2[TGW-INTEGRITY]^7 Initialized trust score for %s: %d', identifier, defaultScore))
end

function UpdateTrustScore(identifier, change, reason)
    local data = PlayerTrustScores[identifier]
    if not data then
        return false
    end

    local oldScore = data.score
    local oldStatus = data.status

    -- Apply score change
    data.score = math.max(IntegrityConfig.TrustScore.minScore,
                         math.min(IntegrityConfig.TrustScore.maxScore, data.score + change))
    data.status = CalculateTrustStatus(data.score)
    data.lastUpdated = os.time()

    -- Check for status change
    local statusChanged = oldStatus ~= data.status

    -- Save to database
    QueueTrustScoreUpdate(identifier)

    -- Notify if significant change
    if statusChanged then
        NotifyTrustStatusChange(identifier, oldStatus, data.status, reason)
    end

    print(string.format('^2[TGW-INTEGRITY TRUST]^7 %s: %d -> %d (%+d) [%s] -> %s',
        identifier, oldScore, data.score, change, reason, data.status))

    return true
end

function CalculateTrustStatus(score)
    for threshold, status in pairs(IntegrityConfig.TrustScore.escalationThresholds) do
        if score >= threshold then
            return status
        end
    end
    return 'BANNED'
end

function SavePlayerTrustScore(identifier)
    local data = PlayerTrustScores[identifier]
    if not data then
        return
    end

    MySQL.execute([[
        UPDATE tgw_integrity SET
            trust_score = ?, total_violations = ?, last_violation = ?, updated_at = NOW()
        WHERE identifier = ?
    ]], {data.score, data.totalViolations, data.lastViolation, identifier})
end

-- =====================================================
-- VIOLATION DETECTION AND REPORTING
-- =====================================================

function ReportViolation(identifier, violationType, evidence, source)
    local violationConfig = IntegrityConfig.ViolationTypes[violationType]
    if not violationConfig then
        print(string.format('^1[TGW-INTEGRITY ERROR]^7 Unknown violation type: %s', violationType))
        return false
    end

    local severity = violationConfig.severity
    local severityConfig = IntegrityConfig.Violations[severity]

    print(string.format('^1[TGW-INTEGRITY VIOLATION]^7 %s - %s (%s) - Source: %s',
        identifier, violationType, severity, source))

    -- Record violation
    RecordViolation(identifier, violationType, severity, evidence, source)

    -- Update trust score
    UpdateTrustScore(identifier, severityConfig.trustScoreImpact, violationType)

    -- Take automatic action
    if IntegrityConfig.AutoResponse.enableAutoKick or IntegrityConfig.AutoResponse.enableAutoBan then
        ProcessAutomaticAction(identifier, violationType, severity)
    end

    -- Notify admins if required
    if severityConfig.reportToAdmins then
        NotifyAdminsOfViolation(identifier, violationType, severity, evidence)
    end

    IntegrityStats.violationsDetected = IntegrityStats.violationsDetected + 1

    return true
end

function RecordViolation(identifier, violationType, severity, evidence, source)
    if not ViolationHistory[identifier] then
        ViolationHistory[identifier] = {}
    end

    local violation = {
        timestamp = os.time(),
        type = violationType,
        severity = severity,
        evidence = evidence,
        source = source,
        action_taken = 'none'
    }

    table.insert(ViolationHistory[identifier], violation)

    -- Limit history size
    if #ViolationHistory[identifier] > IntegrityConfig.Limits.maxViolationHistory then
        table.remove(ViolationHistory[identifier], 1)
    end

    -- Save to database
    MySQL.execute([[
        INSERT INTO tgw_integrity_violations (identifier, violation_type, severity, evidence, source, created_at)
        VALUES (?, ?, ?, ?, ?, FROM_UNIXTIME(?))
    ]], {identifier, violationType, severity, evidence, source, os.time()})

    -- Update violation count
    if PlayerTrustScores[identifier] then
        PlayerTrustScores[identifier].totalViolations = PlayerTrustScores[identifier].totalViolations + 1
        PlayerTrustScores[identifier].lastViolation = os.time()
    end
end

function LoadPlayerViolationHistory(identifier)
    MySQL.query([[
        SELECT violation_type, severity, evidence, source, UNIX_TIMESTAMP(created_at) as timestamp
        FROM tgw_integrity_violations
        WHERE identifier = ?
        ORDER BY created_at DESC
        LIMIT 100
    ]], {identifier}, function(results)
        if results then
            ViolationHistory[identifier] = {}
            for _, row in ipairs(results) do
                table.insert(ViolationHistory[identifier], {
                    timestamp = row.timestamp,
                    type = row.violation_type,
                    severity = row.severity,
                    evidence = row.evidence,
                    source = row.source
                })
            end
        end
    end)
end

-- =====================================================
-- PLAYER MONITORING
-- =====================================================

function InitializePlayerMonitoring(identifier, playerId)
    ActiveMonitoring[identifier] = {
        playerId = playerId,
        startTime = os.time(),
        positionHistory = {},
        weaponHistory = {},
        healthHistory = {},
        damageEvents = {},
        lastUpdate = os.time(),
        flags = {}
    }

    -- Start monitoring threads for this player
    StartPlayerMonitoringThreads(identifier)
end

function ProcessPlayerData(identifier, data, playerId)
    local monitoring = ActiveMonitoring[identifier]
    if not monitoring then
        return
    end

    IntegrityStats.totalChecks = IntegrityStats.totalChecks + 1

    -- Update monitoring data
    monitoring.lastUpdate = os.time()

    -- Movement checks
    if IntegrityConfig.Detection.movement.enabled then
        ValidateMovementData(identifier, data.movement)
    end

    -- Weapon checks
    if IntegrityConfig.Detection.weapon.enabled and data.weapon then
        ValidateWeaponData(identifier, data.weapon)
    end

    -- Health checks
    if IntegrityConfig.Detection.health.enabled and data.health then
        ValidateHealthData(identifier, data.health)
    end

    -- Performance checks
    if IntegrityConfig.Detection.statistical.enabled and data.performance then
        ValidatePerformanceData(identifier, data.performance)
    end
end

function ValidateMovementData(identifier, movementData)
    if not movementData then
        return
    end

    local monitoring = ActiveMonitoring[identifier]
    local config = IntegrityConfig.Detection.movement

    -- Check for teleportation
    if #monitoring.positionHistory > 0 then
        local lastPos = monitoring.positionHistory[#monitoring.positionHistory]
        local distance = #(vector3(movementData.x, movementData.y, movementData.z) - lastPos.position)
        local timeDiff = (os.time() - lastPos.timestamp)

        if timeDiff > 0 and distance > config.teleportDistanceThreshold then
            ReportViolation(identifier, 'TELEPORT', {
                distance = distance,
                timeDiff = timeDiff,
                oldPos = lastPos.position,
                newPos = vector3(movementData.x, movementData.y, movementData.z)
            }, 'movement_validation')
        end

        -- Check for speed hacking
        if config.speedHackDetectionEnabled and timeDiff > 0 then
            local speed = distance / timeDiff
            if speed > config.maxSpeed then
                ReportViolation(identifier, 'SPEED_HACK', {
                    speed = speed,
                    maxAllowed = config.maxSpeed,
                    distance = distance,
                    timeDiff = timeDiff
                }, 'movement_validation')
            end
        end
    end

    -- Record position
    table.insert(monitoring.positionHistory, {
        position = vector3(movementData.x, movementData.y, movementData.z),
        timestamp = os.time()
    })

    -- Limit history size
    if #monitoring.positionHistory > 20 then
        table.remove(monitoring.positionHistory, 1)
    end
end

function ValidateWeaponData(identifier, weaponData)
    if not weaponData then
        return
    end

    local monitoring = ActiveMonitoring[identifier]
    local config = IntegrityConfig.Detection.weapon

    -- Check for unauthorized weapons
    if config.unauthorizedWeaponCheck then
        local isAuthorized = ValidateWeaponAuthorization(identifier, weaponData.weapon)
        if not isAuthorized then
            ReportViolation(identifier, 'UNAUTHORIZED_WEAPON', {
                weapon = weaponData.weapon,
                currentLoadout = GetPlayerCurrentLoadout(identifier)
            }, 'weapon_validation')
        end
    end

    -- Check for infinite ammo
    if config.infiniteAmmoDetection and weaponData.ammo then
        local lastWeapon = monitoring.weaponHistory[#monitoring.weaponHistory]
        if lastWeapon and lastWeapon.weapon == weaponData.weapon then
            if weaponData.ammo > lastWeapon.ammo and not lastWeapon.reloaded then
                ReportViolation(identifier, 'INFINITE_AMMO', {
                    weapon = weaponData.weapon,
                    oldAmmo = lastWeapon.ammo,
                    newAmmo = weaponData.ammo
                }, 'weapon_validation')
            end
        end
    end

    -- Record weapon data
    table.insert(monitoring.weaponHistory, {
        weapon = weaponData.weapon,
        ammo = weaponData.ammo,
        timestamp = os.time(),
        reloaded = weaponData.reloaded
    })

    -- Limit history size
    if #monitoring.weaponHistory > 10 then
        table.remove(monitoring.weaponHistory, 1)
    end
end

function ValidateHealthData(identifier, healthData)
    if not healthData then
        return
    end

    local monitoring = ActiveMonitoring[identifier]
    local config = IntegrityConfig.Detection.health

    -- Check for god mode
    if config.godModeDetection then
        if healthData.health > config.maxHealthThreshold then
            ReportViolation(identifier, 'HEALTH_HACK', {
                health = healthData.health,
                maxAllowed = config.maxHealthThreshold
            }, 'health_validation')
        end

        -- Check for damage immunity
        if config.damageImmunityCheck and #monitoring.healthHistory > 0 then
            local lastHealth = monitoring.healthHistory[#monitoring.healthHistory]
            if healthData.damageReceived > 0 and healthData.health >= lastHealth.health then
                ReportViolation(identifier, 'DAMAGE_IMMUNITY', {
                    damageReceived = healthData.damageReceived,
                    healthBefore = lastHealth.health,
                    healthAfter = healthData.health
                }, 'health_validation')
            end
        end
    end

    -- Record health data
    table.insert(monitoring.healthHistory, {
        health = healthData.health,
        armor = healthData.armor,
        damageReceived = healthData.damageReceived,
        timestamp = os.time()
    })

    -- Limit history size
    if #monitoring.healthHistory > 10 then
        table.remove(monitoring.healthHistory, 1)
    end
end

function ValidatePerformanceData(identifier, performanceData)
    if not performanceData then
        return
    end

    local config = IntegrityConfig.Detection.statistical

    -- Check headshot rate
    if config.headshotRateThreshold and performanceData.headshotRate then
        if performanceData.headshotRate > config.headshotRateThreshold and performanceData.totalShots > 10 then
            ReportViolation(identifier, 'STAT_ANOMALY', {
                headshotRate = performanceData.headshotRate,
                threshold = config.headshotRateThreshold,
                totalShots = performanceData.totalShots
            }, 'statistical_analysis')
        end
    end

    -- Check win rate anomaly
    if config.winRateThreshold and performanceData.winRate then
        if performanceData.winRate > config.winRateThreshold and performanceData.totalMatches > 20 then
            ReportViolation(identifier, 'STAT_ANOMALY', {
                winRate = performanceData.winRate,
                threshold = config.winRateThreshold,
                totalMatches = performanceData.totalMatches
            }, 'statistical_analysis')
        end
    end
end

-- =====================================================
-- MATCH-SPECIFIC MONITORING
-- =====================================================

function StartMatchMonitoring(identifier, matchId)
    local monitoring = ActiveMonitoring[identifier]
    if not monitoring then
        return
    end

    monitoring.currentMatch = {
        matchId = matchId,
        startTime = os.time(),
        killEvents = {},
        damageEvents = {},
        movementEvents = {},
        suspiciousActivity = 0
    }

    print(string.format('^2[TGW-INTEGRITY]^7 Started match monitoring for %s (Match: %s)', identifier, matchId))
end

function ValidateKillEvent(killerIdentifier, victimIdentifier, killData)
    if not killData then
        return
    end

    local killerMonitoring = ActiveMonitoring[killerIdentifier]
    if not killerMonitoring or not killerMonitoring.currentMatch then
        return
    end

    -- Validate kill distance
    if killData.distance and killData.distance > 500 then -- 500m max reasonable distance
        ReportViolation(killerIdentifier, 'STAT_ANOMALY', {
            killDistance = killData.distance,
            weapon = killData.weapon,
            victim = victimIdentifier
        }, 'kill_validation')
    end

    -- Validate damage dealt
    if killData.damage and killData.damage > 300 then -- Max reasonable damage
        ReportViolation(killerIdentifier, 'DAMAGE_MODIFIER', {
            damage = killData.damage,
            weapon = killData.weapon,
            victim = victimIdentifier
        }, 'kill_validation')
    end

    -- Record kill event
    table.insert(killerMonitoring.currentMatch.killEvents, {
        timestamp = os.time(),
        victim = victimIdentifier,
        weapon = killData.weapon,
        distance = killData.distance,
        damage = killData.damage,
        headshot = killData.headshot
    })
end

function AnalyzeMatchPerformance(identifier, resultData)
    local monitoring = ActiveMonitoring[identifier]
    if not monitoring or not monitoring.currentMatch then
        return
    end

    local match = monitoring.currentMatch
    local duration = os.time() - match.startTime

    -- Analyze suspicious patterns
    local suspiciousScore = 0

    -- Check for impossible performance
    if #match.killEvents > 0 then
        local avgTimePerKill = duration / #match.killEvents
        if avgTimePerKill < 5 then -- Less than 5 seconds per kill
            suspiciousScore = suspiciousScore + 20
        end

        -- Check headshot percentage
        local headshots = 0
        for _, kill in ipairs(match.killEvents) do
            if kill.headshot then
                headshots = headshots + 1
            end
        end

        local headshotRate = headshots / #match.killEvents
        if headshotRate > 0.8 then -- More than 80% headshots
            suspiciousScore = suspiciousScore + 30
        end
    end

    -- Report if suspicious
    if suspiciousScore >= 30 then
        ReportViolation(identifier, 'PERFORMANCE_ANOMALY', {
            suspiciousScore = suspiciousScore,
            matchDuration = duration,
            killCount = #match.killEvents,
            matchId = match.matchId
        }, 'match_analysis')
    end

    -- Clear match data
    monitoring.currentMatch = nil
end

-- =====================================================
-- AUTOMATIC ACTIONS
-- =====================================================

function ProcessAutomaticAction(identifier, violationType, severity)
    local severityConfig = IntegrityConfig.Violations[severity]
    if not severityConfig then
        return
    end

    local action = severityConfig.autoAction
    local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)

    if not playerId then
        return
    end

    if action == 'warning' and IntegrityConfig.AutoResponse.enableAutoWarning then
        SendWarningToPlayer(playerId, violationType)

    elseif action == 'temporary_restriction' then
        ApplyTemporaryRestriction(identifier, violationType)

    elseif action == 'temporary_ban' and IntegrityConfig.AutoResponse.enableAutoBan then
        ApplyTemporaryBan(identifier, violationType)

    elseif action == 'permanent_ban' and IntegrityConfig.AutoResponse.enableAutoBan then
        ApplyPermanentBan(identifier, violationType)

    elseif action == 'immediate_ban' and IntegrityConfig.AutoResponse.enableAutoBan then
        DropPlayer(playerId, string.format('TGW Anti-Cheat: %s detected', violationType))
    end

    print(string.format('^3[TGW-INTEGRITY ACTION]^7 %s - %s applied for %s', identifier, action, violationType))
end

function SendWarningToPlayer(playerId, violationType)
    TriggerClientEvent('tgw:integrity:warning', playerId, violationType)
end

function ApplyTemporaryRestriction(identifier, violationType)
    -- Restrict player from joining matches temporarily
    local restrictionEnd = os.time() + 1800 -- 30 minutes

    MySQL.execute([[
        INSERT INTO tgw_integrity_restrictions (identifier, restriction_type, reason, end_time)
        VALUES (?, 'MATCH_RESTRICTION', ?, FROM_UNIXTIME(?))
    ]], {identifier, violationType, restrictionEnd})
end

function ApplyTemporaryBan(identifier, violationType)
    local banDuration = IntegrityConfig.Escalation.tempBanDuration
    local banEnd = os.time() + banDuration

    MySQL.execute([[
        INSERT INTO tgw_integrity_bans (identifier, ban_type, reason, end_time)
        VALUES (?, 'TEMPORARY', ?, FROM_UNIXTIME(?))
    ]], {identifier, violationType, banEnd})

    local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)
    if playerId then
        DropPlayer(playerId, string.format('TGW: Temporarily banned for %s. Duration: %d hours',
            violationType, banDuration / 3600))
    end
end

function ApplyPermanentBan(identifier, violationType)
    MySQL.execute([[
        INSERT INTO tgw_integrity_bans (identifier, ban_type, reason)
        VALUES (?, 'PERMANENT', ?)
    ]], {identifier, violationType})

    local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)
    if playerId then
        DropPlayer(playerId, string.format('TGW: Permanently banned for %s', violationType))
    end
end

-- =====================================================
-- PLAYER REPORTING SYSTEM
-- =====================================================

function ProcessPlayerReport(reporterIdentifier, targetPlayer, reason, evidence)
    if not IntegrityConfig.Reporting.enablePlayerReports then
        return false
    end

    -- Validate report cooldown
    if not ValidateReportCooldown(reporterIdentifier) then
        local playerId = TGWCore.GetPlayerIdByIdentifier(reporterIdentifier)
        if playerId then
            TriggerClientEvent('tgw:integrity:reportResult', playerId, false, 'Report cooldown active')
        end
        return false
    end

    -- Record report
    MySQL.execute([[
        INSERT INTO tgw_integrity_reports (reporter_identifier, target_identifier, reason, evidence)
        VALUES (?, ?, ?, ?)
    ]], {reporterIdentifier, targetPlayer, reason, evidence})

    -- Update trust scores
    UpdateTrustScore(targetPlayer, IntegrityConfig.TrustModifiers.communityReport, 'player_report')

    -- Notify admins
    NotifyAdminsOfReport(reporterIdentifier, targetPlayer, reason, evidence)

    print(string.format('^3[TGW-INTEGRITY REPORT]^7 %s reported %s for %s', reporterIdentifier, targetPlayer, reason))

    return true
end

function ValidateReportCooldown(identifier)
    -- This would check if player can make another report
    return true -- Simplified for now
end

-- =====================================================
-- ADMIN NOTIFICATIONS
-- =====================================================

function NotifyAdminsOfViolation(identifier, violationType, severity, evidence)
    if not IntegrityConfig.Notifications.notifyAdminsOnViolation then
        return
    end

    local message = string.format('TGW Anti-Cheat: %s detected for player %s (Severity: %s)',
        violationType, identifier, severity)

    -- Notify online admins
    local adminPlayers = TGWCore.GetOnlineAdmins()
    for _, adminId in ipairs(adminPlayers) do
        TriggerClientEvent('tgw:integrity:adminNotification', adminId, {
            type = 'violation',
            player = identifier,
            violation = violationType,
            severity = severity,
            evidence = evidence,
            timestamp = os.time()
        })
    end

    print(string.format('^1[TGW-INTEGRITY ADMIN]^7 %s', message))
end

function NotifyAdminsOfReport(reporterIdentifier, targetPlayer, reason, evidence)
    local message = string.format('Player Report: %s reported %s for %s', reporterIdentifier, targetPlayer, reason)

    local adminPlayers = TGWCore.GetOnlineAdmins()
    for _, adminId in ipairs(adminPlayers) do
        TriggerClientEvent('tgw:integrity:adminNotification', adminId, {
            type = 'report',
            reporter = reporterIdentifier,
            target = targetPlayer,
            reason = reason,
            evidence = evidence,
            timestamp = os.time()
        })
    end

    print(string.format('^3[TGW-INTEGRITY REPORT]^7 %s', message))
end

function NotifyTrustStatusChange(identifier, oldStatus, newStatus, reason)
    if not IntegrityConfig.Notifications.notifyOnTrustScoreChange then
        return
    end

    print(string.format('^2[TGW-INTEGRITY STATUS]^7 %s trust status changed: %s -> %s (%s)',
        identifier, oldStatus, newStatus, reason))
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function ValidateWeaponAuthorization(identifier, weaponHash)
    -- Check if player is authorized to have this weapon
    local loadoutExport = exports['tgw_loadout']
    if loadoutExport then
        local loadout = loadoutExport:GetPlayerLoadout(identifier)
        if loadout then
            return loadout.weapons.primary == weaponHash or loadout.weapons.secondary == weaponHash
        end
    end
    return false
end

function GetPlayerCurrentLoadout(identifier)
    local loadoutExport = exports['tgw_loadout']
    if loadoutExport then
        return loadoutExport:GetPlayerLoadout(identifier)
    end
    return nil
end

function StartPlayerMonitoringThreads(identifier)
    -- Start position monitoring
    CreateThread(function()
        while ActiveMonitoring[identifier] do
            Wait(IntegrityConfig.Detection.movement.checkInterval)

            local playerId = ActiveMonitoring[identifier].playerId
            if playerId then
                TriggerClientEvent('tgw:integrity:requestData', playerId)
            end
        end
    end)
end

function StartMonitoringThreads()
    -- Main monitoring thread
    CreateThread(function()
        while true do
            Wait(IntegrityConfig.Performance.processingInterval)
            ProcessDetectionQueue()
        end
    end)

    -- Cleanup thread
    CreateThread(function()
        while true do
            Wait(IntegrityConfig.Performance.memoryCleanupInterval)
            CleanupOldData()
        end
    end)
end

function ProcessDetectionQueue()
    -- Process queued detections
    local processed = 0
    while #DetectionQueue > 0 and processed < IntegrityConfig.Performance.checkBatchSize do
        local detection = table.remove(DetectionQueue, 1)
        -- Process detection
        processed = processed + 1
    end
end

function CleanupOldData()
    local currentTime = os.time()
    local cleanupThreshold = 3600 -- 1 hour

    for identifier, monitoring in pairs(ActiveMonitoring) do
        if currentTime - monitoring.lastUpdate > cleanupThreshold then
            CleanupPlayerMonitoring(identifier)
        end
    end
end

function CleanupPlayerMonitoring(identifier)
    ActiveMonitoring[identifier] = nil
    print(string.format('^3[TGW-INTEGRITY]^7 Cleaned up monitoring for %s', identifier))
end

function QueueTrustScoreUpdate(identifier)
    -- Queue for batch database update
    CreateThread(function()
        Wait(5000) -- Wait 5 seconds before saving
        SavePlayerTrustScore(identifier)
    end)
end

function StartPerformanceTracking()
    CreateThread(function()
        while true do
            Wait(300000) -- Every 5 minutes

            print(string.format('^2[TGW-INTEGRITY STATS]^7 Checks: %d, Violations: %d, False Positives: %d, Monitoring: %d',
                IntegrityStats.totalChecks,
                IntegrityStats.violationsDetected,
                IntegrityStats.falsePositives,
                GetActiveMonitoringCount()
            ))
        end
    end)
end

function GetActiveMonitoringCount()
    local count = 0
    for _ in pairs(ActiveMonitoring) do
        count = count + 1
    end
    return count
end

function InitializeIntegritySystem()
    -- Load trust scores for active players
    local players = ESX.GetPlayers()
    for _, playerId in ipairs(players) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            LoadPlayerTrustScore(xPlayer.identifier)
            InitializePlayerMonitoring(xPlayer.identifier, playerId)
        end
    end
end

function ProcessAdminAction(action, targetIdentifier, reason, adminId)
    if action == 'whitelist' then
        -- Add player to whitelist
        MySQL.execute('INSERT INTO tgw_integrity_whitelist (identifier, reason, admin_id) VALUES (?, ?, ?)',
            {targetIdentifier, reason, adminId})
    elseif action == 'clear_violations' then
        -- Clear violation history
        ViolationHistory[targetIdentifier] = {}
        MySQL.execute('DELETE FROM tgw_integrity_violations WHERE identifier = ?', {targetIdentifier})
    elseif action == 'reset_trust' then
        -- Reset trust score
        if PlayerTrustScores[targetIdentifier] then
            PlayerTrustScores[targetIdentifier].score = IntegrityConfig.TrustScore.defaultScore
            UpdateTrustScore(targetIdentifier, 0, 'admin_reset')
        end
    end

    print(string.format('^2[TGW-INTEGRITY ADMIN]^7 Admin %d performed %s on %s: %s', adminId, action, targetIdentifier, reason))
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('ReportSuspiciousActivity', ReportViolation)

exports('ValidatePlayerAction', function(identifier, action, data)
    -- Generic validation function
    return true -- Simplified
end)

exports('GetPlayerTrustScore', function(identifier)
    return PlayerTrustScores[identifier] and PlayerTrustScores[identifier].score or IntegrityConfig.TrustScore.defaultScore
end)

exports('CheckPlayerIntegrity', function(identifier)
    local trustData = PlayerTrustScores[identifier]
    if trustData then
        return {
            score = trustData.score,
            status = trustData.status,
            violations = trustData.totalViolations,
            lastViolation = trustData.lastViolation
        }
    end
    return nil
end)

exports('FlagPlayer', function(identifier, reason, evidence)
    return ReportViolation(identifier, 'STAT_ANOMALY', evidence, 'external_flag')
end)

exports('GetViolationHistory', function(identifier)
    return ViolationHistory[identifier] or {}
end)

-- =====================================================
-- ADMIN COMMANDS
-- =====================================================

RegisterCommand('tgw_integrity_stats', function(source, args, rawCommand)
    if source == 0 then -- Console only
        print('^2[TGW-INTEGRITY STATS]^7')
        print(string.format('  Total Checks: %d', IntegrityStats.totalChecks))
        print(string.format('  Violations Detected: %d', IntegrityStats.violationsDetected))
        print(string.format('  False Positives: %d', IntegrityStats.falsePositives))
        print(string.format('  Active Monitoring: %d', GetActiveMonitoringCount()))
        print(string.format('  Trusted Players: %d', IntegrityStats.trustedPlayers))
        print(string.format('  Banned Players: %d', IntegrityStats.bannedPlayers))
    end
end, true)

RegisterCommand('tgw_integrity_player', function(source, args, rawCommand)
    if source == 0 and args[1] then -- Console only
        local identifier = args[1]
        local trustData = PlayerTrustScores[identifier]
        local violations = ViolationHistory[identifier] or {}

        if trustData then
            print(string.format('^2[TGW-INTEGRITY PLAYER]^7 %s:', identifier))
            print(string.format('  Trust Score: %d (%s)', trustData.score, trustData.status))
            print(string.format('  Total Violations: %d', #violations))
            print(string.format('  Last Violation: %s', trustData.lastViolation and os.date('%Y-%m-%d %H:%M:%S', trustData.lastViolation) or 'None'))

            if #violations > 0 then
                print('  Recent Violations:')
                for i = math.max(1, #violations - 5), #violations do
                    local v = violations[i]
                    print(string.format('    %s: %s (%s)', os.date('%m/%d %H:%M', v.timestamp), v.type, v.severity))
                end
            end
        else
            print(string.format('^1[TGW-INTEGRITY]^7 No data found for: %s', identifier))
        end
    end
end, true)

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Save all trust scores
        for identifier, _ in pairs(PlayerTrustScores) do
            SavePlayerTrustScore(identifier)
        end

        print('^2[TGW-INTEGRITY]^7 Integrity monitoring stopped, all data saved')
    end
end)