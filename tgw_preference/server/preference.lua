-- =====================================================
-- TGW PREFERENCE SERVER - PLAYER PREFERENCE MANAGER
-- =====================================================
-- Purpose: Manage player preferences, settings, and configurations
-- Dependencies: tgw_core, es_extended
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']

-- Preference storage and caching
local PlayerPreferences = {}        -- [identifier] = {category = {key = value}}
local PreferenceCache = {}          -- Performance cache
local PendingSaves = {}             -- Delayed save queue

-- Statistics and monitoring
local PreferenceStats = {
    totalLoaded = 0,
    totalSaved = 0,
    cacheHits = 0,
    cacheMisses = 0
}

-- =====================================================
-- INITIALIZATION
-- =====================================================

CreateThread(function()
    while not ESX do
        ESX = exports['tgw_core']:GetESX()
        Wait(100)
    end

    RegisterEventHandlers()
    InitializeDefaultPreferences()
    StartPerformanceMonitoring()
    StartAutoSaveThread()

    print('^2[TGW-PREFERENCE SERVER]^7 Player preference system initialized')
end)

function RegisterEventHandlers()
    -- Preference management events
    RegisterNetEvent('tgw:preference:get', function(category, key)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            local value = GetPlayerPreference(xPlayer.identifier, category, key)
            TriggerClientEvent('tgw:preference:result', src, category, key, value)
        end
    end)

    RegisterNetEvent('tgw:preference:set', function(category, key, value)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            SetPlayerPreference(xPlayer.identifier, category, key, value)
        end
    end)

    RegisterNetEvent('tgw:preference:getAll', function(category)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            local preferences = GetAllPlayerPreferences(xPlayer.identifier, category)
            TriggerClientEvent('tgw:preference:allResult', src, category, preferences)
        end
    end)

    RegisterNetEvent('tgw:preference:reset', function(category)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            ResetPlayerPreferences(xPlayer.identifier, category)
        end
    end)

    RegisterNetEvent('tgw:preference:export', function()
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            ExportPlayerPreferences(xPlayer.identifier, src)
        end
    end)

    RegisterNetEvent('tgw:preference:import', function(data)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            ImportPlayerPreferences(xPlayer.identifier, data, src)
        end
    end)

    -- Player connection events
    RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
        LoadPlayerPreferences(xPlayer.identifier)
    end)

    RegisterNetEvent('esx:playerDropped', function(playerId, reason)
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            SavePlayerPreferences(xPlayer.identifier)
            CleanupPlayerData(xPlayer.identifier)
        end
    end)
end

-- =====================================================
-- PREFERENCE MANAGEMENT
-- =====================================================

function GetPlayerPreference(identifier, category, key)
    -- Check cache first
    local cacheKey = string.format('%s:%s:%s', identifier, category, key)
    if PreferenceCache[cacheKey] then
        PreferenceStats.cacheHits = PreferenceStats.cacheHits + 1
        return PreferenceCache[cacheKey].value
    end

    PreferenceStats.cacheMisses = PreferenceStats.cacheMisses + 1

    -- Load from memory
    if PlayerPreferences[identifier] and
       PlayerPreferences[identifier][category] and
       PlayerPreferences[identifier][category][key] ~= nil then
        local value = PlayerPreferences[identifier][category][key]

        -- Cache the result
        PreferenceCache[cacheKey] = {
            value = value,
            timestamp = os.time()
        }

        return value
    end

    -- Return default value
    local defaultValue = GetDefaultPreference(category, key)

    -- Cache default value
    PreferenceCache[cacheKey] = {
        value = defaultValue,
        timestamp = os.time()
    }

    return defaultValue
end

function SetPlayerPreference(identifier, category, key, value)
    -- Validate preference
    if not ValidatePreference(category, key, value) then
        print(string.format('^1[TGW-PREFERENCE ERROR]^7 Invalid preference: %s.%s = %s', category, key, tostring(value)))
        return false
    end

    -- Initialize structure if needed
    if not PlayerPreferences[identifier] then
        PlayerPreferences[identifier] = {}
    end
    if not PlayerPreferences[identifier][category] then
        PlayerPreferences[identifier][category] = {}
    end

    -- Backup old value
    local oldValue = PlayerPreferences[identifier][category][key]
    if PreferenceConfig.Persistence.backupOldValues and oldValue ~= nil then
        BackupPreferenceValue(identifier, category, key, oldValue)
    end

    -- Set new value
    PlayerPreferences[identifier][category][key] = value

    -- Update cache
    local cacheKey = string.format('%s:%s:%s', identifier, category, key)
    PreferenceCache[cacheKey] = {
        value = value,
        timestamp = os.time()
    }

    -- Queue for database save
    QueuePreferenceForSave(identifier, category, key, value)

    -- Notify other systems
    TriggerEvent('tgw:preference:changed', identifier, category, key, value, oldValue)

    print(string.format('^2[TGW-PREFERENCE]^7 Set %s.%s = %s for %s', category, key, tostring(value), identifier))

    return true
end

function GetAllPlayerPreferences(identifier, category)
    if not PlayerPreferences[identifier] then
        return {}
    end

    if category then
        return PlayerPreferences[identifier][category] or {}
    end

    return PlayerPreferences[identifier]
end

function ResetPlayerPreferences(identifier, category)
    if category then
        -- Reset specific category
        if PlayerPreferences[identifier] and PlayerPreferences[identifier][category] then
            PlayerPreferences[identifier][category] = {}

            -- Clear from database
            MySQL.execute('DELETE FROM tgw_player_preferences WHERE identifier = ? AND category = ?',
                {identifier, category})

            print(string.format('^2[TGW-PREFERENCE]^7 Reset %s preferences for %s', category, identifier))
        end
    else
        -- Reset all preferences
        PlayerPreferences[identifier] = {}

        -- Clear from database
        MySQL.execute('DELETE FROM tgw_player_preferences WHERE identifier = ?', {identifier})

        print(string.format('^2[TGW-PREFERENCE]^7 Reset all preferences for %s', identifier))
    end

    -- Clear relevant cache entries
    ClearPlayerCache(identifier, category)

    return true
end

-- =====================================================
-- DATABASE OPERATIONS
-- =====================================================

function LoadPlayerPreferences(identifier)
    MySQL.query('SELECT category, preference_key, preference_value FROM tgw_player_preferences WHERE identifier = ?',
        {identifier}, function(results)
        if results then
            PlayerPreferences[identifier] = {}

            for _, row in ipairs(results) do
                if not PlayerPreferences[identifier][row.category] then
                    PlayerPreferences[identifier][row.category] = {}
                end

                -- Parse JSON value
                local value = json.decode(row.preference_value)
                PlayerPreferences[identifier][row.category][row.preference_key] = value
            end

            PreferenceStats.totalLoaded = PreferenceStats.totalLoaded + 1
            print(string.format('^2[TGW-PREFERENCE]^7 Loaded %d preferences for %s', #results, identifier))
        else
            -- Initialize with empty preferences
            PlayerPreferences[identifier] = {}
        end
    end)
end

function SavePlayerPreferences(identifier)
    if not PlayerPreferences[identifier] then
        return
    end

    local saveCount = 0

    for category, categoryData in pairs(PlayerPreferences[identifier]) do
        for key, value in pairs(categoryData) do
            local valueJson = json.encode(value)

            MySQL.execute([[
                INSERT INTO tgw_player_preferences (identifier, category, preference_key, preference_value, updated_at)
                VALUES (?, ?, ?, ?, NOW())
                ON DUPLICATE KEY UPDATE preference_value = VALUES(preference_value), updated_at = VALUES(updated_at)
            ]], {identifier, category, key, valueJson})

            saveCount = saveCount + 1
        end
    end

    if saveCount > 0 then
        PreferenceStats.totalSaved = PreferenceStats.totalSaved + saveCount
        print(string.format('^2[TGW-PREFERENCE]^7 Saved %d preferences for %s', saveCount, identifier))
    end
end

function QueuePreferenceForSave(identifier, category, key, value)
    if not PreferenceConfig.Persistence.autoSave then
        return
    end

    local saveKey = string.format('%s:%s:%s', identifier, category, key)
    PendingSaves[saveKey] = {
        identifier = identifier,
        category = category,
        key = key,
        value = value,
        timestamp = os.time()
    }
end

function StartAutoSaveThread()
    CreateThread(function()
        while true do
            Wait(PreferenceConfig.Persistence.saveDelay)

            local currentTime = os.time()
            local toSave = {}

            -- Collect pending saves
            for saveKey, saveData in pairs(PendingSaves) do
                if currentTime - saveData.timestamp >= (PreferenceConfig.Persistence.saveDelay / 1000) then
                    table.insert(toSave, saveData)
                    PendingSaves[saveKey] = nil
                end
            end

            -- Process saves
            for _, saveData in ipairs(toSave) do
                local valueJson = json.encode(saveData.value)

                MySQL.execute([[
                    INSERT INTO tgw_player_preferences (identifier, category, preference_key, preference_value, updated_at)
                    VALUES (?, ?, ?, ?, NOW())
                    ON DUPLICATE KEY UPDATE preference_value = VALUES(preference_value), updated_at = VALUES(updated_at)
                ]], {saveData.identifier, saveData.category, saveData.key, valueJson})
            end

            if #toSave > 0 then
                PreferenceStats.totalSaved = PreferenceStats.totalSaved + #toSave
            end
        end
    end)
end

-- =====================================================
-- VALIDATION AND DEFAULTS
-- =====================================================

function ValidatePreference(category, key, value)
    -- Check if category exists
    if not PreferenceConfig.Categories[category] then
        return false
    end

    -- Get validation rules
    local validation = PreferenceConfig.Validation[category]
    if not validation then
        return true -- No validation rules
    end

    -- Type validation
    if validation.validateTypes then
        local defaultValue = GetDefaultPreference(category, key)
        if defaultValue ~= nil and type(value) ~= type(defaultValue) then
            return false
        end
    end

    -- Range validation
    if validation.validateRanges and PreferenceConfig.Ranges[key] then
        local range = PreferenceConfig.Ranges[key]
        if type(value) == 'number' then
            if value < range.min or value > range.max then
                return false
            end
        end
    end

    -- Choice validation
    if validation.validateAgainstChoices then
        local choices = GetPreferenceChoices(category, key)
        if choices then
            local valid = false
            for _, choice in ipairs(choices) do
                if choice.hash == value or choice.value == value then
                    valid = true
                    break
                end
            end
            if not valid then
                return false
            end
        end
    end

    return true
end

function GetDefaultPreference(category, key)
    if category == 'weapon' then
        return PreferenceConfig.WeaponDefaults[key]
    elseif category == 'gameplay' then
        return PreferenceConfig.GameplayDefaults[key]
    elseif category == 'hud' then
        return PreferenceConfig.HUDDefaults[key]
    elseif category == 'audio' then
        return PreferenceConfig.AudioDefaults[key]
    elseif category == 'controls' then
        return PreferenceConfig.ControlDefaults[key]
    end

    return nil
end

function GetPreferenceChoices(category, key)
    if category == 'weapon' then
        return PreferenceConfig.WeaponChoices[key]
    elseif category == 'gameplay' then
        return PreferenceConfig.GameplayChoices[key]
    elseif category == 'hud' then
        return PreferenceConfig.HUDChoices[key]
    elseif category == 'audio' then
        return PreferenceConfig.AudioChoices[key]
    elseif category == 'controls' then
        return PreferenceConfig.ControlChoices[key]
    end

    return nil
end

function InitializeDefaultPreferences()
    -- This could pre-populate default preferences in database
    print('^2[TGW-PREFERENCE]^7 Default preferences initialized')
end

-- =====================================================
-- CACHE MANAGEMENT
-- =====================================================

function ClearPlayerCache(identifier, category)
    local pattern = identifier .. ':'
    if category then
        pattern = pattern .. category .. ':'
    end

    for cacheKey, _ in pairs(PreferenceCache) do
        if string.find(cacheKey, pattern, 1, true) == 1 then
            PreferenceCache[cacheKey] = nil
        end
    end
end

function StartPerformanceMonitoring()
    CreateThread(function()
        while true do
            Wait(300000) -- Every 5 minutes

            -- Clean old cache entries
            local currentTime = os.time()
            local cacheDuration = PreferenceConfig.Persistence.cacheDuration
            local cleaned = 0

            for cacheKey, cacheData in pairs(PreferenceCache) do
                if currentTime - cacheData.timestamp > cacheDuration then
                    PreferenceCache[cacheKey] = nil
                    cleaned = cleaned + 1
                end
            end

            -- Log statistics
            print(string.format('^2[TGW-PREFERENCE STATS]^7 Loaded: %d, Saved: %d, Cache Hits: %d, Misses: %d, Cleaned: %d',
                PreferenceStats.totalLoaded,
                PreferenceStats.totalSaved,
                PreferenceStats.cacheHits,
                PreferenceStats.cacheMisses,
                cleaned
            ))
        end
    end)
end

-- =====================================================
-- IMPORT/EXPORT FUNCTIONALITY
-- =====================================================

function ExportPlayerPreferences(identifier, playerId)
    if not PreferenceConfig.ExportImport.enableExport then
        TriggerClientEvent('tgw:preference:exportResult', playerId, false, 'Export disabled')
        return
    end

    local preferences = GetAllPlayerPreferences(identifier)
    local exportData = {
        version = '1.0',
        timestamp = os.time(),
        identifier = identifier,
        preferences = preferences
    }

    local exportJson = json.encode(exportData)

    if #exportJson > PreferenceConfig.ExportImport.maxExportSize then
        TriggerClientEvent('tgw:preference:exportResult', playerId, false, 'Export too large')
        return
    end

    TriggerClientEvent('tgw:preference:exportResult', playerId, true, exportJson)
    print(string.format('^2[TGW-PREFERENCE]^7 Exported preferences for %s (%d bytes)', identifier, #exportJson))
end

function ImportPlayerPreferences(identifier, data, playerId)
    if not PreferenceConfig.ExportImport.enableImport then
        TriggerClientEvent('tgw:preference:importResult', playerId, false, 'Import disabled')
        return
    end

    local success, importData = pcall(json.decode, data)
    if not success or not importData.preferences then
        TriggerClientEvent('tgw:preference:importResult', playerId, false, 'Invalid import data')
        return
    end

    local imported = 0

    for category, categoryData in pairs(importData.preferences) do
        for key, value in pairs(categoryData) do
            if ValidatePreference(category, key, value) then
                SetPlayerPreference(identifier, category, key, value)
                imported = imported + 1
            end
        end
    end

    TriggerClientEvent('tgw:preference:importResult', playerId, true, string.format('Imported %d preferences', imported))
    print(string.format('^2[TGW-PREFERENCE]^7 Imported %d preferences for %s', imported, identifier))
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function CleanupPlayerData(identifier)
    PlayerPreferences[identifier] = nil
    ClearPlayerCache(identifier)
end

function BackupPreferenceValue(identifier, category, key, value)
    -- This could maintain a backup history
    -- For now, just log the change
    print(string.format('^3[TGW-PREFERENCE BACKUP]^7 %s.%s.%s: %s -> backing up', identifier, category, key, tostring(value)))
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('GetPlayerPreference', GetPlayerPreference)
exports('SetPlayerPreference', SetPlayerPreference)
exports('GetAllPreferences', GetAllPlayerPreferences)
exports('ResetPreferences', ResetPlayerPreferences)
exports('ValidatePreference', ValidatePreference)
exports('GetDefaultPreferences', function(category)
    if category == 'weapon' then
        return PreferenceConfig.WeaponDefaults
    elseif category == 'gameplay' then
        return PreferenceConfig.GameplayDefaults
    elseif category == 'hud' then
        return PreferenceConfig.HUDDefaults
    elseif category == 'audio' then
        return PreferenceConfig.AudioDefaults
    elseif category == 'controls' then
        return PreferenceConfig.ControlDefaults
    end
    return {}
end)

-- =====================================================
-- ADMIN COMMANDS
-- =====================================================

RegisterCommand('tgw_preference_stats', function(source, args, rawCommand)
    if source == 0 then -- Console only
        print('^2[TGW-PREFERENCE STATS]^7')
        print(string.format('  Total Loaded: %d', PreferenceStats.totalLoaded))
        print(string.format('  Total Saved: %d', PreferenceStats.totalSaved))
        print(string.format('  Cache Hits: %d', PreferenceStats.cacheHits))
        print(string.format('  Cache Misses: %d', PreferenceStats.cacheMisses))
        print(string.format('  Active Players: %d', GetActivePlayerCount()))
        print(string.format('  Pending Saves: %d', GetPendingSaveCount()))
    end
end, true)

function GetActivePlayerCount()
    local count = 0
    for _ in pairs(PlayerPreferences) do
        count = count + 1
    end
    return count
end

function GetPendingSaveCount()
    local count = 0
    for _ in pairs(PendingSaves) do
        count = count + 1
    end
    return count
end

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Save all pending preferences
        for identifier, _ in pairs(PlayerPreferences) do
            SavePlayerPreferences(identifier)
        end

        print('^2[TGW-PREFERENCE]^7 Preference system stopped, all data saved')
    end
end)