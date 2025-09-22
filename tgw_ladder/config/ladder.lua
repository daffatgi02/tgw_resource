LadderConfig = {}

-- =====================================================
-- LEVEL SYSTEM CONFIGURATION
-- =====================================================

-- Experience points required per level
LadderConfig.XPRequirements = {
    [1] = 0,        -- Level 1 starts at 0 XP
    [2] = 100,      -- Level 2 requires 100 XP
    [3] = 250,      -- Level 3 requires 250 XP
    [4] = 450,      -- Level 4 requires 450 XP
    [5] = 700,      -- Level 5 requires 700 XP
    [6] = 1000,     -- Level 6 requires 1000 XP
    [7] = 1350,     -- Level 7 requires 1350 XP
    [8] = 1750,     -- Level 8 requires 1750 XP
    [9] = 2200,     -- Level 9 requires 2200 XP
    [10] = 2700,    -- Level 10 requires 2700 XP
    -- Continue pattern: each level requires +50 more XP than the gap before
}

-- Maximum level achievable
LadderConfig.MaxLevel = 100

-- XP progression formula for levels beyond configured
LadderConfig.XPFormula = {
    baseXP = 100,           -- Starting XP requirement
    multiplier = 1.15,      -- Exponential growth factor
    linearBonus = 50        -- Linear bonus per level
}

-- =====================================================
-- XP REWARDS CONFIGURATION
-- =====================================================

-- XP rewards for different achievements
LadderConfig.XPRewards = {
    -- Match results
    win = 50,               -- Win a match
    lose = 15,              -- Lose a match
    draw = 25,              -- Draw a match
    forfeit_win = 30,       -- Win by forfeit (less XP)

    -- Round-specific bonuses
    quick_win = 10,         -- Win round in under 30 seconds
    comeback_win = 20,      -- Win from low health (<25%)
    sudden_death_win = 15,  -- Win in sudden death
    headshot_kill = 5,      -- Kill with headshot

    -- Streak bonuses
    win_streak_2 = 5,       -- 2 wins in a row
    win_streak_5 = 15,      -- 5 wins in a row
    win_streak_10 = 30,     -- 10 wins in a row

    -- Daily/Weekly bonuses
    first_win_daily = 25,   -- First win of the day
    daily_games_5 = 20,     -- Play 5 games in a day
    daily_games_10 = 40,    -- Play 10 games in a day

    -- Special achievements
    perfect_round = 25,     -- Win without taking damage
    clutch_kill = 15,       -- Kill opponent with <10% health
    long_range_kill = 10,   -- Sniper kill from >50m
    close_range_kill = 8,   -- Pistol kill from <5m

    -- Participation rewards
    match_completed = 5,    -- Complete a match (win or lose)
    rounds_played = 2,      -- Per round played

    -- Rating-based bonuses
    beat_higher_rated = 20, -- Beat someone 100+ rating higher
    upset_victory = 35      -- Beat someone 200+ rating higher
}

-- XP multipliers based on conditions
LadderConfig.XPMultipliers = {
    weekend = 1.2,          -- 20% bonus on weekends
    event = 1.5,            -- 50% bonus during events
    new_player = 2.0,       -- 100% bonus for first 10 levels
    comeback = 1.3,         -- 30% bonus after 3+ losses
    underdog = 1.25         -- 25% bonus when fighting higher rated player
}

-- =====================================================
-- RANK SYSTEM
-- =====================================================

-- Rank tiers based on level
LadderConfig.Ranks = {
    {level = 1, name = 'Recruit', color = {150, 150, 150}, icon = '🥉'},
    {level = 5, name = 'Private', color = {139, 69, 19}, icon = '🏅'},
    {level = 10, name = 'Corporal', color = {184, 134, 11}, icon = '🎖️'},
    {level = 15, name = 'Sergeant', color = {255, 215, 0}, icon = '⭐'},
    {level = 20, name = 'Lieutenant', color = {192, 192, 192}, icon = '🌟'},
    {level = 30, name = 'Captain', color = {255, 140, 0}, icon = '💫'},
    {level = 40, name = 'Major', color = {220, 20, 60}, icon = '⚡'},
    {level = 50, name = 'Colonel', color = {138, 43, 226}, icon = '👑'},
    {level = 65, name = 'General', color = {255, 20, 147}, icon = '💎'},
    {level = 80, name = 'Commander', color = {0, 191, 255}, icon = '🔥'},
    {level = 100, name = 'Legend', color = {255, 215, 0}, icon = '🏆'}
}

-- =====================================================
-- LEADERBOARD CONFIGURATION
-- =====================================================

-- Leaderboard categories
LadderConfig.Leaderboards = {
    level = {
        name = 'Level Leaderboard',
        description = 'Highest level players',
        sortBy = 'level',
        sortOrder = 'DESC',
        limit = 100
    },
    rating = {
        name = 'Rating Leaderboard',
        description = 'Highest rated players',
        sortBy = 'rating',
        sortOrder = 'DESC',
        limit = 100
    },
    wins = {
        name = 'Wins Leaderboard',
        description = 'Most wins',
        sortBy = 'wins',
        sortOrder = 'DESC',
        limit = 50
    },
    winrate = {
        name = 'Win Rate Leaderboard',
        description = 'Highest win percentage (min 20 games)',
        sortBy = 'win_rate',
        sortOrder = 'DESC',
        limit = 50,
        minGames = 20
    },
    streak = {
        name = 'Win Streak Leaderboard',
        description = 'Current win streaks',
        sortBy = 'current_streak',
        sortOrder = 'DESC',
        limit = 25
    }
}

-- Leaderboard refresh intervals
LadderConfig.LeaderboardRefresh = {
    level = 300,        -- 5 minutes
    rating = 300,       -- 5 minutes
    wins = 600,         -- 10 minutes
    winrate = 900,      -- 15 minutes
    streak = 180        -- 3 minutes
}

-- =====================================================
-- PRESTIGE SYSTEM
-- =====================================================

-- Prestige levels (reset level but keep prestige)
LadderConfig.Prestige = {
    enabled = true,
    maxLevel = 100,         -- Max level before prestige
    prestigeBonusXP = 0.1,  -- 10% XP bonus per prestige
    maxPrestige = 10,       -- Maximum prestige levels
    prestigeRewards = {
        [1] = {item = 'prestige_badge_1', title = 'Veteran'},
        [2] = {item = 'prestige_badge_2', title = 'Elite'},
        [3] = {item = 'prestige_badge_3', title = 'Master'},
        [5] = {item = 'prestige_badge_5', title = 'Grandmaster'},
        [10] = {item = 'prestige_badge_max', title = 'Legendary'}
    }
}

-- =====================================================
-- LEVEL REWARDS SYSTEM
-- =====================================================

-- Rewards given when reaching certain levels
LadderConfig.LevelRewards = {
    [5] = {
        xp = 100,
        title = 'Rising Star',
        announcement = true
    },
    [10] = {
        xp = 200,
        title = 'Skilled Fighter',
        announcement = true
    },
    [15] = {
        xp = 300,
        title = 'Veteran Warrior',
        announcement = true
    },
    [25] = {
        xp = 500,
        title = 'Elite Combatant',
        announcement = true,
        specialReward = 'weapon_skin_bronze'
    },
    [50] = {
        xp = 1000,
        title = 'Champion',
        announcement = true,
        specialReward = 'weapon_skin_silver'
    },
    [75] = {
        xp = 1500,
        title = 'Master of Arms',
        announcement = true,
        specialReward = 'weapon_skin_gold'
    },
    [100] = {
        xp = 2500,
        title = 'Legend',
        announcement = true,
        specialReward = 'weapon_skin_legendary'
    }
}

-- =====================================================
-- STATISTICS TRACKING
-- =====================================================

-- Stats to track for ladder progression
LadderConfig.TrackedStats = {
    -- Match statistics
    'total_matches',
    'wins',
    'losses',
    'draws',
    'forfeit_wins',
    'forfeit_losses',

    -- Round statistics
    'total_rounds',
    'rounds_won',
    'rounds_lost',
    'sudden_death_wins',
    'quick_wins',

    -- Kill statistics
    'total_kills',
    'headshot_kills',
    'long_range_kills',
    'close_range_kills',
    'clutch_kills',

    -- Streak statistics
    'current_streak',
    'best_streak',
    'current_loss_streak',
    'worst_loss_streak',

    -- Time statistics
    'total_playtime',
    'average_match_time',
    'fastest_win',
    'longest_match',

    -- Special achievements
    'perfect_rounds',
    'comeback_wins',
    'upset_victories'
}

-- =====================================================
-- ACHIEVEMENT SYSTEM
-- =====================================================

-- Achievements that give XP and recognition
LadderConfig.Achievements = {
    first_win = {
        name = 'First Blood',
        description = 'Win your first match',
        xp = 100,
        oneTime = true,
        condition = function(stats) return stats.wins >= 1 end
    },

    win_10 = {
        name = 'Rising Fighter',
        description = 'Win 10 matches',
        xp = 200,
        oneTime = true,
        condition = function(stats) return stats.wins >= 10 end
    },

    win_50 = {
        name = 'Veteran Fighter',
        description = 'Win 50 matches',
        xp = 500,
        oneTime = true,
        condition = function(stats) return stats.wins >= 50 end
    },

    win_100 = {
        name = 'Centurion',
        description = 'Win 100 matches',
        xp = 1000,
        oneTime = true,
        condition = function(stats) return stats.wins >= 100 end
    },

    streak_5 = {
        name = 'Hot Streak',
        description = 'Win 5 matches in a row',
        xp = 150,
        oneTime = false,
        condition = function(stats) return stats.current_streak >= 5 end
    },

    streak_10 = {
        name = 'Unstoppable',
        description = 'Win 10 matches in a row',
        xp = 300,
        oneTime = false,
        condition = function(stats) return stats.current_streak >= 10 end
    },

    headshot_master = {
        name = 'Headshot Master',
        description = 'Score 100 headshot kills',
        xp = 300,
        oneTime = true,
        condition = function(stats) return stats.headshot_kills >= 100 end
    },

    sniper_elite = {
        name = 'Sniper Elite',
        description = 'Score 50 long range kills',
        xp = 250,
        oneTime = true,
        condition = function(stats) return stats.long_range_kills >= 50 end
    }
}

-- =====================================================
-- SEASONAL LADDER
-- =====================================================

-- Seasonal competitions
LadderConfig.Seasons = {
    enabled = true,
    seasonLength = 30,      -- 30 days per season
    seasonalBonusXP = 0.2,  -- 20% bonus XP during seasons
    seasonRewards = {
        top1 = {item = 'season_crown', title = 'Season Champion'},
        top3 = {item = 'season_medal', title = 'Season Finalist'},
        top10 = {item = 'season_badge', title = 'Season Elite'},
        participation = {item = 'season_token', title = 'Season Participant'}
    }
}

-- =====================================================
-- PERFORMANCE SETTINGS
-- =====================================================

-- Update and calculation intervals
LadderConfig.Performance = {
    xpUpdateInterval = 1000,        -- XP update frequency (ms)
    leaderboardCacheTime = 300,     -- Cache leaderboards for 5 minutes
    statUpdateBatch = 10,           -- Batch stat updates
    achievementCheckInterval = 5000, -- Check achievements every 5 seconds
    enableXPLogging = true,         -- Log XP changes
    enableStatLogging = false       -- Log stat changes
}

-- =====================================================
-- UI DISPLAY SETTINGS
-- =====================================================

-- How ladder info is displayed
LadderConfig.Display = {
    showLevelInHUD = true,          -- Show level in main HUD
    showXPGains = true,             -- Show XP gain notifications
    showLevelUps = true,            -- Show level up notifications
    showRankPromotions = true,      -- Show rank promotion notifications
    showAchievements = true,        -- Show achievement notifications
    animateXPGains = true,          -- Animate XP gain display
    xpGainDuration = 3000,          -- XP gain notification duration
    levelUpDuration = 5000          -- Level up notification duration
}

-- =====================================================
-- ANTI-CHEAT SETTINGS
-- =====================================================

-- XP gain validation
LadderConfig.AntiCheat = {
    maxXPPerMatch = 500,            -- Maximum XP per single match
    maxXPPerHour = 2000,            -- Maximum XP per hour
    validateXPSources = true,       -- Validate XP source events
    logSuspiciousActivity = true,   -- Log suspicious XP gains
    autoFlagThreshold = 1000,       -- Auto-flag if XP gain exceeds this
    resetOnCheatDetection = false   -- Reset ladder progress on cheat detection
}