-- =====================================================
-- TGW LOADOUT CLIENT - WEAPON AND EQUIPMENT APPLICATION
-- =====================================================
-- Purpose: Apply weapons, armor, and restrictions on client side
-- Dependencies: tgw_core
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']

-- Client loadout state
local CurrentLoadout = nil
local LoadoutActive = false
local RestrictionsActive = false

-- Monitoring threads
local WeaponMonitorThread = nil
local RestrictionThread = nil

-- =====================================================
-- INITIALIZATION
-- =====================================================

CreateThread(function()
    while not ESX do
        ESX = exports['tgw_core']:GetESX()
        Wait(100)
    end

    RegisterEventHandlers()
    StartClientMonitoring()

    print('^2[TGW-LOADOUT CLIENT]^7 Loadout client system initialized')
end)

function RegisterEventHandlers()
    -- Loadout events
    RegisterNetEvent('tgw:loadout:apply', function(loadoutData)
        ApplyClientLoadout(loadoutData)
    end)

    RegisterNetEvent('tgw:loadout:remove', function()
        RemoveClientLoadout()
    end)

    RegisterNetEvent('tgw:loadout:validate', function()
        ValidateClientLoadout()
    end)

    -- Round events integration
    RegisterNetEvent('tgw:round:freezeStart', function()
        if LoadoutActive then
            EnableWeaponRestrictions(true)
        end
    end)

    RegisterNetEvent('tgw:round:started', function()
        if LoadoutActive then
            EnableWeaponRestrictions(false)
        end
    end)

    RegisterNetEvent('tgw:round:result', function()
        RemoveClientLoadout()
    end)
end

-- =====================================================
-- LOADOUT APPLICATION
-- =====================================================

function ApplyClientLoadout(loadoutData)
    print(string.format('^2[TGW-LOADOUT CLIENT]^7 Applying %s loadout', loadoutData.roundType))

    CurrentLoadout = loadoutData
    LoadoutActive = true

    -- Clear existing weapons
    if LoadoutConfig.Application.clearAllWeapons then
        RemoveAllPedWeapons(PlayerPedId(), true)
    end

    -- Set health and armor
    ApplyHealthAndArmor(loadoutData)

    -- Give weapons
    GiveLoadoutWeapons(loadoutData)

    -- Apply restrictions
    EnableWeaponRestrictions(true)

    -- Start monitoring
    StartWeaponMonitoring()

    -- Show loadout applied notification
    TGWCore.ShowTGWNotification(
        string.format('Loadout applied: %s', loadoutData.roundType:upper()),
        'info',
        3000
    )

    print(string.format('^2[TGW-LOADOUT CLIENT]^7 Loadout applied successfully: %s', loadoutData.roundType))
end

function ApplyHealthAndArmor(loadoutData)
    local playerPed = PlayerPedId()

    -- Set health
    if LoadoutConfig.Application.setMaxHealth then
        SetEntityMaxHealth(playerPed, LoadoutConfig.Health.maxHealth)
        SetEntityHealth(playerPed, LoadoutConfig.Health.startHealth)
    end

    -- Set armor
    if loadoutData.armor > 0 then
        SetPedArmour(playerPed, loadoutData.armor)
    end

    -- Apply helmet (visual only for now)
    if loadoutData.helmet then
        -- In a full implementation, this would apply a helmet component
        -- SetPedComponentVariation(playerPed, 0, helmetId, 0, 0)
    end
end

function GiveLoadoutWeapons(loadoutData)
    local playerPed = PlayerPedId()

    -- Give primary weapon
    if loadoutData.weapons.primary then
        GiveWeaponToPed(playerPed, GetHashKey(loadoutData.weapons.primary), loadoutData.ammo.primary, false, true)

        -- Apply attachments
        ApplyWeaponAttachments(loadoutData.weapons.primary, loadoutData.roundType)

        print(string.format('^2[TGW-LOADOUT CLIENT]^7 Given primary weapon: %s (%d ammo)',
            loadoutData.weapons.primary, loadoutData.ammo.primary))
    end

    -- Give secondary weapon
    if loadoutData.weapons.secondary then
        GiveWeaponToPed(playerPed, GetHashKey(loadoutData.weapons.secondary), loadoutData.ammo.secondary, false, false)

        print(string.format('^2[TGW-LOADOUT CLIENT]^7 Given secondary weapon: %s (%d ammo)',
            loadoutData.weapons.secondary, loadoutData.ammo.secondary))
    end

    -- Set current weapon to primary
    if loadoutData.weapons.primary then
        SetCurrentPedWeapon(playerPed, GetHashKey(loadoutData.weapons.primary), true)
    end
end

function ApplyWeaponAttachments(weaponHash, roundType)
    local playerPed = PlayerPedId()
    local weapon = GetHashKey(weaponHash)
    local attachments = LoadoutConfig.RoundTypes[roundType].attachments

    if attachments then
        for _, attachment in ipairs(attachments) do
            if HasPedGotWeapon(playerPed, weapon, false) then
                GiveWeaponComponentToPed(playerPed, weapon, GetHashKey(attachment))
            end
        end
    end
end

-- =====================================================
-- LOADOUT REMOVAL
-- =====================================================

function RemoveClientLoadout()
    if not LoadoutActive then
        return
    end

    print('^2[TGW-LOADOUT CLIENT]^7 Removing loadout')

    LoadoutActive = false
    CurrentLoadout = nil

    -- Stop monitoring
    StopWeaponMonitoring()

    -- Disable restrictions
    EnableWeaponRestrictions(false)

    -- Remove weapons
    RemoveAllPedWeapons(PlayerPedId(), true)

    -- Reset health and armor
    local playerPed = PlayerPedId()
    SetEntityMaxHealth(playerPed, 200) -- Default GTA health
    SetEntityHealth(playerPed, 200)
    SetPedArmour(playerPed, 0)

    TGWCore.ShowTGWNotification('Loadout removed', 'info', 2000)
end

-- =====================================================
-- WEAPON RESTRICTIONS
-- =====================================================

function EnableWeaponRestrictions(enable)
    RestrictionsActive = enable

    if enable then
        StartRestrictionThread()
    else
        StopRestrictionThread()
    end
end

function StartRestrictionThread()
    if RestrictionThread then
        return
    end

    RestrictionThread = CreateThread(function()
        while RestrictionsActive do
            Wait(LoadoutConfig.Performance.restrictionCheckInterval)

            local playerPed = PlayerPedId()

            -- Block melee attacks
            if LoadoutConfig.Restrictions.disableMelee then
                DisableControlAction(0, 140, true) -- Melee Attack Light
                DisableControlAction(0, 141, true) -- Melee Attack Heavy
                DisableControlAction(0, 142, true) -- Melee Attack Alternate
            end

            -- Block weapon drop
            if LoadoutConfig.Restrictions.blockWeaponDrop then
                DisableControlAction(0, 37, true) -- SELECT WEAPON
            end

            -- Block vehicle weapons
            if LoadoutConfig.Restrictions.disableVehicleWeapons then
                if IsPedInAnyVehicle(playerPed, false) then
                    DisableControlAction(0, 24, true) -- Attack
                    DisableControlAction(0, 25, true) -- Aim
                end
            end

            -- Prevent unauthorized weapon changes
            PreventUnauthorizedWeapons()
        end
    end)
end

function StopRestrictionThread()
    if RestrictionThread then
        RestrictionThread = nil
        RestrictionsActive = false
    end
end

function PreventUnauthorizedWeapons()
    if not CurrentLoadout then
        return
    end

    local playerPed = PlayerPedId()
    local currentWeapon = GetSelectedPedWeapon(playerPed)

    -- Check if current weapon is authorized
    local isAuthorized = false

    if currentWeapon == GetHashKey(CurrentLoadout.weapons.primary) then
        isAuthorized = true
    elseif CurrentLoadout.weapons.secondary and currentWeapon == GetHashKey(CurrentLoadout.weapons.secondary) then
        isAuthorized = true
    elseif currentWeapon == GetHashKey('WEAPON_UNARMED') then
        isAuthorized = true
    end

    if not isAuthorized then
        -- Force switch back to primary weapon
        SetCurrentPedWeapon(playerPed, GetHashKey(CurrentLoadout.weapons.primary), true)
        TGWCore.ShowTGWNotification('Unauthorized weapon removed', 'warning', 2000)
    end
end

-- =====================================================
-- WEAPON MONITORING
-- =====================================================

function StartWeaponMonitoring()
    if WeaponMonitorThread then
        return
    end

    WeaponMonitorThread = CreateThread(function()
        while LoadoutActive do
            Wait(LoadoutConfig.Performance.weaponCheckInterval)

            if CurrentLoadout then
                MonitorWeaponState()
                MonitorAmmoState()
            end
        end
    end)
end

function StopWeaponMonitoring()
    if WeaponMonitorThread then
        WeaponMonitorThread = nil
    end
end

function MonitorWeaponState()
    local playerPed = PlayerPedId()

    -- Ensure player has required weapons
    if CurrentLoadout.weapons.primary then
        local primaryHash = GetHashKey(CurrentLoadout.weapons.primary)
        if not HasPedGotWeapon(playerPed, primaryHash, false) then
            GiveWeaponToPed(playerPed, primaryHash, CurrentLoadout.ammo.primary, false, true)
            print('^3[TGW-LOADOUT CLIENT]^7 Restored primary weapon')
        end
    end

    if CurrentLoadout.weapons.secondary then
        local secondaryHash = GetHashKey(CurrentLoadout.weapons.secondary)
        if not HasPedGotWeapon(playerPed, secondaryHash, false) then
            GiveWeaponToPed(playerPed, secondaryHash, CurrentLoadout.ammo.secondary, false, false)
            print('^3[TGW-LOADOUT CLIENT]^7 Restored secondary weapon')
        end
    end
end

function MonitorAmmoState()
    -- This could monitor ammo and prevent unlimited ammo exploits
    -- For now, we trust the initial ammo allocation
end

-- =====================================================
-- VALIDATION
-- =====================================================

function ValidateClientLoadout()
    if not LoadoutActive or not CurrentLoadout then
        TriggerServerEvent('tgw:loadout:validationResult', false, 'No active loadout')
        return
    end

    local playerPed = PlayerPedId()
    local isValid = true
    local issues = {}

    -- Check primary weapon
    if CurrentLoadout.weapons.primary then
        local primaryHash = GetHashKey(CurrentLoadout.weapons.primary)
        if not HasPedGotWeapon(playerPed, primaryHash, false) then
            isValid = false
            table.insert(issues, 'Missing primary weapon')
        end
    end

    -- Check secondary weapon
    if CurrentLoadout.weapons.secondary then
        local secondaryHash = GetHashKey(CurrentLoadout.weapons.secondary)
        if not HasPedGotWeapon(playerPed, secondaryHash, false) then
            isValid = false
            table.insert(issues, 'Missing secondary weapon')
        end
    end

    -- Check armor
    local currentArmor = GetPedArmour(playerPed)
    if currentArmor < CurrentLoadout.armor * 0.5 then -- Allow some armor loss
        table.insert(issues, 'Low armor')
    end

    TriggerServerEvent('tgw:loadout:validationResult', isValid, table.concat(issues, ', '))
end

-- =====================================================
-- CLIENT MONITORING
-- =====================================================

function StartClientMonitoring()
    CreateThread(function()
        while true do
            Wait(60000) -- Every minute

            if LoadoutActive then
                -- Send heartbeat to server
                TriggerServerEvent('tgw:loadout:heartbeat', CurrentLoadout.roundType)
            end
        end
    end)
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function GetCurrentLoadout()
    return CurrentLoadout
end

function IsLoadoutActive()
    return LoadoutActive
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('GetCurrentLoadout', GetCurrentLoadout)
exports('IsLoadoutActive', IsLoadoutActive)

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        RemoveClientLoadout()
    end
end)