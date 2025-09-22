PreferenceConfig = {}

-- =====================================================
-- PREFERENCE CATEGORIES
-- =====================================================

-- Kategori preferensi yang dapat diatur player
PreferenceConfig.Categories = {
    weapon = {
        name = 'Weapon Preferences',
        description = 'Preferred weapons for each round type',
        saveToDB = true,
        syncAcrossDevices = true
    },
    gameplay = {
        name = 'Gameplay Settings',
        description = 'Game behavior and controls',
        saveToDB = true,
        syncAcrossDevices = true
    },
    hud = {
        name = 'HUD Settings',
        description = 'User interface preferences',
        saveToDB = true,
        syncAcrossDevices = false
    },
    audio = {
        name = 'Audio Settings',
        description = 'Sound and music preferences',
        saveToDB = true,
        syncAcrossDevices = false
    },
    controls = {
        name = 'Control Settings',
        description = 'Key bindings and control preferences',
        saveToDB = true,
        syncAcrossDevices = false
    }
}

-- =====================================================
-- WEAPON PREFERENCES
-- =====================================================

-- Default weapon preferences per round type
PreferenceConfig.WeaponDefaults = {
    rifle = 'WEAPON_CARBINERIFLE',
    pistol = 'WEAPON_PISTOL',
    sniper = 'WEAPON_SNIPERRIFLE'
}

-- Available weapon choices per round type
PreferenceConfig.WeaponChoices = {
    rifle = {
        {hash = 'WEAPON_CARBINERIFLE', name = 'Carbine Rifle', description = 'Balanced assault rifle'},
        {hash = 'WEAPON_ASSAULTRIFLE', name = 'Assault Rifle', description = 'High damage, slower fire'},
        {hash = 'WEAPON_BULLPUPRIFLE', name = 'Bullpup Rifle', description = 'Fast fire rate, lower damage'}
    },
    pistol = {
        {hash = 'WEAPON_PISTOL', name = 'Pistol', description = 'Standard sidearm'},
        {hash = 'WEAPON_PISTOL_MK2', name = 'Pistol Mk II', description = 'Improved version'},
        {hash = 'WEAPON_PISTOL50', name = 'Pistol .50', description = 'High damage, slower fire'}
    },
    sniper = {
        {hash = 'WEAPON_SNIPERRIFLE', name = 'Sniper Rifle', description = 'High accuracy, one-shot potential'},
        {hash = 'WEAPON_MARKSMANRIFLE', name = 'Marksman Rifle', description = 'Semi-auto precision'},
        {hash = 'WEAPON_HEAVYSNIPER', name = 'Heavy Sniper', description = 'Maximum damage and range'}
    }
}

-- =====================================================
-- GAMEPLAY PREFERENCES
-- =====================================================

-- Gameplay behavior settings
PreferenceConfig.GameplayDefaults = {
    autoQueue = false,               -- auto-join queue after match
    spectateMode = 'firstPerson',    -- camera mode while spectating
    crosshairStyle = 'dot',          -- crosshair preference
    damageNumbers = true,            -- show damage numbers
    killFeed = true,                 -- show kill notifications
    roundResults = true,             -- show detailed round results
    matchHistory = true,             -- track match history
    allowFriendSpectate = true,      -- allow friends to spectate
    hideRating = false,              -- hide ELO rating from others
    acceptChallenges = true          -- accept direct challenges
}

PreferenceConfig.GameplayChoices = {
    spectateMode = {
        {value = 'firstPerson', name = 'First Person', description = 'Follow players in first person'},
        {value = 'thirdPerson', name = 'Third Person', description = 'Follow players in third person'},
        {value = 'freeCam', name = 'Free Camera', description = 'Free roam camera in arena'}
    },
    crosshairStyle = {
        {value = 'dot', name = 'Dot', description = 'Simple dot crosshair'},
        {value = 'cross', name = 'Cross', description = 'Traditional cross crosshair'},
        {value = 'circle', name = 'Circle', description = 'Circle crosshair'},
        {value = 'none', name = 'None', description = 'No crosshair overlay'}
    }
}

-- =====================================================
-- HUD PREFERENCES
-- =====================================================

-- HUD display settings
PreferenceConfig.HUDDefaults = {
    hudPosition = 'bottom',          -- HUD position on screen
    timerSize = 'medium',            -- timer display size
    showOpponentInfo = true,         -- show opponent name and rating
    showRoundType = true,            -- show current round type
    showAmmoCount = true,            -- show ammunition count
    showHealthBar = true,            -- show health bar
    showArmorBar = true,             -- show armor bar
    hudOpacity = 0.8,                -- HUD transparency
    showMinimap = false,             -- show minimap during round
    countdownStyle = 'numbers',      -- countdown display style
    resultOverlay = true,            -- show result overlay screen
    spectatorHUD = true              -- show HUD while spectating
}

PreferenceConfig.HUDChoices = {
    hudPosition = {
        {value = 'top', name = 'Top', description = 'HUD elements at top of screen'},
        {value = 'bottom', name = 'Bottom', description = 'HUD elements at bottom of screen'},
        {value = 'sides', name = 'Sides', description = 'Spread HUD across sides'}
    },
    timerSize = {
        {value = 'small', name = 'Small', description = 'Compact timer display'},
        {value = 'medium', name = 'Medium', description = 'Standard timer size'},
        {value = 'large', name = 'Large', description = 'Large, prominent timer'}
    },
    countdownStyle = {
        {value = 'numbers', name = 'Numbers', description = 'Numeric countdown (3, 2, 1)'},
        {value = 'text', name = 'Text', description = 'Text countdown (Three, Two, One)'},
        {value = 'both', name = 'Both', description = 'Numbers with text'}
    }
}

-- =====================================================
-- AUDIO PREFERENCES
-- =====================================================

-- Audio settings
PreferenceConfig.AudioDefaults = {
    masterVolume = 0.8,              -- overall volume
    sfxVolume = 0.9,                 -- sound effects volume
    musicVolume = 0.6,               -- background music volume
    voiceVolume = 0.0,               -- voice chat volume (disabled)
    countdownSounds = true,          -- countdown audio cues
    killSounds = true,               -- kill confirmation sounds
    hitMarkerSounds = true,          -- hit marker audio
    ambientSounds = true,            -- arena ambient sounds
    weaponSounds = true,             -- weapon audio
    uiSounds = true,                 -- interface sounds
    radioChatter = false,            -- radio communications
    audioQuality = 'high'            -- audio quality setting
}

PreferenceConfig.AudioChoices = {
    audioQuality = {
        {value = 'low', name = 'Low', description = 'Performance optimized'},
        {value = 'medium', name = 'Medium', description = 'Balanced quality'},
        {value = 'high', name = 'High', description = 'Maximum quality'}
    }
}

-- =====================================================
-- CONTROL PREFERENCES
-- =====================================================

-- Control and keybind settings
PreferenceConfig.ControlDefaults = {
    mouseSensitivity = 0.5,          -- mouse sensitivity multiplier
    aimSensitivity = 0.3,            -- aim sensitivity multiplier
    invertY = false,                 -- invert Y-axis
    toggleAim = false,               -- toggle vs hold to aim
    autoReload = true,               -- automatic reload when empty
    sprintToggle = false,            -- toggle vs hold to sprint
    crouchToggle = true,             -- toggle vs hold to crouch
    weaponSwapMode = 'scroll',       -- weapon switching method
    quickSwitch = true,              -- enable quick weapon switch
    contextualReload = true          -- context-sensitive reload
}

PreferenceConfig.ControlChoices = {
    weaponSwapMode = {
        {value = 'scroll', name = 'Mouse Wheel', description = 'Use mouse wheel to cycle weapons'},
        {value = 'keys', name = 'Number Keys', description = 'Use number keys for direct selection'},
        {value = 'both', name = 'Both', description = 'Allow both methods'}
    }
}

-- =====================================================
-- PREFERENCE VALIDATION
-- =====================================================

-- Validation rules for preferences
PreferenceConfig.Validation = {
    weapon = {
        required = true,
        validateAgainstChoices = true,
        allowCustom = false
    },
    gameplay = {
        required = false,
        validateTypes = true,
        allowCustom = false
    },
    hud = {
        required = false,
        validateRanges = true,
        allowCustom = true
    },
    audio = {
        required = false,
        validateRanges = true,
        allowCustom = false
    },
    controls = {
        required = false,
        validateRanges = true,
        allowCustom = true
    }
}

-- Value ranges for numeric preferences
PreferenceConfig.Ranges = {
    hudOpacity = {min = 0.1, max = 1.0},
    masterVolume = {min = 0.0, max = 1.0},
    sfxVolume = {min = 0.0, max = 1.0},
    musicVolume = {min = 0.0, max = 1.0},
    voiceVolume = {min = 0.0, max = 1.0},
    mouseSensitivity = {min = 0.1, max = 2.0},
    aimSensitivity = {min = 0.1, max = 2.0}
}

-- =====================================================
-- PERSISTENCE SETTINGS
-- =====================================================

-- Database and caching settings
PreferenceConfig.Persistence = {
    autoSave = true,                 -- automatically save changes
    saveDelay = 2000,                -- delay before saving (ms)
    cacheDuration = 3600,            -- cache preferences for 1 hour
    syncOnLogin = true,              -- sync preferences on player login
    backupOldValues = true,          -- backup previous values
    maxBackups = 5                   -- maximum backup entries
}

-- =====================================================
-- UI SETTINGS
-- =====================================================

-- Preference menu settings
PreferenceConfig.UI = {
    enablePreferenceMenu = true,     -- enable in-game preference menu
    menuCommand = 'preferences',     -- command to open menu
    categoryTabs = true,             -- use tabbed interface
    searchEnabled = true,            -- enable preference search
    resetConfirmation = true,        -- confirm before resetting
    applyChangesImmediately = false, -- apply changes without restart
    showAdvancedOptions = false      -- show advanced/developer options
}

-- Menu access permissions
PreferenceConfig.MenuAccess = {
    duringQueue = true,              -- allow access while in queue
    duringSpectate = true,           -- allow access while spectating
    duringMatch = false,             -- block access during active match
    duringFreezePhase = false        -- block access during freeze phase
}

-- =====================================================
-- PREFERENCE EXPORT/IMPORT
-- =====================================================

-- Settings for preference backup and sharing
PreferenceConfig.ExportImport = {
    enableExport = true,             -- allow preference export
    enableImport = true,             -- allow preference import
    shareWithFriends = true,         -- allow sharing with friends
    cloudBackup = false,             -- cloud backup integration
    maxExportSize = 4096,            -- maximum export size (bytes)
    compressionEnabled = true        -- compress exported data
}