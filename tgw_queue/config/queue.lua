QueueConfig = {}

-- =====================================================
-- QUEUE SYSTEM CONFIGURATION
-- =====================================================

-- Matchmaking criteria
QueueConfig.MinEloDiff = 100           -- Minimum ELO difference for pairing
QueueConfig.EloDiffGrow = 25           -- ELO difference growth per step
QueueConfig.EloDiffGrowStep = 10       -- Time in seconds per growth step
QueueConfig.MaxEloDiff = 400           -- Maximum ELO difference allowed
QueueConfig.FallbackAfterSec = 30      -- Time before fallback pairing

-- Spectate system
QueueConfig.SpectateSwitchCooldown = 2.0   -- Cooldown between spectate target switches
QueueConfig.SpectateHud = true             -- Show spectate HUD
QueueConfig.AutoSpectateWhenFull = true    -- Auto-spectate when all arenas full

-- Queue preferences
QueueConfig.MatchPreferredFirst = true     -- Try to match preferred round types first
QueueConfig.ServerRoundPriority = { 'rifle', 'pistol', 'sniper' }  -- Server fallback priority

-- Queue limits
QueueConfig.MaxQueueTime = 300         -- Maximum queue time in seconds (5 minutes)
QueueConfig.MaxQueueSize = 100         -- Maximum players in queue
QueueConfig.MinPlayersForMatch = 2     -- Minimum players needed for matchmaking

-- Spectate preferences
QueueConfig.SpectatePreferences = {
    preferSimilarRating = true,        -- Prefer spectating matches with similar rating
    preferPreferredRoundType = true,   -- Prefer spectating preferred round type
    avoidAlreadyWatched = true,        -- Avoid repeatedly spectating same match
    maxSpectateTime = 120              -- Max spectate time before switching (seconds)
}

-- Queue states
QueueConfig.States = {
    WAITING = 'waiting',       -- Waiting for a match
    SPECTATE = 'spectate',     -- Spectating while waiting
    PAIRED = 'paired'          -- Paired and moving to arena
}

-- Error messages
QueueConfig.Errors = {
    QUEUE_FULL = 'Queue is full',
    ALREADY_IN_QUEUE = 'Player already in queue',
    NOT_IN_QUEUE = 'Player not in queue',
    NO_ARENAS_AVAILABLE = 'No arenas available',
    INVALID_PREFERENCES = 'Invalid preferences',
    COOLDOWN_ACTIVE = 'Spectate cooldown active',
    NO_MATCHES_TO_SPECTATE = 'No matches available to spectate'
}

-- Success messages
QueueConfig.Messages = {
    JOINED_QUEUE = 'Joined queue successfully',
    LEFT_QUEUE = 'Left queue successfully',
    SPECTATE_STARTED = 'Started spectating',
    SPECTATE_STOPPED = 'Stopped spectating',
    SPECTATE_SWITCHED = 'Switched spectate target'
}