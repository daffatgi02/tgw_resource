ArenaConfig = {}

-- =====================================================
-- ARENA SYSTEM CONFIGURATION
-- =====================================================

-- Model satu lokasi, banyak arena via routing bucket
ArenaConfig.UseInstance = true
ArenaConfig.BaseBucket = 1000                -- bucket awal arena (1000-1023 untuk 24 arena)
ArenaConfig.ArenasCount = 24                 -- jumlah arena aktif
ArenaConfig.AutoSeedArenas = true            -- auto-seed tgw_arenas saat start

-- Template lokasi untuk SEMUA arena (koordinat yang sama)
ArenaConfig.Template = {
    name = 'Depot One',
    radius = 30.0,
    spawnA = vector3(169.5, -1005.2, 29.4),
    headingA = 90.0,
    spawnB = vector3(145.8, -1012.9, 29.4),
    headingB = 270.0,
    center = vector3(157.65, -1009.05, 29.4)  -- titik tengah arena
}

-- Batas arena dan peringatan
ArenaConfig.OutOfBoundsWarnSec = 3.0         -- waktu peringatan sebelum forfeit
ArenaConfig.MaxViolations = 2                -- maksimal pelanggaran sebelum forfeit
ArenaConfig.ViolationResetSec = 10           -- reset violation counter

-- Teleportasi dan spawn
ArenaConfig.TeleportDelay = 1000             -- delay teleport dalam ms
ArenaConfig.SpawnProtection = 3.0            -- proteksi spawn dalam detik
ArenaConfig.SafeZoneRadius = 5.0             -- radius aman di sekitar spawn

-- Arena assignment
ArenaConfig.PreferRecentlyUsed = false      -- prefer arena yang baru dipakai
ArenaConfig.BalanceLoad = true               -- seimbangkan beban arena
ArenaConfig.ReserveArenas = 2                -- arena yang direserve untuk high priority

-- Cleanup settings
ArenaConfig.CleanupOnEmpty = true            -- cleanup saat arena kosong
ArenaConfig.CleanupDelay = 30                -- delay cleanup setelah kosong (detik)
ArenaConfig.ForceCleanupAfter = 300          -- force cleanup setelah 5 menit

-- Performance settings
ArenaConfig.UpdateInterval = 1000            -- interval update arena status (ms)
ArenaConfig.PlayerCheckInterval = 5000       -- interval cek pemain di arena (ms)
ArenaConfig.EntityCleanupRadius = 50.0       -- radius cleanup entity

-- Debug and logging
ArenaConfig.EnableDebugMarkers = false       -- tampilkan marker debug di arena
ArenaConfig.LogArenaEvents = true            -- log event arena
ArenaConfig.ShowBucketInChat = true          -- tampilkan bucket ID di chat arena

-- Arena states
ArenaConfig.States = {
    EMPTY = 'empty',           -- arena kosong
    PREPARING = 'preparing',   -- sedang prepare untuk match
    ACTIVE = 'active',         -- match sedang berjalan
    CLEANUP = 'cleanup'        -- sedang cleanup
}

-- Spawn sides
ArenaConfig.SpawnSides = {
    A = 'A',
    B = 'B'
}

-- Validation settings
ArenaConfig.ValidateSpawnPoints = true       -- validasi spawn point saat assignment
ArenaConfig.ValidateRadius = true            -- validasi radius arena
ArenaConfig.RequireGroundZ = true            -- require spawn di permukaan tanah