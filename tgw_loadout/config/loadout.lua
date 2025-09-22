LoadoutConfig = {}

-- =====================================================
-- WEAPON LOADOUT CONFIGURATIONS
-- =====================================================

-- Konfigurasi loadout berdasarkan round type dari RoundConfig
LoadoutConfig.RoundTypes = {
    rifle = {
        armor = 50,
        helmet = true,
        weapons = {
            primary = {
                'WEAPON_CARBINERIFLE',
                'WEAPON_ASSAULTRIFLE',
                'WEAPON_BULLPUPRIFLE'
            },
            secondary = 'WEAPON_PISTOL'
        },
        ammo = {
            primary = 120,
            secondary = 36
        },
        attachments = {
            'COMPONENT_AT_AR_FLSH',      -- Flashlight
            'COMPONENT_AT_AR_AFGRIP',    -- Grip
            'COMPONENT_CARBINERIFLE_CLIP_02' -- Extended clip
        }
    },
    pistol = {
        armor = 25,
        helmet = false,
        weapons = {
            primary = {
                'WEAPON_PISTOL',
                'WEAPON_PISTOL_MK2',
                'WEAPON_PISTOL50'
            },
            secondary = nil
        },
        ammo = {
            primary = 60,
            secondary = 0
        },
        attachments = {
            'COMPONENT_AT_PI_FLSH'       -- Pistol flashlight
        }
    },
    sniper = {
        armor = 50,
        helmet = true,
        weapons = {
            primary = {
                'WEAPON_SNIPERRIFLE',
                'WEAPON_MARKSMANRIFLE',
                'WEAPON_HEAVYSNIPER'
            },
            secondary = 'WEAPON_SNSPISTOL'
        },
        ammo = {
            primary = 30,
            secondary = 24
        },
        attachments = {
            'COMPONENT_AT_SCOPE_LARGE',  -- Sniper scope
            'COMPONENT_AT_SR_SUPP'       -- Suppressor
        }
    }
}

-- =====================================================
-- LOADOUT APPLICATION SETTINGS
-- =====================================================

-- Pengaturan aplikasi loadout
LoadoutConfig.Application = {
    clearAllWeapons = true,          -- bersihkan semua weapon sebelum apply
    clearInventory = false,          -- jangan clear inventory ESX
    removeArmor = false,             -- jangan remove armor yang ada
    setMaxHealth = true,             -- set health ke maksimal
    giveMaxArmor = false,            -- berikan armor sesuai config
    enableGodMode = false            -- tidak pakai god mode
}

-- =====================================================
-- WEAPON PREFERENCES
-- =====================================================

-- Default weapon preferences per round type
LoadoutConfig.DefaultPreferences = {
    rifle = 'WEAPON_CARBINERIFLE',
    pistol = 'WEAPON_PISTOL',
    sniper = 'WEAPON_SNIPERRIFLE'
}

-- Allowed weapon choices per category
LoadoutConfig.WeaponChoices = {
    rifle = {
        {weapon = 'WEAPON_CARBINERIFLE', name = 'Carbine Rifle', description = 'Balanced assault rifle'},
        {weapon = 'WEAPON_ASSAULTRIFLE', name = 'Assault Rifle', description = 'High damage, slower fire'},
        {weapon = 'WEAPON_BULLPUPRIFLE', name = 'Bullpup Rifle', description = 'Fast fire rate, lower damage'}
    },
    pistol = {
        {weapon = 'WEAPON_PISTOL', name = 'Pistol', description = 'Standard sidearm'},
        {weapon = 'WEAPON_PISTOL_MK2', name = 'Pistol Mk II', description = 'Improved version'},
        {weapon = 'WEAPON_PISTOL50', name = 'Pistol .50', description = 'High damage, slower fire'}
    },
    sniper = {
        {weapon = 'WEAPON_SNIPERRIFLE', name = 'Sniper Rifle', description = 'High accuracy, one-shot potential'},
        {weapon = 'WEAPON_MARKSMANRIFLE', name = 'Marksman Rifle', description = 'Semi-auto precision'},
        {weapon = 'WEAPON_HEAVYSNIPER', name = 'Heavy Sniper', description = 'Maximum damage and range'}
    }
}

-- =====================================================
-- ARMOR AND HEALTH SETTINGS
-- =====================================================

-- Health settings
LoadoutConfig.Health = {
    maxHealth = 200,                 -- maksimal health
    startHealth = 200,               -- health awal saat spawn
    regenEnabled = false             -- disable health regen
}

-- Armor settings
LoadoutConfig.Armor = {
    maxArmor = 100,                  -- maksimal armor
    helmetProtection = 0.15,         -- 15% headshot protection dengan helmet
    bodyArmorProtection = 0.25       -- 25% body protection dengan armor
}

-- =====================================================
-- LOADOUT VALIDATION
-- =====================================================

-- Validasi loadout
LoadoutConfig.Validation = {
    checkWeaponExists = true,        -- cek apakah weapon exist di game
    checkAmmoType = true,            -- cek tipe ammo yang sesuai
    checkAttachments = true,         -- cek attachment compatibility
    logInvalidWeapons = true         -- log weapon yang tidak valid
}

-- =====================================================
-- SPAWN LOCATIONS PER ROUND TYPE
-- =====================================================

-- Posisi spawn untuk setiap round type (dalam arena)
LoadoutConfig.SpawnPositions = {
    rifle = {
        player1 = {x = 0.0, y = 10.0, z = 1.0, heading = 180.0},
        player2 = {x = 0.0, y = -10.0, z = 1.0, heading = 0.0}
    },
    pistol = {
        player1 = {x = 5.0, y = 5.0, z = 1.0, heading = 225.0},
        player2 = {x = -5.0, y = -5.0, z = 1.0, heading = 45.0}
    },
    sniper = {
        player1 = {x = 0.0, y = 20.0, z = 1.0, heading = 180.0},
        player2 = {x = 0.0, y = -20.0, z = 1.0, heading = 0.0}
    }
}

-- =====================================================
-- WEAPON RESTRICTION SETTINGS
-- =====================================================

-- Pembatasan weapon selama round
LoadoutConfig.Restrictions = {
    disableMelee = true,             -- disable melee attacks
    disableThrowables = true,        -- disable grenades/throwables
    disableVehicleWeapons = true,    -- disable vehicle weapons
    blockWeaponDrop = true,          -- prevent weapon dropping
    blockWeaponPickup = true,        -- prevent weapon pickup
    blockAmmoPickup = false          -- allow ammo pickup
}

-- =====================================================
-- PERFORMANCE SETTINGS
-- =====================================================

-- Update intervals dan optimasi
LoadoutConfig.Performance = {
    weaponCheckInterval = 1000,      -- interval cek weapon player (ms)
    ammoCheckInterval = 5000,        -- interval cek ammo (ms)
    restrictionCheckInterval = 500,  -- interval cek restriction (ms)
    enableWeaponLogging = false      -- log weapon events
}

-- =====================================================
-- SPECIAL LOADOUT EFFECTS
-- =====================================================

-- Efek khusus untuk loadout
LoadoutConfig.Effects = {
    spawnParticles = true,           -- particle effect saat spawn
    weaponGlowEnabled = false,       -- weapon glow effect
    armorVisualEnabled = true,       -- visual armor indicator
    helmetVisualEnabled = true       -- visual helmet indicator
}

-- =====================================================
-- LOADOUT EVENTS
-- =====================================================

-- Event names untuk komunikasi
LoadoutConfig.Events = {
    applyLoadout = 'tgw:loadout:apply',
    removeLoadout = 'tgw:loadout:remove',
    updatePreference = 'tgw:loadout:updatePreference',
    validateLoadout = 'tgw:loadout:validate',
    loadoutApplied = 'tgw:loadout:applied',
    loadoutRemoved = 'tgw:loadout:removed'
}