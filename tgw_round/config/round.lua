RoundConfig = {}

-- =====================================================
-- ROUND TIMING CONFIGURATION
-- =====================================================

-- Waktu ronde berdasarkan konsep (detik)
RoundConfig.FreezeTime = 4.0                 -- freeze countdown sebelum start
RoundConfig.RoundTime = 75.0                 -- durasi ronde utama (1 menit 15 detik)
RoundConfig.SuddenDeath = 25.0               -- durasi sudden death
RoundConfig.AFKThreshold = 15.0              -- batas AFK sebelum forfeit

-- =====================================================
-- SUDDEN DEATH CONFIGURATION
-- =====================================================

-- Sudden death mechanics
RoundConfig.SuddenDeathShrink = true         -- shrink arena radius
RoundConfig.SuddenDeathShrinkStep = 3.0      -- pengurangan radius per step (meter)
RoundConfig.SuddenDeathTick = 5.0            -- interval shrink (detik)
RoundConfig.SuddenDeathMinRadius = 10.0      -- radius minimum

-- Sudden death damage
RoundConfig.OutOfBoundsDamagePerSec = 25     -- damage per detik di luar radius
RoundConfig.HeadshotBonusDamage = 0.25       -- 25% bonus damage untuk headshot

-- =====================================================
-- ROUND TYPES CONFIGURATION
-- =====================================================

-- Konfigurasi per tipe ronde (rifle, pistol, sniper)
RoundConfig.RoundTypes = {
    rifle = {
        armor = 50,
        helmet = true,
        weapons = { 'WEAPON_CARBINERIFLE', 'WEAPON_ASSAULTRIFLE', 'WEAPON_BULLPUPRIFLE' },
        pistol = 'WEAPON_PISTOL',
        ammo = { primary = 120, secondary = 36 }
    },
    pistol = {
        armor = 25,
        helmet = false,
        weapons = { 'WEAPON_PISTOL', 'WEAPON_PISTOL_MK2', 'WEAPON_PISTOL50' },
        pistol = nil,
        ammo = { primary = 60, secondary = 0 }
    },
    sniper = {
        armor = 50,
        helmet = true,
        weapons = { 'WEAPON_SNIPERRIFLE', 'WEAPON_MARKSMANRIFLE', 'WEAPON_HEAVYSNIPER' },
        pistol = 'WEAPON_SNSPISTOL',
        ammo = { primary = 30, secondary = 24 }
    }
}

-- =====================================================
-- PLAYER CONTROL SETTINGS
-- =====================================================

-- Kontrol yang diblokir
RoundConfig.DisableMelee = true              -- nonaktifkan melee attacks
RoundConfig.BlockHealthItems = true          -- blokir health items
RoundConfig.BlockArmorItems = true           -- blokir armor items
RoundConfig.BlockWeaponDrop = true           -- cegah drop weapon

-- Freeze controls
RoundConfig.FreezeControls = {
    movement = true,      -- blokir movement saat freeze
    weapons = true,       -- blokir weapons saat freeze
    vehicle = true,       -- blokir enter vehicle
    interaction = true    -- blokir interaction
}

-- =====================================================
-- AFK DETECTION
-- =====================================================

-- AFK detection settings
RoundConfig.AFKDetection = {
    checkMovement = true,           -- cek pergerakan pemain
    checkShooting = true,           -- cek aktivitas menembak
    checkInput = true,              -- cek input lainnya
    minMovementDistance = 2.0,      -- minimal jarak gerak untuk tidak AFK
    checkInterval = 5.0             -- interval cek AFK (detik)
}

-- =====================================================
-- ROUND END CONDITIONS
-- =====================================================

-- Kondisi kemenangan
RoundConfig.WinConditions = {
    kill = true,                    -- menang dengan kill
    forfeit = true,                 -- menang dengan forfeit lawan
    sudden_death_hp = true,         -- menang dengan HP tersisa di sudden death
    sudden_death_hits = true,       -- menang dengan hit terbanyak di sudden death
    disconnect = true               -- menang jika lawan disconnect
}

-- Sudden death tie-breaker priority
RoundConfig.TieBreaker = {
    'health',                       -- HP tersisa tertinggi
    'hits',                         -- hit terbanyak
    'draw'                         -- draw jika semua sama
}

-- =====================================================
-- HIT TRACKING AND STATISTICS
-- =====================================================

-- Hit tracking untuk tie-breaker
RoundConfig.TrackHits = true
RoundConfig.TrackDamage = true
RoundConfig.TrackHeadshots = true

-- Hit validation
RoundConfig.ValidateHits = true
RoundConfig.MaxHitsPerSecond = 20            -- anti-spam hit detection
RoundConfig.HitTimeWindow = 1.0              -- window untuk validasi hit

-- =====================================================
-- ROUND STATES
-- =====================================================

-- State machine untuk ronde
RoundConfig.States = {
    PREPARING = 'preparing',        -- persiapan sebelum freeze
    FREEZE = 'freeze',              -- countdown freeze
    ACTIVE = 'active',              -- ronde aktif
    SUDDEN_DEATH = 'sudden_death',  -- sudden death mode
    ENDING = 'ending',              -- ronde berakhir
    COMPLETED = 'completed'         -- ronde selesai
}

-- =====================================================
-- PERFORMANCE SETTINGS
-- =====================================================

-- Update intervals
RoundConfig.TickRate = 250                   -- main round timer tick (ms)
RoundConfig.AFKCheckRate = 5000              -- AFK check interval (ms)
RoundConfig.HitValidationRate = 100          -- hit validation rate (ms)
RoundConfig.SuddenDeathTickRate = 5000       -- sudden death tick rate (ms)

-- Logging and debug
RoundConfig.LogRoundEvents = true
RoundConfig.EnableDebugHUD = false
RoundConfig.ShowRoundStats = true

-- =====================================================
-- NOTIFICATION MESSAGES
-- =====================================================

-- Pesan notifikasi untuk berbagai event
RoundConfig.Messages = {
    round_starting = 'Ronde dimulai...',
    sudden_death = 'Sudden Death!',
    round_ended = 'Ronde berakhir',
    player_killed = '%s telah mati',
    player_afk = '%s AFK - Forfeit',
    out_of_bounds = '%s keluar zona - Forfeit',
    player_won = '%s menang!',
    round_draw = 'Hasil seri',
    countdown_3 = '3',
    countdown_2 = '2',
    countdown_1 = '1',
    countdown_go = 'GO!'
}

-- =====================================================
-- ROUND RESULT CALCULATION
-- =====================================================

-- Settings untuk kalkulasi hasil
RoundConfig.ResultCalculation = {
    instakill_hp_threshold = 0,              -- HP threshold untuk instant kill
    minimum_damage_for_hit = 1,              -- minimum damage untuk count sebagai hit
    headshot_multiplier = 1.25,              -- multiplier damage headshot
    sudden_death_hp_decay = false            -- HP decay selama sudden death
}