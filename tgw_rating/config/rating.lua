RatingConfig = {}

-- =====================================================
-- ELO RATING SYSTEM CONFIGURATION
-- =====================================================

-- Base ELO rating settings
RatingConfig.DefaultRating = 1200        -- Starting rating for new players
RatingConfig.MinRating = 100             -- Minimum possible rating
RatingConfig.MaxRating = 3000            -- Maximum possible rating
RatingConfig.ProvisionalGames = 10       -- Games before rating stabilizes

-- K-factor (rating change multiplier) based on conditions
RatingConfig.KFactors = {
    provisional = 40,                    -- High K-factor for new players
    standard = 20,                       -- Standard K-factor
    high_rated = 15,                     -- Lower K-factor for high-rated players
    master = 10                          -- Very low K-factor for masters
}

-- Rating thresholds for different K-factors
RatingConfig.KFactorThresholds = {
    high_rated = 1800,                   -- High rated player threshold
    master = 2200                        -- Master level threshold
}

-- =====================================================
-- COMPETITIVE RANKING SYSTEM
-- =====================================================

-- Competitive ranks based on rating
RatingConfig.CompetitiveRanks = {
    {rating = 100, name = 'Iron', tier = 'I', color = {139, 69, 19}, icon = '🥉'},
    {rating = 200, name = 'Iron', tier = 'II', color = {139, 69, 19}, icon = '🥉'},
    {rating = 300, name = 'Iron', tier = 'III', color = {139, 69, 19}, icon = '🥉'},

    {rating = 400, name = 'Bronze', tier = 'I', color = {184, 134, 11}, icon = '🥉'},
    {rating = 500, name = 'Bronze', tier = 'II', color = {184, 134, 11}, icon = '🥉'},
    {rating = 600, name = 'Bronze', tier = 'III', color = {184, 134, 11}, icon = '🥉'},

    {rating = 700, name = 'Silver', tier = 'I', color = {192, 192, 192}, icon = '🥈'},
    {rating = 850, name = 'Silver', tier = 'II', color = {192, 192, 192}, icon = '🥈'},
    {rating = 1000, name = 'Silver', tier = 'III', color = {192, 192, 192}, icon = '🥈'},

    {rating = 1150, name = 'Gold', tier = 'I', color = {255, 215, 0}, icon = '🥇'},
    {rating = 1300, name = 'Gold', tier = 'II', color = {255, 215, 0}, icon = '🥇'},
    {rating = 1450, name = 'Gold', tier = 'III', color = {255, 215, 0}, icon = '🥇'},

    {rating = 1600, name = 'Platinum', tier = 'I', color = {229, 228, 226}, icon = '💎'},
    {rating = 1750, name = 'Platinum', tier = 'II', color = {229, 228, 226}, icon = '💎'},
    {rating = 1900, name = 'Platinum', tier = 'III', color = {229, 228, 226}, icon = '💎'},

    {rating = 2050, name = 'Diamond', tier = 'I', color = {0, 191, 255}, icon = '💠'},
    {rating = 2200, name = 'Diamond', tier = 'II', color = {0, 191, 255}, icon = '💠'},
    {rating = 2350, name = 'Diamond', tier = 'III', color = {0, 191, 255}, icon = '💠'},

    {rating = 2500, name = 'Master', tier = '', color = {138, 43, 226}, icon = '👑'},
    {rating = 2750, name = 'Grandmaster', tier = '', color = {255, 20, 147}, icon = '🔥'},
    {rating = 3000, name = 'Champion', tier = '', color = {255, 215, 0}, icon = '🏆'}
}

-- =====================================================
-- RATING CALCULATION PARAMETERS
-- =====================================================

-- Expected score calculation settings
RatingConfig.ExpectedScore = {
    ratingDifference400 = 10,            -- Rating difference for 10:1 odds
    logisticBase = 10,                   -- Base for logistic function
    scalingFactor = 400                  -- ELO scaling factor
}

-- Rating adjustment modifiers
RatingConfig.Modifiers = {
    roundType = {
        rifle = 1.0,                     -- Standard modifier for rifle rounds
        pistol = 1.1,                    -- Slightly higher for pistol (harder)
        sniper = 0.95                    -- Slightly lower for sniper (easier for skilled)
    },

    matchConditions = {
        forfeit_win = 0.5,               -- Reduced rating for forfeit wins
        forfeit_loss = 0.7,              -- Reduced rating loss for forfeits
        sudden_death = 1.2,              -- Bonus for sudden death wins
        quick_win = 1.1,                 -- Small bonus for quick wins
        comeback = 1.3                   -- Bonus for comeback wins (low HP)
    },

    streakBonus = {
        enabled = true,
        maxBonus = 0.2,                  -- Maximum 20% bonus
        streakThreshold = 3,             -- Start bonus after 3 wins
        bonusPerWin = 0.05               -- 5% bonus per additional win
    },

    uncertaintyPenalty = {
        enabled = true,
        inactivityDays = 30,             -- Days before uncertainty increases
        maxPenalty = 0.3,                -- Maximum 30% rating change increase
        penaltyRate = 0.01               -- 1% penalty per day inactive
    }
}

-- =====================================================
-- RATING DECAY AND MAINTENANCE
-- =====================================================

-- Rating decay for inactive players
RatingConfig.Decay = {
    enabled = true,
    decayThreshold = 1400,               -- Only decay ratings above this
    inactivityDays = 14,                 -- Days before decay starts
    decayRate = 5,                       -- Rating points lost per day
    maxDecay = 200,                      -- Maximum total decay
    decayInterval = 86400                -- Check interval (24 hours)
}

-- Rating recalibration settings
RatingConfig.Recalibration = {
    enabled = true,
    seasonsEnabled = true,
    seasonLength = 90,                   -- Days per season
    softReset = true,                    -- Soft reset vs hard reset
    resetFormula = {
        factor = 0.8,                    -- Keep 80% of rating
        baseline = 1200,                 -- Pull toward baseline
        pullStrength = 0.2               -- 20% pull toward baseline
    }
}

-- =====================================================
-- RATING VALIDATION AND ANTI-CHEAT
-- =====================================================

-- Rating change validation
RatingConfig.Validation = {
    maxChangePerGame = 100,              -- Maximum rating change per game
    maxGamesPerHour = 20,                -- Maximum games per hour
    suspiciousChangeThreshold = 200,     -- Flag changes above this
    validateOpponentRating = true,       -- Validate opponent rating exists
    logSuspiciousActivity = true         -- Log suspicious rating changes
}

-- Anti-boost protection
RatingConfig.AntiBoost = {
    enabled = true,
    sameOpponentLimit = 5,               -- Max games vs same opponent per day
    ratingDifferenceThreshold = 500,     -- Flag if rating difference too high
    newAccountProtection = true,         -- Extra checks for new accounts
    ipMatchingEnabled = false            -- Check for IP address matching
}

-- =====================================================
-- PLACEMENT MATCHES SYSTEM
-- =====================================================

-- Initial rating determination
RatingConfig.Placement = {
    placementGames = 10,                 -- Number of placement games
    startingRating = 1200,               -- Starting rating for placements
    ratingRange = 600,                   -- Possible rating range after placements
    uncertaintyFactor = 2.0,             -- Higher K-factor during placements
    minRatingAfterPlacement = 400,       -- Minimum rating after placements
    maxRatingAfterPlacement = 1800       -- Maximum rating after placements
}

-- =====================================================
-- RATING HISTORY AND STATISTICS
-- =====================================================

-- Rating tracking settings
RatingConfig.History = {
    trackHistory = true,                 -- Track rating changes
    historyLimit = 100,                  -- Keep last 100 rating changes
    trackPeakRating = true,              -- Track highest rating achieved
    trackSeasonStats = true,             -- Track per-season statistics
    compressOldHistory = false           -- Compress old rating history
}

-- Statistical calculations
RatingConfig.Statistics = {
    calculateTrends = true,              -- Calculate rating trends
    trendPeriod = 20,                    -- Games to calculate trend over
    volatilityTracking = true,           -- Track rating volatility
    performanceMetrics = true,           -- Advanced performance metrics
    rankDistribution = true              -- Track rank distribution
}

-- =====================================================
-- LEADERBOARD CONFIGURATION
-- =====================================================

-- Rating leaderboards
RatingConfig.Leaderboards = {
    global = {
        name = 'Global Rating Leaderboard',
        minGames = 15,                   -- Minimum games to appear
        limit = 100,                     -- Top 100 players
        refreshInterval = 300            -- 5 minutes
    },

    seasonal = {
        name = 'Current Season Leaderboard',
        minGames = 10,                   -- Minimum games this season
        limit = 50,                      -- Top 50 players
        refreshInterval = 180            -- 3 minutes
    },

    byRank = {
        name = 'Leaderboard by Rank',
        showPercentiles = true,          -- Show rank percentiles
        limit = 25,                      -- Top 25 per rank
        refreshInterval = 600            -- 10 minutes
    }
}

-- =====================================================
-- RATING DISPLAY SETTINGS
-- =====================================================

-- How rating is shown to players
RatingConfig.Display = {
    showRatingChanges = true,            -- Show +/- rating after games
    showOpponentRating = true,           -- Show opponent's rating
    showRankProgress = true,             -- Show progress to next rank
    showPeakRating = true,               -- Show highest rating achieved
    showProvisionalStatus = true,        -- Indicate provisional rating
    animateRatingChanges = true,         -- Animate rating number changes
    ratingChangeNotifications = true,    -- Show notification for rating changes
    rankUpNotifications = true,          -- Show notification for rank ups
    rankDownNotifications = true         -- Show notification for rank downs
}

-- Rating precision and formatting
RatingConfig.Formatting = {
    decimalPlaces = 0,                   -- Show rating as whole numbers
    showSign = true,                     -- Show +/- for rating changes
    colorCodeChanges = true,             -- Color code positive/negative changes
    abbreviateHighRatings = false,       -- Abbreviate very high ratings (2.5K)
    showUncertainty = false              -- Show rating uncertainty (±50)
}

-- =====================================================
-- ADVANCED RATING FEATURES
-- =====================================================

-- Dynamic rating adjustments
RatingConfig.Advanced = {
    performanceBased = false,            -- Adjust based on individual performance
    roundSpecific = true,                -- Different calculations per round type
    teamFactors = false,                 -- Team rating considerations (future)
    contextualAdjustments = true,        -- Adjust based on match context
    adaptiveKFactor = true,              -- Dynamically adjust K-factor
    confidenceIntervals = false         -- Calculate rating confidence
}

-- Experimental features
RatingConfig.Experimental = {
    glicko2System = false,               -- Alternative to ELO (Glicko-2)
    trueskillSystem = false,             -- Microsoft TrueSkill system
    customAlgorithm = false,             -- Custom TGW rating algorithm
    machinelearningAdjustments = false, -- ML-based rating predictions
    multiFactorRating = false           -- Multiple rating categories
}

-- =====================================================
-- PERFORMANCE AND OPTIMIZATION
-- =====================================================

-- Database and caching settings
RatingConfig.Performance = {
    cacheRatings = true,                 -- Cache player ratings in memory
    cacheDuration = 1800,                -- Cache for 30 minutes
    batchUpdates = true,                 -- Batch rating updates
    batchSize = 10,                      -- Update 10 ratings at once
    updateInterval = 5000,               -- Update every 5 seconds
    compressionEnabled = false,          -- Compress rating history
    indexOptimization = true             -- Optimize database indexes
}

-- Resource usage limits
RatingConfig.Limits = {
    maxConcurrentCalculations = 50,      -- Max simultaneous calculations
    calculationTimeout = 5000,           -- Timeout for rating calculations (ms)
    maxHistoryEntries = 1000,            -- Max history entries per player
    maxLeaderboardSize = 500,            -- Max leaderboard entries
    rateLimitCalculations = true         -- Rate limit rating calculations
}