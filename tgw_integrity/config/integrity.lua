IntegrityConfig = {}

-- =====================================================
-- ANTI-CHEAT DETECTION SETTINGS
-- =====================================================

-- Detection categories and their sensitivities
IntegrityConfig.Detection = {
    -- Movement and positioning checks
    movement = {
        enabled = true,
        maxSpeed = 15.0,                    -- Maximum player speed (m/s)
        teleportDistanceThreshold = 50.0,   -- Distance to trigger teleport detection
        noClipDetectionEnabled = true,      -- Detect no-clip/fly cheats
        speedHackDetectionEnabled = true,   -- Detect speed modifications
        checkInterval = 500                 -- Check every 500ms
    },

    -- Weapon and damage checks
    weapon = {
        enabled = true,
        unauthorizedWeaponCheck = true,     -- Check for unauthorized weapons
        infiniteAmmoDetection = true,       -- Detect infinite ammo
        damageMultiplierThreshold = 2.0,    -- Flag damage above this multiplier
        rapidFireThreshold = 0.05,          -- Minimum time between shots (seconds)
        weaponRangeValidation = true        -- Validate weapon range limits
    },

    -- Health and invincibility checks
    health = {
        enabled = true,
        godModeDetection = true,            -- Detect god mode/invincibility
        healthRegenerationCheck = true,     -- Check for abnormal health regen
        maxHealthThreshold = 200,           -- Maximum allowed health
        instantHealDetection = true,        -- Detect instant healing
        damageImmunityCheck = true          -- Check for damage immunity
    },

    -- Resource and exploit checks
    resource = {
        enabled = true,
        resourceInjectionDetection = true,  -- Detect injected resources
        eventSpamThreshold = 50,            -- Max events per second
        menuDetection = true,               -- Detect mod menus
        executeCommandDetection = true,     -- Detect command execution exploits
        networkEventValidation = true      -- Validate network events
    },

    -- Statistical anomaly detection
    statistical = {
        enabled = true,
        headshotRateThreshold = 0.8,        -- Flag if headshot rate above 80%
        winRateThreshold = 0.95,            -- Flag if win rate above 95%
        kdrAnomalyDetection = true,         -- Detect abnormal K/D ratios
        performanceConsistencyCheck = true, -- Check for unrealistic consistency
        ratingGainAnomalyDetection = true   -- Detect suspicious rating gains
    }
}

-- =====================================================
-- VIOLATION SEVERITY LEVELS
-- =====================================================

-- Violation categories and their severity
IntegrityConfig.Violations = {
    MINOR = {
        level = 1,
        description = 'Minor violation',
        trustScoreImpact = -5,
        autoAction = 'warning',
        reportToAdmins = false
    },

    MODERATE = {
        level = 2,
        description = 'Moderate violation',
        trustScoreImpact = -15,
        autoAction = 'temporary_restriction',
        reportToAdmins = true
    },

    MAJOR = {
        level = 3,
        description = 'Major violation',
        trustScoreImpact = -30,
        autoAction = 'temporary_ban',
        reportToAdmins = true
    },

    SEVERE = {
        level = 4,
        description = 'Severe violation',
        trustScoreImpact = -50,
        autoAction = 'permanent_ban',
        reportToAdmins = true
    },

    CRITICAL = {
        level = 5,
        description = 'Critical violation',
        trustScoreImpact = -100,
        autoAction = 'immediate_ban',
        reportToAdmins = true
    }
}

-- Specific violation types
IntegrityConfig.ViolationTypes = {
    -- Movement violations
    TELEPORT = {severity = 'MAJOR', description = 'Teleportation detected'},
    SPEED_HACK = {severity = 'MAJOR', description = 'Speed modification detected'},
    NO_CLIP = {severity = 'MAJOR', description = 'No-clip detected'},
    FLY_HACK = {severity = 'MAJOR', description = 'Flying detected'},

    -- Weapon violations
    UNAUTHORIZED_WEAPON = {severity = 'MODERATE', description = 'Unauthorized weapon'},
    INFINITE_AMMO = {severity = 'MAJOR', description = 'Infinite ammo detected'},
    DAMAGE_MODIFIER = {severity = 'SEVERE', description = 'Damage modification'},
    RAPID_FIRE = {severity = 'MODERATE', description = 'Rapid fire detected'},

    -- Health violations
    GOD_MODE = {severity = 'SEVERE', description = 'God mode/invincibility'},
    HEALTH_HACK = {severity = 'MAJOR', description = 'Health modification'},
    DAMAGE_IMMUNITY = {severity = 'SEVERE', description = 'Damage immunity'},

    -- Resource violations
    RESOURCE_INJECTION = {severity = 'CRITICAL', description = 'Resource injection'},
    MOD_MENU = {severity = 'CRITICAL', description = 'Mod menu detected'},
    EVENT_SPAM = {severity = 'MODERATE', description = 'Event spamming'},
    COMMAND_EXPLOIT = {severity = 'SEVERE', description = 'Command execution exploit'},

    -- Statistical violations
    STAT_ANOMALY = {severity = 'MINOR', description = 'Statistical anomaly'},
    PERFORMANCE_ANOMALY = {severity = 'MODERATE', description = 'Performance anomaly'},
    RATING_MANIPULATION = {severity = 'MAJOR', description = 'Rating manipulation'}
}

-- =====================================================
-- TRUST SCORE SYSTEM
-- =====================================================

-- Trust score parameters
IntegrityConfig.TrustScore = {
    defaultScore = 100,                     -- Starting trust score
    minScore = 0,                           -- Minimum trust score
    maxScore = 150,                         -- Maximum trust score
    decayRate = 1,                          -- Daily decay rate for inactive players
    recoveryRate = 2,                       -- Weekly recovery rate for good behavior
    escalationThresholds = {
        80 = 'GOOD',                        -- Good standing
        60 = 'NEUTRAL',                     -- Neutral standing
        40 = 'SUSPICIOUS',                  -- Under scrutiny
        20 = 'PROBLEMATIC',                 -- Problematic player
        0 = 'BANNED'                        -- Banned
    }
}

-- Trust score modifiers
IntegrityConfig.TrustModifiers = {
    matchCompletion = 1,                    -- +1 for each completed match
    fairPlay = 2,                           -- +2 for clean matches
    communityReport = -10,                  -- -10 for player reports
    falseReport = -5,                       -- -5 for making false reports
    adminVerification = 20                  -- +20 for admin verification
}

-- =====================================================
-- MONITORING AND LOGGING
-- =====================================================

-- Monitoring settings
IntegrityConfig.Monitoring = {
    enableRealTimeMonitoring = true,        -- Real-time monitoring
    enablePostGameAnalysis = true,          -- Post-match analysis
    enableBehaviorTracking = true,          -- Track player behavior patterns
    enablePerformanceAnalysis = true,       -- Analyze performance metrics
    logAllEvents = false,                   -- Log all monitored events
    logSuspiciousEvents = true,             -- Log only suspicious events
    retentionPeriod = 30                    -- Days to retain logs
}

-- Data collection settings
IntegrityConfig.DataCollection = {
    collectMovementData = true,             -- Track movement patterns
    collectWeaponData = true,               -- Track weapon usage
    collectDamageData = true,               -- Track damage dealt/received
    collectStatisticalData = true,          -- Track performance statistics
    collectBehaviorData = true,             -- Track behavior patterns
    anonymizeData = true,                   -- Anonymize collected data
    dataRetentionDays = 90                  -- Data retention period
}

-- =====================================================
-- AUTOMATED RESPONSES
-- =====================================================

-- Automatic response settings
IntegrityConfig.AutoResponse = {
    enableAutoKick = true,                  -- Auto-kick for violations
    enableAutoBan = false,                  -- Auto-ban for severe violations
    enableAutoWarning = true,               -- Auto-warn for minor violations
    enableMatchCancellation = true,         -- Cancel matches on detection
    warningCooldown = 300,                  -- 5 minutes between warnings
    kickCooldown = 600,                     -- 10 minutes between kicks
    escalationEnabled = true                -- Escalate repeated violations
}

-- Escalation rules
IntegrityConfig.Escalation = {
    warningLimit = 3,                       -- Warnings before kick
    kickLimit = 2,                          -- Kicks before temporary ban
    tempBanDuration = 86400,                -- 24 hours temporary ban
    tempBanLimit = 3,                       -- Temp bans before permanent ban
    violationWindow = 604800                -- 7 days violation window
}

-- =====================================================
-- WHITELIST AND EXCEPTIONS
-- =====================================================

-- Whitelisting settings
IntegrityConfig.Whitelist = {
    enableAdminWhitelist = true,            -- Admins exempt from checks
    enableVIPWhitelist = false,             -- VIP players exempt from checks
    enableDeveloperMode = true,             -- Developer exemptions
    whitelistBypass = {
        'movement',                         -- Admins can bypass movement checks
        'weapon'                            -- Admins can bypass weapon checks
    }
}

-- Exception handling
IntegrityConfig.Exceptions = {
    allowedModifications = {
                                           -- List of allowed modifications
    },
    exemptResources = {
        'tgw_core',                        -- Core resources are exempt
        'tgw_arena',                       -- Arena resources are exempt
        'es_extended'                      -- ESX is exempt
    },
    testingMode = false                    -- Testing mode with relaxed rules
}

-- =====================================================
-- REPORTING AND NOTIFICATIONS
-- =====================================================

-- Reporting settings
IntegrityConfig.Reporting = {
    enablePlayerReports = true,            -- Players can report others
    enableAutoReporting = true,            -- Automatic violation reports
    reportCooldown = 300,                  -- 5 minutes between reports
    requireEvidence = false,               -- Require evidence for reports
    anonymousReports = true,               -- Allow anonymous reports
    maxReportsPerDay = 10                  -- Max reports per player per day
}

-- Notification settings
IntegrityConfig.Notifications = {
    notifyAdminsOnViolation = true,        -- Notify admins of violations
    notifyPlayersOnWarning = true,         -- Notify players of warnings
    notifyOnTrustScoreChange = false,      -- Notify on trust score changes
    violationNotificationThreshold = 'MODERATE', -- Minimum severity to notify
    useDiscordWebhook = false,             -- Send notifications to Discord
    discordWebhookURL = ''                 -- Discord webhook URL
}

-- =====================================================
-- PERFORMANCE AND OPTIMIZATION
-- =====================================================

-- Performance settings
IntegrityConfig.Performance = {
    maxConcurrentChecks = 32,              -- Max simultaneous checks
    checkBatchSize = 8,                    -- Batch size for checks
    processingInterval = 1000,             -- Processing interval (ms)
    memoryCleanupInterval = 300000,        -- Memory cleanup interval (5 min)
    databaseBatchWrites = true,            -- Batch database writes
    cacheResults = true,                   -- Cache check results
    cacheTimeout = 60000                   -- Cache timeout (1 minute)
}

-- Resource usage limits
IntegrityConfig.Limits = {
    maxMemoryUsage = 50,                   -- Max memory usage (MB)
    maxCPUUsage = 10,                      -- Max CPU usage (%)
    maxDatabaseConnections = 5,            -- Max database connections
    maxLogFileSize = 100,                  -- Max log file size (MB)
    maxViolationHistory = 1000             -- Max violations to store per player
}

-- =====================================================
-- ADVANCED DETECTION ALGORITHMS
-- =====================================================

-- Machine learning settings
IntegrityConfig.MachineLearning = {
    enableMLDetection = false,             -- Enable ML-based detection
    modelUpdateInterval = 86400,           -- Update models daily
    trainingDataRetention = 30,            -- Days to retain training data
    confidenceThreshold = 0.8,             -- ML confidence threshold
    falsePositiveReduction = true          -- Reduce false positives
}

-- Behavioral analysis
IntegrityConfig.BehavioralAnalysis = {
    enableBehaviorProfiling = true,        -- Profile player behavior
    trackPlaytimePatterns = true,          -- Track playtime patterns
    detectBoostingBehavior = true,         -- Detect rating boosting
    socialGraphAnalysis = false,           -- Analyze player connections
    anomalyDetectionEnabled = true         -- Detect behavioral anomalies
}

-- Pattern recognition
IntegrityConfig.PatternRecognition = {
    enablePatternMatching = true,          -- Enable pattern matching
    suspiciousPatternThreshold = 0.7,      -- Pattern match threshold
    patternHistoryLength = 100,            -- Patterns to track
    crossReferencePatterns = true,         -- Cross-reference with known patterns
    adaptivePatterns = false               -- Adapt patterns based on new data
}

-- =====================================================
-- INTEGRATION SETTINGS
-- =====================================================

-- Third-party integration
IntegrityConfig.Integration = {
    enableFiveMACIntegration = false,      -- FiveM Anti-Cheat integration
    enableCFXBanIntegration = false,       -- CFX.re ban system integration
    enableCustomACIntegration = false,     -- Custom anti-cheat integration
    shareViolationData = false,            -- Share data with other servers
    participateInGlobalDatabase = false    -- Participate in global ban database
}

-- API settings
IntegrityConfig.API = {
    enableRESTAPI = false,                 -- REST API for external tools
    apiAuthRequired = true,                -- API authentication required
    apiRateLimit = 100,                    -- API rate limit per hour
    allowExternalQueries = false,          -- Allow external violation queries
    webhookNotifications = false           -- Webhook notifications
}