MatchmakerConfig = {}

-- =====================================================
-- MATCHMAKING CONFIGURATION
-- =====================================================

-- Processing intervals
MatchmakerConfig.TickPairingSec = 1           -- Matchmaking tick interval in seconds
MatchmakerConfig.MaxPairsPerTick = 12         -- Maximum pairs to process per tick
MatchmakerConfig.ReuseEmptyArenaFirst = true  -- Prefer reusing recently emptied arenas

-- Rating system
MatchmakerConfig.ELO = {
    startingRating = 1500,
    minRatingDiff = 50,      -- Minimum rating difference for immediate pairing
    maxRatingDiff = 400,     -- Maximum rating difference allowed
    ratingGrowthRate = 15,   -- Rating difference growth per 10 seconds waiting
    ratingGrowthInterval = 10 -- Seconds between rating difference growth
}

-- Round type matching
MatchmakerConfig.RoundTypes = {
    priority = { 'rifle', 'pistol', 'sniper' },  -- Server priority when no match
    allowMismatch = true,                         -- Allow different preferences to match
    mismatchPenalty = 30                          -- Extra seconds to wait before mismatch
}

-- Match creation
MatchmakerConfig.Match = {
    maxCreationTime = 5000,      -- Max time to create match (ms)
    teleportDelay = 1000,        -- Delay before teleporting players (ms)
    preparationTime = 4000,      -- Preparation time before round starts (ms)
    validatePlayers = true,      -- Validate players are online before matching
    requirePreferences = false   -- Require players to have set preferences
}

-- Performance settings
MatchmakerConfig.Performance = {
    enableDebugLogging = false,
    maxDatabaseQueries = 50,      -- Max DB queries per tick
    enableMatchHistory = true,    -- Store match creation history
    cleanupHistoryAfter = 86400   -- Cleanup history after 24 hours
}

-- Advanced pairing algorithms
MatchmakerConfig.Algorithm = {
    type = 'rating_proximity',    -- 'rating_proximity', 'wait_time', 'balanced'
    balanceFactors = {
        rating = 0.6,             -- Weight for rating difference
        waitTime = 0.3,           -- Weight for wait time
        preferences = 0.1         -- Weight for preference matching
    },
    antiAvoidance = {
        enabled = true,           -- Prevent players from avoiding each other
        trackRecentMatches = 10,  -- Track last N matches per player
        avoidanceWindow = 300     -- Avoid recent opponents for N seconds
    }
}

-- Fallback mechanisms
MatchmakerConfig.Fallback = {
    enableTimeoutPairing = true,     -- Pair anyone after timeout
    timeoutAfterSeconds = 180,       -- Timeout after 3 minutes
    enableBotMatching = false,       -- Enable bot opponents (future feature)
    enableCrossRegion = false        -- Enable cross-region matching (future)
}

-- Quality assurance
MatchmakerConfig.QualityControl = {
    minWaitTime = 5,              -- Minimum wait time before pairing (seconds)
    maxConsecutiveMatches = 0,    -- Max consecutive matches (0 = unlimited)
    cooldownBetweenMatches = 10,  -- Cooldown between matches (seconds)
    validateArenaAvailability = true -- Double-check arena availability
}