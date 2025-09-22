Config = {}

-- =====================================================
-- FRAMEWORK CONFIGURATION
-- =====================================================
Config.Framework = 'esx'
Config.Locale = 'id'
Config.UseVoice = false
Config.EnableSpectateQueue = true

-- =====================================================
-- ARENA SYSTEM CONFIGURATION
-- =====================================================
Config.MaxArenas = 24
Config.LobbyBucket = 0
Config.BaseBucketID = 1000

-- =====================================================
-- TIMING CONFIGURATION
-- =====================================================
Config.TickRate = 250                    -- Main loop tick rate in milliseconds
Config.DBWait = 50                       -- Database operation timeout
Config.HeartbeatInterval = 30000         -- Player heartbeat interval (30 seconds)

-- =====================================================
-- ECONOMY CONFIGURATION
-- =====================================================
Config.UseCashAsCredits = true
Config.CreditsOnWin = 100
Config.CreditsOnLose = 0
Config.EntryFee = 0                      -- Entry fee for matches (0 = free)

-- =====================================================
-- PLAYER CONFIGURATION
-- =====================================================
Config.DefaultRating = 1500
Config.DefaultLadderLevel = 16
Config.MaxNicknameLength = 20
Config.MinNicknameLength = 3

-- =====================================================
-- SYSTEM LIMITS
-- =====================================================
Config.MaxPlayersPerArena = 2
Config.MaxSpectators = 50
Config.MaxQueueSize = 100

-- =====================================================
-- PERFORMANCE SETTINGS
-- =====================================================
Config.EnableDebugMode = false
Config.EnablePerformanceMetrics = false
Config.LogLevel = 'info'                 -- 'debug', 'info', 'warn', 'error'

-- =====================================================
-- KEYBINDS
-- =====================================================
Config.Keybinds = {
    OpenMenu = 'F5',
    SpectateNext = 'RIGHT',
    SpectatePrev = 'LEFT',
    LeaveQueue = 'BACK',
    ChatArena = 'T'
}

-- =====================================================
-- LOCALIZATION
-- =====================================================
Config.Locales = {
    ['id'] = {
        -- General
        ['loading'] = 'Memuat...',
        ['error'] = 'Error',
        ['success'] = 'Berhasil',
        ['failed'] = 'Gagal',
        ['confirm'] = 'Konfirmasi',
        ['cancel'] = 'Batal',

        -- TGW System
        ['tgw_system'] = 'TGW System',
        ['joining_queue'] = 'Bergabung dengan antrean...',
        ['leaving_queue'] = 'Meninggalkan antrean...',
        ['queue_joined'] = 'Berhasil bergabung dengan antrean',
        ['queue_left'] = 'Berhasil meninggalkan antrean',
        ['match_found'] = 'Lawan ditemukan!',
        ['teleporting'] = 'Teleporting ke arena...',

        -- Player Status
        ['player_not_found'] = 'Pemain tidak ditemukan',
        ['invalid_identifier'] = 'Identifier tidak valid',
        ['player_already_in_queue'] = 'Pemain sudah dalam antrean',
        ['player_not_in_queue'] = 'Pemain tidak dalam antrean',
        ['insufficient_funds'] = 'Uang tidak cukup',

        -- Arena
        ['arena_full'] = 'Arena penuh',
        ['arena_not_found'] = 'Arena tidak ditemukan',
        ['spectate_mode'] = 'Mode Spectate',
        ['round_starting'] = 'Ronde dimulai...',
        ['round_ended'] = 'Ronde berakhir',

        -- Errors
        ['database_error'] = 'Error database',
        ['server_error'] = 'Error server',
        ['network_error'] = 'Error jaringan',
        ['permission_denied'] = 'Akses ditolak'
    }
}

-- =====================================================
-- HELPER FUNCTIONS
-- =====================================================
function Config.GetLocale(key)
    local locale = Config.Locales[Config.Locale] or Config.Locales['id']
    return locale[key] or key
end

function Config.IsValidBucketID(bucketId)
    return bucketId >= Config.BaseBucketID and bucketId < (Config.BaseBucketID + Config.MaxArenas)
end

function Config.GetArenaBucketID(arenaId)
    return Config.BaseBucketID + (arenaId - 1)
end

-- =====================================================
-- WEAPON HASH MAPPINGS
-- =====================================================
Config.WeaponHashes = {
    -- Rifles
    ['WEAPON_CARBINERIFLE'] = `WEAPON_CARBINERIFLE`,
    ['WEAPON_ASSAULTRIFLE'] = `WEAPON_ASSAULTRIFLE`,
    ['WEAPON_BULLPUPRIFLE'] = `WEAPON_BULLPUPRIFLE`,

    -- Pistols
    ['WEAPON_PISTOL'] = `WEAPON_PISTOL`,
    ['WEAPON_PISTOL_MK2'] = `WEAPON_PISTOL_MK2`,
    ['WEAPON_PISTOL50'] = `WEAPON_PISTOL50`,

    -- Snipers
    ['WEAPON_SNIPERRIFLE'] = `WEAPON_SNIPERRIFLE`,
    ['WEAPON_MARKSMANRIFLE'] = `WEAPON_MARKSMANRIFLE`,
    ['WEAPON_HEAVYSNIPER'] = `WEAPON_HEAVYSNIPER`,

    -- Secondary
    ['WEAPON_SNSPISTOL'] = `WEAPON_SNSPISTOL`
}

-- =====================================================
-- ROUND TYPES CONFIGURATION
-- =====================================================
Config.RoundTypes = {
    'rifle',
    'pistol',
    'sniper'
}

-- =====================================================
-- ARENA TEMPLATE (DEFAULT COORDINATES)
-- =====================================================
Config.DefaultArenaTemplate = {
    name = 'Depot One',
    radius = 30.0,
    spawnA = vector3(169.5, -1005.2, 29.4),
    headingA = 90.0,
    spawnB = vector3(145.8, -1012.9, 29.4),
    headingB = 270.0,
    center = vector3(157.65, -1009.05, 29.4)
}

-- =====================================================
-- EVENT NAMES (CONSISTENT ACROSS RESOURCES)
-- =====================================================
Config.Events = {
    -- Server to Client
    PlayerJoinedTGW = 'tgw:player:joined',
    PlayerLeftTGW = 'tgw:player:left',
    QueueStatusUpdate = 'tgw:queue:status',
    MatchTeleport = 'tgw:match:teleport',
    RoundFreeze = 'tgw:round:freeze',
    RoundStart = 'tgw:round:start',
    RoundEnd = 'tgw:round:end',
    SpectateStart = 'tgw:spectate:start',
    SpectateStop = 'tgw:spectate:stop',
    ChatReceive = 'tgw:chat:receive',
    NotificationSend = 'tgw:notification:send',

    -- Client to Server
    QueueJoin = 'tgw:queue:join',
    QueueLeave = 'tgw:queue:leave',
    PreferenceSave = 'tgw:preference:save',
    RoundHit = 'tgw:round:hit',
    SpectateNext = 'tgw:spectate:next',
    SpectatePrev = 'tgw:spectate:prev',
    ChatSend = 'tgw:chat:send',
    PlayerHeartbeat = 'tgw:player:heartbeat',

    -- Callbacks
    GetPlayerData = 'tgw:callback:getPlayerData',
    GetPreferences = 'tgw:callback:getPreferences',
    GetLeaderboard = 'tgw:callback:getLeaderboard',
    GetQueueStatus = 'tgw:callback:getQueueStatus'
}

-- =====================================================
-- VERSION INFO
-- =====================================================
Config.Version = {
    major = 1,
    minor = 0,
    patch = 0,
    build = 'release'
}

function Config.GetVersionString()
    return string.format('%d.%d.%d-%s',
        Config.Version.major,
        Config.Version.minor,
        Config.Version.patch,
        Config.Version.build
    )
end