ChatConfig = {}

-- =====================================================
-- CHAT SYSTEM CONFIGURATION
-- =====================================================

-- Arena-specific chat settings
ChatConfig.Arena = {
    enableArenaChat = true,                 -- Enable arena-specific chat
    disableGlobalChat = true,               -- Disable global chat during matches
    enableSpectatorChat = true,             -- Allow spectators to chat
    spectatorsCanSeeArenaChat = true,       -- Spectators see arena chat
    arenaPlayersCanSeeSpectatorChat = false, -- Arena players don't see spectator chat
    chatRange = 50.0,                       -- Chat range in meters (if proximity chat enabled)
    enableProximityChat = false             -- Disable proximity chat (arena-only)
}

-- Chat channels and types
ChatConfig.Channels = {
    arena = {
        name = 'Arena',
        description = 'Chat visible to players in the same arena',
        color = {255, 255, 255},
        prefix = '[ARENA]',
        enabled = true,
        requiresArena = true
    },

    spectator = {
        name = 'Spectator',
        description = 'Chat visible to spectators watching the same arena',
        color = {150, 150, 150},
        prefix = '[SPEC]',
        enabled = true,
        requiresSpectating = true
    },

    system = {
        name = 'System',
        description = 'System messages and announcements',
        color = {255, 215, 0},
        prefix = '[SYSTEM]',
        enabled = true,
        readOnly = true
    },

    admin = {
        name = 'Admin',
        description = 'Admin-only chat channel',
        color = {255, 0, 0},
        prefix = '[ADMIN]',
        enabled = true,
        adminOnly = true
    }
}

-- =====================================================
-- MESSAGE FILTERING AND MODERATION
-- =====================================================

-- Content filtering settings
ChatConfig.Filtering = {
    enableProfanityFilter = true,           -- Filter profanity
    enableSpamFilter = true,                -- Filter spam messages
    enableLinkFilter = true,                -- Filter external links
    enableCapFilter = true,                 -- Filter excessive caps
    enableEmoticonFilter = false,           -- Filter emoticons
    enableRepeatFilter = true,              -- Filter repeated messages
    caseSensitive = false                   -- Case sensitive filtering
}

-- Profanity filter words
ChatConfig.ProfanityList = {
    -- Basic profanity list (this would be much more comprehensive in production)
    'fuck', 'shit', 'bitch', 'asshole', 'damn', 'hell',
    'stupid', 'idiot', 'moron', 'retard', 'gay', 'faggot',
    'nigger', 'nigga', 'jew', 'kike', 'spic', 'chink'
}

-- Spam detection settings
ChatConfig.SpamDetection = {
    maxMessagesPerMinute = 10,              -- Max messages per minute
    maxIdenticalMessages = 3,               -- Max identical messages
    repeatWindow = 300,                     -- Time window for repeat detection (seconds)
    capsPercentageThreshold = 70,           -- Max percentage of caps in message
    maxMessageLength = 200,                 -- Maximum message length
    minMessageLength = 1                    -- Minimum message length
}

-- Link filtering
ChatConfig.LinkFilter = {
    allowedDomains = {
        'youtube.com',
        'youtu.be',
        'twitch.tv',
        'imgur.com',
        'gyazo.com'
    },
    blockedDomains = {
        'discord.gg',
        'discordapp.com'
    },
    requireWhitelist = false                -- Only allow whitelisted domains
}

-- =====================================================
-- MODERATION AND PUNISHMENT
-- =====================================================

-- Mute and punishment settings
ChatConfig.Moderation = {
    enableAutoMute = true,                  -- Auto-mute for violations
    enableWarningSystem = true,             -- Warning system before mutes
    warningsBeforeMute = 2,                 -- Warnings before auto-mute
    defaultMuteDuration = 300,              -- Default mute duration (5 minutes)
    maxMuteDuration = 86400,                -- Maximum mute duration (24 hours)
    muteEscalation = true,                  -- Escalate mute duration for repeat offenders
    escalationMultiplier = 2,               -- Multiply mute duration by this factor
    appealCooldown = 3600                   -- Cooldown before mute appeals (1 hour)
}

-- Violation types and penalties
ChatConfig.Violations = {
    PROFANITY = {
        warningsBeforeMute = 1,
        muteDuration = 600,                 -- 10 minutes
        severity = 'MODERATE'
    },

    SPAM = {
        warningsBeforeMute = 2,
        muteDuration = 300,                 -- 5 minutes
        severity = 'MINOR'
    },

    LINKS = {
        warningsBeforeMute = 1,
        muteDuration = 900,                 -- 15 minutes
        severity = 'MODERATE'
    },

    CAPS = {
        warningsBeforeMute = 3,
        muteDuration = 180,                 -- 3 minutes
        severity = 'MINOR'
    },

    HARASSMENT = {
        warningsBeforeMute = 0,
        muteDuration = 3600,                -- 1 hour
        severity = 'SEVERE'
    },

    TOXICITY = {
        warningsBeforeMute = 1,
        muteDuration = 1800,                -- 30 minutes
        severity = 'MAJOR'
    }
}

-- =====================================================
-- CHAT HISTORY AND LOGGING
-- =====================================================

-- Message history settings
ChatConfig.History = {
    enableChatHistory = true,               -- Store chat history
    maxHistoryPerArena = 100,               -- Max messages to store per arena
    historyRetentionDays = 7,               -- Days to keep chat history
    logToDatabase = true,                   -- Log messages to database
    logSystemMessages = false,              -- Log system messages
    logPrivateMessages = true,              -- Log private messages
    anonymizeOldLogs = true                 -- Anonymize logs after retention period
}

-- Logging levels
ChatConfig.Logging = {
    logLevel = 'INFO',                      -- DEBUG, INFO, WARN, ERROR
    logToFile = false,                      -- Log to file
    logToDatabase = true,                   -- Log to database
    logToConsole = true,                    -- Log to console
    includeMetadata = true,                 -- Include message metadata
    logModerationActions = true             -- Log moderation actions
}

-- =====================================================
-- UI AND DISPLAY SETTINGS
-- =====================================================

-- Chat display configuration
ChatConfig.Display = {
    maxVisibleMessages = 10,                -- Max messages visible at once
    messageDisplayTime = 8000,              -- Time to display messages (ms)
    fadeOutTime = 1000,                     -- Fade out animation time (ms)
    showTimestamps = true,                  -- Show message timestamps
    show24HourTime = false,                 -- Use 24-hour time format
    showPlayerIDs = false,                  -- Show player IDs in chat
    showArenaNumbers = true,                -- Show arena numbers in messages
    enableChatSounds = true,                -- Play sounds for new messages
    enableAnimations = true                 -- Enable chat animations
}

-- Chat positioning and styling
ChatConfig.Style = {
    chatX = 0.025,                         -- Chat X position (0-1)
    chatY = 0.65,                          -- Chat Y position (0-1)
    chatWidth = 0.5,                       -- Chat width (0-1)
    chatHeight = 0.3,                      -- Chat height (0-1)
    backgroundColor = {0, 0, 0, 150},      -- Background color (RGBA)
    borderColor = {255, 255, 255, 100},    -- Border color (RGBA)
    borderWidth = 1,                       -- Border width
    padding = 5,                           -- Internal padding
    fontSize = 0.4,                        -- Font size
    fontFamily = 4                         -- Font family
}

-- Message colors by type
ChatConfig.MessageColors = {
    normal = {255, 255, 255},              -- Normal messages
    system = {255, 215, 0},                -- System messages
    admin = {255, 0, 0},                   -- Admin messages
    warning = {255, 165, 0},               -- Warning messages
    error = {255, 0, 0},                   -- Error messages
    success = {0, 255, 0},                 -- Success messages
    muted = {128, 128, 128}                -- Muted player messages
}

-- =====================================================
-- COMMANDS AND SHORTCUTS
-- =====================================================

-- Chat commands
ChatConfig.Commands = {
    chatCommand = 'say',                   -- Main chat command
    arenaCommand = 'a',                    -- Arena chat shortcut
    spectatorCommand = 's',                -- Spectator chat shortcut
    adminCommand = 'admin',                -- Admin chat command
    muteCommand = 'mute',                  -- Mute player command
    unmuteCommand = 'unmute',              -- Unmute player command
    clearCommand = 'clear',                -- Clear chat command
    historyCommand = 'history'             -- Chat history command
}

-- Keybinds
ChatConfig.Keybinds = {
    openChatKey = 'T',                     -- Key to open chat
    sendMessageKey = 'ENTER',              -- Key to send message
    cancelMessageKey = 'ESCAPE',           -- Key to cancel message
    scrollUpKey = 'PAGEUP',                -- Scroll up in history
    scrollDownKey = 'PAGEDOWN'             -- Scroll down in history
}

-- =====================================================
-- ANTI-SPAM AND RATE LIMITING
-- =====================================================

-- Rate limiting settings
ChatConfig.RateLimit = {
    enableRateLimit = true,                -- Enable rate limiting
    messagesPerSecond = 2,                 -- Max messages per second
    messagesPerMinute = 20,                -- Max messages per minute
    burstAllowance = 5,                    -- Burst message allowance
    cooldownPeriod = 60,                   -- Cooldown period after rate limit hit
    exemptAdmins = true,                   -- Exempt admins from rate limiting
    penaltyDuration = 300                  -- Rate limit violation penalty (5 minutes)
}

-- Flood protection
ChatConfig.FloodProtection = {
    enableFloodProtection = true,          -- Enable flood protection
    maxCharactersPerMinute = 1000,         -- Max characters per minute
    duplicateMessageThreshold = 3,         -- Max duplicate messages
    duplicateTimeWindow = 300,             -- Time window for duplicate detection
    autoMuteOnFlood = true,                -- Auto-mute flood violators
    floodMuteDuration = 600                -- Flood mute duration (10 minutes)
}

-- =====================================================
-- ARENA INTEGRATION
-- =====================================================

-- Arena-specific settings
ChatConfig.ArenaIntegration = {
    enableMatchChat = true,                -- Enable chat during matches
    enablePreMatchChat = true,             -- Enable chat before matches
    enablePostMatchChat = true,            -- Enable chat after matches
    disableChatDuringFreezePhase = false,  -- Disable chat during freeze countdown
    allowOpponentChat = true,              -- Allow chatting with opponent
    showMatchEvents = true,                -- Show match events in chat
    announceRoundStart = true,             -- Announce round start
    announceRoundEnd = true,               -- Announce round end
    announcePlayerJoin = true,             -- Announce when players join arena
    announcePlayerLeave = true             -- Announce when players leave arena
}

-- Spectator integration
ChatConfig.SpectatorIntegration = {
    enableSpectatorCommands = true,        -- Enable spectator-specific commands
    allowSpectatorSuggestions = false,     -- Allow spectators to give suggestions
    showSpectatorCount = true,             -- Show spectator count in arena
    notifyOnSpectatorJoin = false,         -- Notify when spectators join
    spectatorChatPrefix = '[VIEWER]',      -- Prefix for spectator messages
    limitSpectatorMessages = true,         -- Limit spectator message frequency
    spectatorMessageLimit = 5              -- Max spectator messages per minute
}

-- =====================================================
-- PRIVACY AND SECURITY
-- =====================================================

-- Privacy settings
ChatConfig.Privacy = {
    enablePrivateMessages = false,         -- Disable private messages (arena-only)
    logPrivateMessages = false,            -- Don't log private messages
    allowBlockingPlayers = true,           -- Allow players to block others
    enableIgnoreList = true,               -- Enable ignore functionality
    maxIgnoreListSize = 50,                -- Max players in ignore list
    enableReportSystem = true,             -- Enable message reporting
    autoDeleteReportedMessages = false     -- Don't auto-delete reported messages
}

-- Security settings
ChatConfig.Security = {
    validateMessageSender = true,          -- Validate message sender
    preventMessageSpoofing = true,         -- Prevent message spoofing
    encryptSensitiveData = false,          -- Encrypt sensitive chat data
    sanitizeUserInput = true,              -- Sanitize all user input
    preventXSSAttacks = true,              -- Prevent XSS in messages
    validateUTF8 = true                    -- Validate UTF-8 encoding
}

-- =====================================================
-- PERFORMANCE AND OPTIMIZATION
-- =====================================================

-- Performance settings
ChatConfig.Performance = {
    maxConcurrentMessages = 100,           -- Max concurrent messages in memory
    messageProcessingInterval = 100,       -- Message processing interval (ms)
    chatHistoryCleanupInterval = 3600,     -- History cleanup interval (1 hour)
    databaseBatchSize = 10,                -- Database batch write size
    enableMessageCaching = true,           -- Enable message caching
    cacheTimeout = 300,                    -- Cache timeout (5 minutes)
    compressOldMessages = false            -- Compress old messages
}

-- Resource limits
ChatConfig.Limits = {
    maxMemoryUsage = 20,                   -- Max memory usage (MB)
    maxDatabaseConnections = 3,            -- Max database connections
    maxActiveChats = 50,                   -- Max active chat sessions
    maxMessageQueueSize = 1000,            -- Max queued messages
    processingTimeout = 5000               -- Message processing timeout (ms)
}

-- =====================================================
-- INTEGRATION SETTINGS
-- =====================================================

-- Third-party integration
ChatConfig.Integration = {
    enableDiscordIntegration = false,      -- Discord webhook integration
    discordWebhookURL = '',                -- Discord webhook URL
    enableTwitchIntegration = false,       -- Twitch chat integration
    enableCustomBots = false,              -- Custom chat bots
    enableChatAPI = false,                 -- REST API for chat
    enableWebhooks = false                 -- Webhook notifications
}

-- Event integration
ChatConfig.Events = {
    broadcastMatchResults = true,          -- Broadcast match results to chat
    broadcastLevelUps = false,             -- Don't broadcast level ups
    broadcastAchievements = false,         -- Don't broadcast achievements
    broadcastRankChanges = false,          -- Don't broadcast rank changes
    broadcastSpecialEvents = true,         -- Broadcast special events
    customEventMessages = {}               -- Custom event message templates
}