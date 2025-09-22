-- =====================================================
-- TGW LOADOUT SERVER - WEAPON AND EQUIPMENT MANAGER
-- =====================================================
-- Purpose: Manage weapon loadouts, armor, and equipment for rounds
-- Dependencies: tgw_core, tgw_round, es_extended
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']

-- Loadout state management
local ActiveLoadouts = {}  -- [identifier] = loadoutData
local PlayerPreferences = {} -- [identifier] = {rifle = 'WEAPON_X', pistol = 'WEAPON_Y', sniper = 'WEAPON_Z'}

-- Performance tracking
local LoadoutStats = {
    totalApplied = 0,
    totalRemoved = 0,
    errors = 0
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
    LoadPlayerPreferences()
    StartPerformanceMonitoring()

    print('^2[TGW-LOADOUT SERVER]^7 Loadout management system initialized')
end)

function RegisterEventHandlers()
    -- Loadout application events
    RegisterNetEvent('tgw:loadout:apply', function(identifier, roundType, weaponPreference)
        ApplyLoadout(identifier, roundType, weaponPreference)
    end)

    RegisterNetEvent('tgw:loadout:remove', function(identifier)
        RemoveLoadout(identifier)
    end)

    -- Preference management
    RegisterNetEvent('tgw:loadout:updatePreference', function(identifier, roundType, weaponHash)
        UpdatePlayerPreference(identifier, roundType, weaponHash)
    end)

    -- Round events integration
    RegisterNetEvent('tgw:round:playerSpawned', function(identifier, roundType)
        local preference = GetPlayerPreference(identifier, roundType)
        ApplyLoadout(identifier, roundType, preference)
    end)

    RegisterNetEvent('tgw:round:ended', function(matchData)
        -- Remove loadouts for both players
        for _, playerData in pairs(matchData.players) do
            RemoveLoadout(playerData.identifier)
        end
    end)

    -- Player disconnect cleanup
    RegisterNetEvent('esx:playerDropped', function(playerId, reason)
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            CleanupPlayerLoadout(xPlayer.identifier)
        end
    end)
end

-- =====================================================
-- LOADOUT APPLICATION
-- =====================================================

function ApplyLoadout(identifier, roundType, weaponPreference)
    local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)
    if not playerId then
        print(string.format('^1[TGW-LOADOUT ERROR]^7 Player not found: %s', identifier))
        return false
    end

    local loadoutConfig = LoadoutConfig.RoundTypes[roundType]
    if not loadoutConfig then
        print(string.format('^1[TGW-LOADOUT ERROR]^7 Invalid round type: %s', roundType))
        return false
    end

    print(string.format('^2[TGW-LOADOUT]^7 Applying %s loadout to %s', roundType, identifier))

    -- Validate and select weapons
    local selectedWeapons = SelectWeapons(loadoutConfig, weaponPreference)
    if not selectedWeapons then
        print(string.format('^1[TGW-LOADOUT ERROR]^7 Failed to select weapons for %s', identifier))
        return false
    end

    -- Create loadout data
    local loadoutData = {
        identifier = identifier,
        roundType = roundType,
        weapons = selectedWeapons,
        armor = loadoutConfig.armor,
        helmet = loadoutConfig.helmet,
        ammo = loadoutConfig.ammo,
        appliedAt = os.time()
    }

    -- Store active loadout
    ActiveLoadouts[identifier] = loadoutData

    -- Apply to client
    TriggerClientEvent('tgw:loadout:apply', playerId, loadoutData)

    -- Update statistics
    LoadoutStats.totalApplied = LoadoutStats.totalApplied + 1

    -- Log loadout application
    if LoadoutConfig.Performance.enableWeaponLogging then
        LogLoadoutEvent(identifier, 'APPLIED', roundType, selectedWeapons)
    end

    return true
end

function SelectWeapons(loadoutConfig, weaponPreference)
    local selectedWeapons = {}

    -- Select primary weapon
    if weaponPreference and IsValidWeapon(weaponPreference, loadoutConfig.weapons.primary) then
        selectedWeapons.primary = weaponPreference
    else
        -- Use first weapon as default
        selectedWeapons.primary = loadoutConfig.weapons.primary[1]
    end

    -- Select secondary weapon (if any)
    if loadoutConfig.weapons.secondary then
        selectedWeapons.secondary = loadoutConfig.weapons.secondary
    end

    -- Validate weapons exist
    if LoadoutConfig.Validation.checkWeaponExists then
        if not DoesWeaponExist(selectedWeapons.primary) then
            print(string.format('^1[TGW-LOADOUT ERROR]^7 Primary weapon does not exist: %s', selectedWeapons.primary))
            return nil
        end

        if selectedWeapons.secondary and not DoesWeaponExist(selectedWeapons.secondary) then
            print(string.format('^1[TGW-LOADOUT ERROR]^7 Secondary weapon does not exist: %s', selectedWeapons.secondary))
            return nil
        end
    end

    return selectedWeapons
end

function IsValidWeapon(weaponHash, allowedWeapons)
    for _, weapon in ipairs(allowedWeapons) do
        if weapon == weaponHash then
            return true
        end
    end
    return false
end

function DoesWeaponExist(weaponHash)
    -- This would be more sophisticated in production
    -- For now, assume all configured weapons exist
    return true
end

-- =====================================================
-- LOADOUT REMOVAL
-- =====================================================

function RemoveLoadout(identifier)
    local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)
    if not playerId then
        return false
    end

    print(string.format('^2[TGW-LOADOUT]^7 Removing loadout from %s', identifier))

    -- Remove from active loadouts
    if ActiveLoadouts[identifier] then
        -- Log removal
        if LoadoutConfig.Performance.enableWeaponLogging then
            LogLoadoutEvent(identifier, 'REMOVED', ActiveLoadouts[identifier].roundType, ActiveLoadouts[identifier].weapons)
        end

        ActiveLoadouts[identifier] = nil
    end

    -- Trigger client removal
    TriggerClientEvent('tgw:loadout:remove', playerId)

    -- Update statistics
    LoadoutStats.totalRemoved = LoadoutStats.totalRemoved + 1

    return true
end

function CleanupPlayerLoadout(identifier)
    if ActiveLoadouts[identifier] then
        print(string.format('^3[TGW-LOADOUT]^7 Cleaning up loadout for disconnected player: %s', identifier))
        ActiveLoadouts[identifier] = nil
    end
end

-- =====================================================
-- PREFERENCE MANAGEMENT
-- =====================================================

function UpdatePlayerPreference(identifier, roundType, weaponHash)
    if not PlayerPreferences[identifier] then
        PlayerPreferences[identifier] = {}
    end

    -- Validate weapon choice
    local loadoutConfig = LoadoutConfig.RoundTypes[roundType]
    if not loadoutConfig or not IsValidWeapon(weaponHash, loadoutConfig.weapons.primary) then
        print(string.format('^1[TGW-LOADOUT ERROR]^7 Invalid weapon preference: %s for %s', weaponHash, roundType))
        return false
    end

    PlayerPreferences[identifier][roundType] = weaponHash

    -- Save to database
    SavePlayerPreference(identifier, roundType, weaponHash)

    print(string.format('^2[TGW-LOADOUT]^7 Updated %s preference for %s: %s', roundType, identifier, weaponHash))

    return true
end

function GetPlayerPreference(identifier, roundType)
    if PlayerPreferences[identifier] and PlayerPreferences[identifier][roundType] then
        return PlayerPreferences[identifier][roundType]
    end

    -- Return default preference
    return LoadoutConfig.DefaultPreferences[roundType]
end

function SavePlayerPreference(identifier, roundType, weaponHash)
    local query = [[
        INSERT INTO tgw_loadout_preferences (identifier, round_type, weapon_hash, updated_at)
        VALUES (?, ?, ?, NOW())
        ON DUPLICATE KEY UPDATE weapon_hash = VALUES(weapon_hash), updated_at = VALUES(updated_at)
    ]]

    MySQL.execute(query, {identifier, roundType, weaponHash}, function(affectedRows)
        if affectedRows > 0 then
            print(string.format('^2[TGW-LOADOUT]^7 Saved preference to database: %s/%s/%s', identifier, roundType, weaponHash))
        end
    end)
end

function LoadPlayerPreferences()
    MySQL.query('SELECT identifier, round_type, weapon_hash FROM tgw_loadout_preferences', {}, function(results)
        if results then
            for _, row in ipairs(results) do
                if not PlayerPreferences[row.identifier] then
                    PlayerPreferences[row.identifier] = {}
                end
                PlayerPreferences[row.identifier][row.round_type] = row.weapon_hash
            end
            print(string.format('^2[TGW-LOADOUT]^7 Loaded %d player preferences from database', #results))
        end
    end)
end

-- =====================================================
-- VALIDATION AND MONITORING
-- =====================================================

function ValidateLoadout(identifier)
    local loadoutData = ActiveLoadouts[identifier]
    if not loadoutData then
        return false, 'No active loadout'
    end

    local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)
    if not playerId then
        return false, 'Player not found'
    end

    -- This would trigger client-side validation
    TriggerClientEvent('tgw:loadout:validate', playerId)

    return true, 'Validation triggered'
end

function StartPerformanceMonitoring()
    CreateThread(function()
        while true do
            Wait(300000) -- Every 5 minutes

            -- Log performance statistics
            print(string.format('^2[TGW-LOADOUT STATS]^7 Applied: %d, Removed: %d, Errors: %d, Active: %d',
                LoadoutStats.totalApplied,
                LoadoutStats.totalRemoved,
                LoadoutStats.errors,
                GetActiveLoadoutCount()
            ))

            -- Cleanup stale loadouts (older than 1 hour)
            CleanupStaleLoadouts()
        end
    end)
end

function GetActiveLoadoutCount()
    local count = 0
    for _ in pairs(ActiveLoadouts) do
        count = count + 1
    end
    return count
end

function CleanupStaleLoadouts()
    local currentTime = os.time()
    local staleThreshold = 3600 -- 1 hour

    for identifier, loadoutData in pairs(ActiveLoadouts) do
        if currentTime - loadoutData.appliedAt > staleThreshold then
            print(string.format('^3[TGW-LOADOUT]^7 Cleaning up stale loadout: %s', identifier))
            ActiveLoadouts[identifier] = nil
        end
    end
end

function LogLoadoutEvent(identifier, action, roundType, weapons)
    local weaponStr = weapons.primary
    if weapons.secondary then
        weaponStr = weaponStr .. ', ' .. weapons.secondary
    end

    print(string.format('^2[TGW-LOADOUT LOG]^7 %s - %s - %s - [%s]', action, identifier, roundType, weaponStr))

    -- This could be enhanced to write to a log file or database
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('ApplyLoadout', ApplyLoadout)
exports('RemoveLoadout', RemoveLoadout)
exports('GetLoadoutConfig', function(roundType)
    return LoadoutConfig.RoundTypes[roundType]
end)
exports('ValidateLoadout', ValidateLoadout)
exports('GetPlayerLoadout', function(identifier)
    return ActiveLoadouts[identifier]
end)
exports('SetPlayerPreference', UpdatePlayerPreference)
exports('GetPlayerPreference', GetPlayerPreference)

-- =====================================================
-- ADMIN COMMANDS
-- =====================================================

RegisterCommand('tgw_loadout_stats', function(source, args, rawCommand)
    if source == 0 then -- Console only
        print('^2[TGW-LOADOUT STATS]^7')
        print(string.format('  Applied: %d', LoadoutStats.totalApplied))
        print(string.format('  Removed: %d', LoadoutStats.totalRemoved))
        print(string.format('  Errors: %d', LoadoutStats.errors))
        print(string.format('  Active: %d', GetActiveLoadoutCount()))
        print('  Active Loadouts:')
        for identifier, loadoutData in pairs(ActiveLoadouts) do
            print(string.format('    %s: %s (%s)', identifier, loadoutData.roundType, loadoutData.weapons.primary))
        end
    end
end, true)

RegisterCommand('tgw_loadout_clear', function(source, args, rawCommand)
    if source == 0 and args[1] then -- Console only
        local identifier = args[1]
        if ActiveLoadouts[identifier] then
            RemoveLoadout(identifier)
            print(string.format('^2[TGW-LOADOUT]^7 Cleared loadout for: %s', identifier))
        else
            print(string.format('^1[TGW-LOADOUT]^7 No active loadout for: %s', identifier))
        end
    end
end, true)

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Clear all active loadouts
        for identifier, _ in pairs(ActiveLoadouts) do
            RemoveLoadout(identifier)
        end

        print('^2[TGW-LOADOUT]^7 Loadout system stopped, all loadouts cleared')
    end
end)