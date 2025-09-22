UIConfig = {}

-- =====================================================
-- HUD SYSTEM CONFIGURATION
-- =====================================================

-- Main HUD settings
UIConfig.HUD = {
    enabled = true,                         -- Enable TGW HUD system
    hideDefaultHUD = true,                  -- Hide default GTA HUD elements
    showInMenus = false,                    -- Show HUD in menus
    showWhileDead = false,                  -- Show HUD when player is dead
    opacity = 0.9,                          -- HUD opacity (0-1)
    scale = 1.0,                            -- HUD scale multiplier
    fadeInTime = 500,                       -- Fade in animation time (ms)
    fadeOutTime = 300                       -- Fade out animation time (ms)
}

-- HUD positioning
UIConfig.Position = {
    hudX = 0.0,                            -- HUD X offset
    hudY = 0.0,                            -- HUD Y offset
    anchorPoint = 'top-left',              -- Anchor point (top-left, center, etc.)
    responsiveDesign = true,               -- Responsive design for different resolutions
    safeZone = 0.02                        -- Safe zone margin
}

-- =====================================================
-- HUD COMPONENTS CONFIGURATION
-- =====================================================

-- Health and armor display
UIConfig.Health = {
    enabled = true,
    position = {x = 0.02, y = 0.88},
    size = {width = 0.15, height = 0.02},
    showPercentage = true,
    showNumbers = true,
    animateChanges = true,
    lowHealthThreshold = 50,
    criticalHealthThreshold = 25,
    flashOnLowHealth = true,
    colors = {
        health = {0, 255, 0},
        lowHealth = {255, 255, 0},
        criticalHealth = {255, 0, 0},
        armor = {0, 100, 255}
    }
}

-- Weapon and ammo display
UIConfig.Weapon = {
    enabled = true,
    position = {x = 0.85, y = 0.88},
    showWeaponName = true,
    showAmmoCount = true,
    showReloadIndicator = true,
    showWeaponIcon = false,               -- Weapon icons not implemented
    animateReload = true,
    lowAmmoThreshold = 10,
    flashOnLowAmmo = true,
    colors = {
        normal = {255, 255, 255},
        lowAmmo = {255, 255, 0},
        noAmmo = {255, 0, 0}
    }
}

-- Round timer display
UIConfig.Timer = {
    enabled = true,
    position = {x = 0.5, y = 0.05},
    size = 'large',                        -- small, medium, large
    showBackground = true,
    showMilliseconds = false,
    warningTime = 30,                      -- Start warning at 30 seconds
    criticalTime = 10,                     -- Critical warning at 10 seconds
    flashOnCritical = true,
    colors = {
        normal = {255, 255, 255},
        warning = {255, 255, 0},
        critical = {255, 0, 0},
        background = {0, 0, 0, 150}
    }
}

-- Score and match info
UIConfig.Score = {
    enabled = true,
    position = {x = 0.02, y = 0.02},
    showPlayerNames = true,
    showRoundType = true,
    showArenaNumber = true,
    showRating = true,
    showWinStreak = true,
    maxNameLength = 15,
    colors = {
        player = {255, 255, 255},
        opponent = {255, 255, 255},
        highlight = {255, 215, 0}
    }
}

-- Minimap configuration
UIConfig.Minimap = {
    enabled = false,                       -- Disabled for arena matches
    hideInArena = true,
    position = {x = 0.02, y = 0.02},
    size = 'small',
    showPlayerDot = true,
    showOpponentDot = false               -- No opponent tracking
}

-- Crosshair customization
UIConfig.Crosshair = {
    enabled = false,                      -- Use game default
    customCrosshair = false,
    style = 'dot',                        -- dot, cross, circle
    size = 2,
    thickness = 1,
    color = {255, 255, 255, 200},
    outline = true,
    outlineColor = {0, 0, 0, 255}
}

-- =====================================================
-- NOTIFICATION SYSTEM
-- =====================================================

-- Notification settings
UIConfig.Notifications = {
    enabled = true,
    position = {x = 0.8, y = 0.3},
    maxNotifications = 5,
    defaultDuration = 4000,               -- 4 seconds
    fadeInTime = 300,
    fadeOutTime = 500,
    spacing = 0.08,                       -- Space between notifications
    width = 0.25,
    height = 0.06
}

-- Notification types and styles
UIConfig.NotificationTypes = {
    info = {
        backgroundColor = {0, 100, 255, 180},
        textColor = {255, 255, 255, 255},
        borderColor = {0, 150, 255, 255},
        icon = 'info',
        sound = 'NAV_UP_DOWN'
    },
    success = {
        backgroundColor = {0, 200, 0, 180},
        textColor = {255, 255, 255, 255},
        borderColor = {0, 255, 0, 255},
        icon = 'success',
        sound = 'CHECKPOINT_PERFECT'
    },
    warning = {
        backgroundColor = {255, 165, 0, 180},
        textColor = {255, 255, 255, 255},
        borderColor = {255, 200, 0, 255},
        icon = 'warning',
        sound = 'ERROR'
    },
    error = {
        backgroundColor = {200, 0, 0, 180},
        textColor = {255, 255, 255, 255},
        borderColor = {255, 0, 0, 255},
        icon = 'error',
        sound = 'LOSER'
    }
}

-- =====================================================
-- MENU SYSTEM CONFIGURATION
-- =====================================================

-- Menu styling
UIConfig.Menu = {
    enabled = true,
    style = 'modern',                     -- classic, modern, minimal
    backgroundColor = {0, 0, 0, 200},
    borderColor = {255, 255, 255, 100},
    textColor = {255, 255, 255, 255},
    accentColor = {0, 150, 255, 255},
    selectedColor = {255, 215, 0, 255},
    fontSize = 0.4,
    fontFamily = 4,
    maxItemsVisible = 8,
    itemHeight = 0.05,
    width = 0.25,
    animations = true,
    sounds = true
}

-- =====================================================
-- LOADING SCREEN CONFIGURATION
-- =====================================================

-- Loading screen settings
UIConfig.Loading = {
    enabled = true,
    showProgress = true,
    showTips = true,
    backgroundColor = {0, 0, 0, 255},
    logoPath = 'assets/logo.png',
    logoSize = {width = 200, height = 100},
    progressBarColor = {0, 150, 255, 255},
    textColor = {255, 255, 255, 255},
    tipDuration = 3000,                   -- Time to show each tip
    fadeTransitions = true
}

-- Loading tips
UIConfig.LoadingTips = {
    'Use cover effectively to avoid enemy fire',
    'Headshots deal extra damage',
    'Watch your ammo count during fights',
    'Practice your aim in training mode',
    'Learn the arena layouts for tactical advantage',
    'Different weapons have different effective ranges',
    'Stay calm under pressure for better accuracy',
    'Use sound cues to track your opponent'
}

-- =====================================================
-- SPECTATOR UI CONFIGURATION
-- =====================================================

-- Spectator mode UI
UIConfig.Spectator = {
    enabled = true,
    showSpectatorHUD = true,
    showPlayerInfo = true,
    showMatchInfo = true,
    allowCameraSwitch = true,
    showControls = true,
    fadeUIWhenInactive = true,
    inactivityTime = 5000,                -- Hide UI after 5 seconds of inactivity
    overlayOpacity = 0.8,
    position = {x = 0.5, y = 0.02}
}

-- Spectator controls
UIConfig.SpectatorControls = {
    switchPlayer = 'E',
    freeCam = 'F',
    exitSpectator = 'ESC',
    showHelp = 'H'
}

-- =====================================================
-- RESULT SCREEN CONFIGURATION
-- =====================================================

-- Match result display
UIConfig.Results = {
    enabled = true,
    showDetailedStats = true,
    showRatingChanges = true,
    showXPGained = true,
    duration = 8000,                      -- Show for 8 seconds
    autoAdvance = true,
    allowSkip = true,
    backgroundBlur = true,
    animations = true,
    celebrationEffects = true
}

-- Result screen elements
UIConfig.ResultElements = {
    title = {
        position = {x = 0.5, y = 0.2},
        fontSize = 1.5,
        colors = {
            win = {0, 255, 0},
            loss = {255, 0, 0},
            draw = {255, 255, 0}
        }
    },
    stats = {
        position = {x = 0.5, y = 0.4},
        showDuration = true,
        showAccuracy = true,
        showDamage = true,
        showHeadshots = true
    },
    ratings = {
        position = {x = 0.5, y = 0.6},
        showOldRating = true,
        showNewRating = true,
        showChange = true,
        animateChange = true
    }
}

-- =====================================================
-- INTERACTION PROMPTS
-- =====================================================

-- Interaction prompt system
UIConfig.Prompts = {
    enabled = true,
    position = {x = 0.5, y = 0.8},
    backgroundColor = {0, 0, 0, 180},
    textColor = {255, 255, 255, 255},
    accentColor = {0, 150, 255, 255},
    fontSize = 0.4,
    showKeyBinding = true,
    fadeInTime = 200,
    fadeOutTime = 300
}

-- =====================================================
-- PERFORMANCE SETTINGS
-- =====================================================

-- Performance optimization
UIConfig.Performance = {
    enableVSync = true,
    targetFPS = 60,
    adaptiveQuality = true,               -- Reduce quality if FPS drops
    minFPS = 30,                          -- Minimum FPS before quality reduction
    updateInterval = 16,                  -- ~60 FPS update rate
    batchDrawCalls = true,                -- Batch UI draw calls
    useGPUAcceleration = true,            -- Use GPU for UI rendering
    memoryLimit = 100                     -- Memory limit in MB
}

-- LOD (Level of Detail) settings
UIConfig.LOD = {
    enableLOD = true,
    nearDistance = 10.0,                  -- Full quality distance
    farDistance = 50.0,                   -- Reduced quality distance
    cullDistance = 100.0,                 -- No rendering beyond this
    reducedUpdateRate = 5                 -- Update rate for distant UI elements
}

-- =====================================================
-- ACCESSIBILITY SETTINGS
-- =====================================================

-- Accessibility options
UIConfig.Accessibility = {
    colorBlindSupport = true,             -- Color blind friendly colors
    highContrast = false,                 -- High contrast mode
    largeText = false,                    -- Large text mode
    screenReader = false,                 -- Screen reader support
    reducedMotion = false,                -- Reduce animations
    audioFeedback = true,                 -- Audio feedback for actions
    keyboardNavigation = true             -- Keyboard menu navigation
}

-- Color blind friendly palette
UIConfig.ColorBlindPalette = {
    red = {213, 94, 0},                   -- Orange instead of red
    green = {0, 158, 115},                -- Blue-green
    blue = {86, 180, 233},                -- Sky blue
    yellow = {240, 228, 66},              -- Yellow
    purple = {204, 121, 167}              -- Rose
}

-- =====================================================
-- THEME SYSTEM
-- =====================================================

-- Theme configuration
UIConfig.Themes = {
    default = {
        primary = {0, 150, 255},
        secondary = {255, 215, 0},
        success = {0, 255, 0},
        warning = {255, 165, 0},
        error = {255, 0, 0},
        background = {0, 0, 0, 200},
        text = {255, 255, 255}
    },
    dark = {
        primary = {100, 100, 100},
        secondary = {200, 200, 200},
        success = {0, 200, 0},
        warning = {255, 200, 0},
        error = {200, 0, 0},
        background = {20, 20, 20, 220},
        text = {220, 220, 220}
    },
    neon = {
        primary = {0, 255, 255},
        secondary = {255, 0, 255},
        success = {0, 255, 0},
        warning = {255, 255, 0},
        error = {255, 0, 0},
        background = {0, 0, 0, 240},
        text = {255, 255, 255}
    }
}

-- Default theme
UIConfig.CurrentTheme = 'default'

-- =====================================================
-- ANIMATION SETTINGS
-- =====================================================

-- Animation configuration
UIConfig.Animations = {
    enabled = true,
    duration = 300,                       -- Default animation duration
    easing = 'ease-out',                  -- Animation easing
    reduceMotion = false,                 -- Accessibility option
    particleEffects = true,               -- Enable particle effects
    transitionEffects = true              -- Enable transition effects
}

-- Specific animations
UIConfig.AnimationTypes = {
    fadeIn = {duration = 300, easing = 'ease-out'},
    fadeOut = {duration = 200, easing = 'ease-in'},
    slideIn = {duration = 400, easing = 'ease-out'},
    slideOut = {duration = 300, easing = 'ease-in'},
    bounce = {duration = 500, easing = 'bounce'},
    elastic = {duration = 600, easing = 'elastic'}
}

-- =====================================================
-- AUDIO SETTINGS
-- =====================================================

-- UI audio configuration
UIConfig.Audio = {
    enabled = true,
    masterVolume = 0.7,
    uiSounds = true,
    notificationSounds = true,
    menuSounds = true,
    buttonSounds = true,
    errorSounds = true,
    successSounds = true
}

-- Sound mappings
UIConfig.Sounds = {
    buttonClick = 'NAV_UP_DOWN',
    buttonHover = 'NAV_LEFT_RIGHT',
    menuOpen = 'SELECT',
    menuClose = 'BACK',
    notification = 'CHECKPOINT_PERFECT',
    error = 'ERROR',
    success = 'RACE_PLACED',
    warning = 'TIMER_STOP'
}

-- =====================================================
-- RESPONSIVE DESIGN
-- =====================================================

-- Responsive breakpoints
UIConfig.Responsive = {
    enabled = true,
    breakpoints = {
        mobile = 1024,                    -- Mobile/small screens
        tablet = 1440,                    -- Tablet/medium screens
        desktop = 1920,                   -- Desktop/large screens
        ultrawide = 2560                  -- Ultrawide/extra large screens
    },
    scaleFactors = {
        mobile = 0.8,
        tablet = 0.9,
        desktop = 1.0,
        ultrawide = 1.1
    }
}

-- =====================================================
-- INTEGRATION SETTINGS
-- =====================================================

-- Integration with other TGW systems
UIConfig.Integration = {
    tgw_round = true,                     -- Round system integration
    tgw_ladder = true,                    -- Ladder system integration
    tgw_rating = true,                    -- Rating system integration
    tgw_chat = true,                      -- Chat system integration
    tgw_queue = true,                     -- Queue system integration
    syncWithPreferences = true,           -- Sync with player preferences
    realTimeUpdates = true                -- Real-time data updates
}