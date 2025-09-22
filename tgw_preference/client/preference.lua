-- =====================================================
-- TGW PREFERENCE CLIENT - PREFERENCE UI AND MANAGEMENT
-- =====================================================
-- Purpose: Handle client-side preference management and UI
-- Dependencies: tgw_core
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']

-- Client preference state
local LocalPreferences = {}        -- Cached preferences
local PreferenceMenuOpen = false
local PendingChanges = {}         -- Changes not yet applied

-- UI state
local CurrentCategory = 'weapon'
local MenuElements = {}

-- =====================================================
-- INITIALIZATION
-- =====================================================

CreateThread(function()
    while not ESX do
        ESX = exports['tgw_core']:GetESX()
        Wait(100)
    end

    RegisterEventHandlers()
    RegisterCommands()
    LoadInitialPreferences()

    print('^2[TGW-PREFERENCE CLIENT]^7 Preference client system initialized')
end)

function RegisterEventHandlers()
    -- Preference results
    RegisterNetEvent('tgw:preference:result', function(category, key, value)
        if not LocalPreferences[category] then
            LocalPreferences[category] = {}
        end
        LocalPreferences[category][key] = value
    end)

    RegisterNetEvent('tgw:preference:allResult', function(category, preferences)
        LocalPreferences[category] = preferences
        if PreferenceMenuOpen and CurrentCategory == category then
            RefreshPreferenceMenu()
        end
    end)

    -- Import/Export results
    RegisterNetEvent('tgw:preference:exportResult', function(success, data)
        if success then
            -- Copy to clipboard or save to file
            TGWCore.ShowTGWNotification('Preferences exported to clipboard', 'success', 3000)
            -- In a full implementation, this would copy to clipboard
        else
            TGWCore.ShowTGWNotification('Export failed: ' .. (data or 'Unknown error'), 'error', 3000)
        end
    end)

    RegisterNetEvent('tgw:preference:importResult', function(success, message)
        if success then
            TGWCore.ShowTGWNotification(message, 'success', 3000)
            LoadInitialPreferences() -- Refresh local cache
        else
            TGWCore.ShowTGWNotification('Import failed: ' .. message, 'error', 3000)
        end
    end)

    -- Game state events
    RegisterNetEvent('tgw:queue:joined', function()
        -- Cache important preferences for quick access
        CacheImportantPreferences()
    end)

    RegisterNetEvent('tgw:round:freezeStart', function()
        -- Close preference menu during active gameplay
        if PreferenceMenuOpen then
            ClosePreferenceMenu()
        end
    end)
end

function RegisterCommands()
    -- Main preference command
    RegisterCommand(PreferenceConfig.UI.menuCommand, function(source, args, rawCommand)
        if CanAccessPreferenceMenu() then
            if args[1] then
                OpenPreferenceMenu(args[1])
            else
                OpenPreferenceMenu()
            end
        else
            TGWCore.ShowTGWNotification('Cannot access preferences right now', 'warning', 2000)
        end
    end, false)

    -- Quick weapon preference commands
    RegisterCommand('tgw_weapon_rifle', function(source, args, rawCommand)
        if args[1] then
            QuickSetWeaponPreference('rifle', args[1])
        else
            ShowWeaponChoices('rifle')
        end
    end, false)

    RegisterCommand('tgw_weapon_pistol', function(source, args, rawCommand)
        if args[1] then
            QuickSetWeaponPreference('pistol', args[1])
        else
            ShowWeaponChoices('pistol')
        end
    end, false)

    RegisterCommand('tgw_weapon_sniper', function(source, args, rawCommand)
        if args[1] then
            QuickSetWeaponPreference('sniper', args[1])
        else
            ShowWeaponChoices('sniper')
        end
    end, false)
end

-- =====================================================
-- PREFERENCE ACCESS
-- =====================================================

function GetPreference(category, key)
    if LocalPreferences[category] and LocalPreferences[category][key] ~= nil then
        return LocalPreferences[category][key]
    end

    -- Request from server
    TriggerServerEvent('tgw:preference:get', category, key)

    -- Return default while waiting
    return GetDefaultPreference(category, key)
end

function SetPreference(category, key, value)
    -- Validate locally first
    if not ValidatePreferenceLocally(category, key, value) then
        TGWCore.ShowTGWNotification('Invalid preference value', 'error', 2000)
        return false
    end

    -- Update local cache immediately
    if not LocalPreferences[category] then
        LocalPreferences[category] = {}
    end
    LocalPreferences[category][key] = value

    -- Send to server
    TriggerServerEvent('tgw:preference:set', category, key, value)

    -- Apply immediately if configured
    if PreferenceConfig.UI.applyChangesImmediately then
        ApplyPreferenceChange(category, key, value)
    end

    TGWCore.ShowTGWNotification(string.format('%s preference updated', category:gsub('^%l', string.upper)), 'success', 2000)
    return true
end

function ApplyPreferenceChange(category, key, value)
    -- Apply preference changes that affect immediate gameplay
    if category == 'hud' then
        ApplyHUDPreference(key, value)
    elseif category == 'audio' then
        ApplyAudioPreference(key, value)
    elseif category == 'controls' then
        ApplyControlPreference(key, value)
    end

    -- Trigger event for other systems
    TriggerEvent('tgw:preference:applied', category, key, value)
end

-- =====================================================
-- PREFERENCE MENU SYSTEM
-- =====================================================

function OpenPreferenceMenu(category)
    if PreferenceMenuOpen then
        ClosePreferenceMenu()
        return
    end

    if category then
        CurrentCategory = category
    end

    PreferenceMenuOpen = true

    -- Load current category data
    TriggerServerEvent('tgw:preference:getAll', CurrentCategory)

    -- Build menu
    BuildPreferenceMenu()

    print(string.format('^2[TGW-PREFERENCE CLIENT]^7 Opened preference menu: %s', CurrentCategory))
end

function ClosePreferenceMenu()
    if not PreferenceMenuOpen then
        return
    end

    PreferenceMenuOpen = false
    MenuElements = {}

    -- Close ESX menu if using ESX menus
    ESX.UI.Menu.CloseAll()

    print('^2[TGW-PREFERENCE CLIENT]^7 Closed preference menu')
end

function BuildPreferenceMenu()
    MenuElements = {}

    -- Category selection
    if PreferenceConfig.UI.categoryTabs then
        for categoryKey, categoryData in pairs(PreferenceConfig.Categories) do
            table.insert(MenuElements, {
                label = categoryData.name,
                value = categoryKey,
                description = categoryData.description,
                selected = categoryKey == CurrentCategory
            })
        end
    end

    -- Current category preferences
    BuildCategoryMenu(CurrentCategory)

    -- Open ESX menu (simplified version)
    OpenESXPreferenceMenu()
end

function BuildCategoryMenu(category)
    if category == 'weapon' then
        BuildWeaponPreferenceMenu()
    elseif category == 'gameplay' then
        BuildGameplayPreferenceMenu()
    elseif category == 'hud' then
        BuildHUDPreferenceMenu()
    elseif category == 'audio' then
        BuildAudioPreferenceMenu()
    elseif category == 'controls' then
        BuildControlPreferenceMenu()
    end
end

function BuildWeaponPreferenceMenu()
    local elements = {}

    for roundType, choices in pairs(PreferenceConfig.WeaponChoices) do
        local currentChoice = GetPreference('weapon', roundType)
        local currentWeaponName = 'Default'

        -- Find current weapon name
        for _, choice in ipairs(choices) do
            if choice.hash == currentChoice then
                currentWeaponName = choice.name
                break
            end
        end

        table.insert(elements, {
            label = string.format('%s: %s', roundType:gsub('^%l', string.upper), currentWeaponName),
            value = roundType,
            type = 'weapon_choice',
            choices = choices,
            current = currentChoice
        })
    end

    MenuElements = elements
end

function BuildGameplayPreferenceMenu()
    local elements = {}

    for key, value in pairs(PreferenceConfig.GameplayDefaults) do
        local currentValue = GetPreference('gameplay', key)
        local displayValue = tostring(currentValue)

        if type(currentValue) == 'boolean' then
            displayValue = currentValue and 'Enabled' or 'Disabled'
        end

        table.insert(elements, {
            label = string.format('%s: %s', key:gsub('([A-Z])', ' %1'), displayValue),
            value = key,
            type = 'gameplay_setting',
            current = currentValue
        })
    end

    MenuElements = elements
end

function BuildHUDPreferenceMenu()
    -- Similar to gameplay but for HUD settings
    local elements = {}

    for key, value in pairs(PreferenceConfig.HUDDefaults) do
        local currentValue = GetPreference('hud', key)
        local displayValue = tostring(currentValue)

        table.insert(elements, {
            label = string.format('%s: %s', key:gsub('([A-Z])', ' %1'), displayValue),
            value = key,
            type = 'hud_setting',
            current = currentValue
        })
    end

    MenuElements = elements
end

function BuildAudioPreferenceMenu()
    -- Audio settings with volume sliders
    local elements = {}

    for key, value in pairs(PreferenceConfig.AudioDefaults) do
        local currentValue = GetPreference('audio', key)
        local displayValue = tostring(currentValue)

        if type(currentValue) == 'number' and currentValue <= 1.0 then
            displayValue = string.format('%.0f%%', currentValue * 100)
        end

        table.insert(elements, {
            label = string.format('%s: %s', key:gsub('([A-Z])', ' %1'), displayValue),
            value = key,
            type = 'audio_setting',
            current = currentValue
        })
    end

    MenuElements = elements
end

function BuildControlPreferenceMenu()
    -- Control and sensitivity settings
    local elements = {}

    for key, value in pairs(PreferenceConfig.ControlDefaults) do
        local currentValue = GetPreference('controls', key)
        local displayValue = tostring(currentValue)

        table.insert(elements, {
            label = string.format('%s: %s', key:gsub('([A-Z])', ' %1'), displayValue),
            value = key,
            type = 'control_setting',
            current = currentValue
        })
    end

    MenuElements = elements
end

-- =====================================================
-- ESX MENU INTEGRATION
-- =====================================================

function OpenESXPreferenceMenu()
    -- Simplified ESX menu integration
    local elements = {}

    -- Add category tabs if enabled
    if PreferenceConfig.UI.categoryTabs then
        for categoryKey, categoryData in pairs(PreferenceConfig.Categories) do
            local selected = categoryKey == CurrentCategory
            table.insert(elements, {
                label = (selected and '>>> ' or '') .. categoryData.name .. (selected and ' <<<' or ''),
                value = 'category_' .. categoryKey
            })
        end

        table.insert(elements, {label = '─────────────────'})
    end

    -- Add current category elements
    for _, element in ipairs(MenuElements) do
        table.insert(elements, element)
    end

    -- Add menu actions
    table.insert(elements, {label = '─────────────────'})
    table.insert(elements, {label = 'Export Preferences', value = 'export'})
    table.insert(elements, {label = 'Import Preferences', value = 'import'})
    table.insert(elements, {label = 'Reset Category', value = 'reset'})

    ESX.UI.Menu.Open('default', GetCurrentResourceName(), 'tgw_preferences', {
        title = 'TGW Preferences - ' .. CurrentCategory:gsub('^%l', string.upper),
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        HandleMenuSelection(data, menu)
    end, function(data, menu)
        ClosePreferenceMenu()
    end)
end

function HandleMenuSelection(data, menu)
    local value = data.current.value

    if string.find(value, 'category_') then
        -- Category change
        local newCategory = string.gsub(value, 'category_', '')
        CurrentCategory = newCategory
        TriggerServerEvent('tgw:preference:getAll', CurrentCategory)
        BuildPreferenceMenu()

    elseif value == 'export' then
        TriggerServerEvent('tgw:preference:export')

    elseif value == 'import' then
        -- This would open an import dialog
        TGWCore.ShowTGWNotification('Import feature coming soon', 'info', 2000)

    elseif value == 'reset' then
        TriggerServerEvent('tgw:preference:reset', CurrentCategory)
        TGWCore.ShowTGWNotification('Category preferences reset', 'success', 2000)

    else
        -- Handle preference change
        HandlePreferenceChange(data.current)
    end
end

function HandlePreferenceChange(element)
    if element.type == 'weapon_choice' then
        -- Cycle through weapon choices
        local choices = element.choices
        local currentIndex = 1

        for i, choice in ipairs(choices) do
            if choice.hash == element.current then
                currentIndex = i
                break
            end
        end

        local nextIndex = (currentIndex % #choices) + 1
        local newWeapon = choices[nextIndex].hash

        SetPreference('weapon', element.value, newWeapon)

    elseif element.type == 'gameplay_setting' or element.type == 'hud_setting' or element.type == 'audio_setting' or element.type == 'control_setting' then
        -- Toggle boolean or cycle through values
        local category = element.type:gsub('_setting', '')
        local currentValue = element.current

        if type(currentValue) == 'boolean' then
            SetPreference(category, element.value, not currentValue)
        else
            -- For other types, would need more sophisticated input handling
            TGWCore.ShowTGWNotification('Use console commands for advanced settings', 'info', 2000)
        end
    end

    -- Refresh menu
    Wait(100)
    BuildPreferenceMenu()
end

-- =====================================================
-- QUICK ACCESS FUNCTIONS
-- =====================================================

function QuickSetWeaponPreference(roundType, weaponChoice)
    local choices = PreferenceConfig.WeaponChoices[roundType]
    if not choices then
        TGWCore.ShowTGWNotification('Invalid round type', 'error', 2000)
        return
    end

    local foundWeapon = nil
    for _, choice in ipairs(choices) do
        if choice.hash:lower():find(weaponChoice:lower()) or choice.name:lower():find(weaponChoice:lower()) then
            foundWeapon = choice.hash
            break
        end
    end

    if foundWeapon then
        SetPreference('weapon', roundType, foundWeapon)
    else
        TGWCore.ShowTGWNotification('Weapon not found', 'error', 2000)
        ShowWeaponChoices(roundType)
    end
end

function ShowWeaponChoices(roundType)
    local choices = PreferenceConfig.WeaponChoices[roundType]
    if choices then
        local choiceText = string.format('%s weapons:', roundType:gsub('^%l', string.upper))
        for _, choice in ipairs(choices) do
            choiceText = choiceText .. string.format('\n  %s - %s', choice.name, choice.description)
        end
        TGWCore.ShowTGWNotification(choiceText, 'info', 5000)
    end
end

function CacheImportantPreferences()
    -- Cache preferences that are frequently accessed during gameplay
    local importantPrefs = {
        {'weapon', 'rifle'},
        {'weapon', 'pistol'},
        {'weapon', 'sniper'},
        {'hud', 'hudOpacity'},
        {'hud', 'showOpponentInfo'},
        {'audio', 'masterVolume'},
        {'gameplay', 'spectateMode'}
    }

    for _, pref in ipairs(importantPrefs) do
        GetPreference(pref[1], pref[2])
    end
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function CanAccessPreferenceMenu()
    -- Check if player can access preference menu based on current state
    local roundExport = exports['tgw_round']
    local queueExport = exports['tgw_queue']

    if roundExport and roundExport:IsInRound() then
        return PreferenceConfig.MenuAccess.duringMatch
    end

    if roundExport and roundExport:IsInFreeze() then
        return PreferenceConfig.MenuAccess.duringFreezePhase
    end

    if queueExport and queueExport:IsInQueue() then
        return PreferenceConfig.MenuAccess.duringQueue
    end

    return true
end

function ValidatePreferenceLocally(category, key, value)
    -- Basic client-side validation
    if not PreferenceConfig.Categories[category] then
        return false
    end

    -- Check ranges
    if PreferenceConfig.Ranges[key] then
        local range = PreferenceConfig.Ranges[key]
        if type(value) == 'number' then
            return value >= range.min and value <= range.max
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

function LoadInitialPreferences()
    -- Load commonly used preferences
    for category, _ in pairs(PreferenceConfig.Categories) do
        TriggerServerEvent('tgw:preference:getAll', category)
    end
end

function RefreshPreferenceMenu()
    if PreferenceMenuOpen then
        ESX.UI.Menu.CloseAll()
        BuildPreferenceMenu()
    end
end

-- =====================================================
-- PREFERENCE APPLICATION
-- =====================================================

function ApplyHUDPreference(key, value)
    if key == 'hudOpacity' then
        -- Apply HUD opacity changes
        TriggerEvent('tgw:hud:setOpacity', value)
    elseif key == 'showMinimap' then
        -- Toggle minimap display
        DisplayRadar(value)
    end
end

function ApplyAudioPreference(key, value)
    if key == 'masterVolume' then
        -- Apply master volume changes
        SetAudioFlag('LoadMPData', value > 0)
    end
end

function ApplyControlPreference(key, value)
    if key == 'mouseSensitivity' then
        -- Apply mouse sensitivity changes
        -- This would require native calls or client-side sensitivity handling
    end
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('GetPreference', GetPreference)
exports('SetPreference', SetPreference)
exports('OpenPreferenceMenu', OpenPreferenceMenu)
exports('GetLocalPreferences', function()
    return LocalPreferences
end)

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if PreferenceMenuOpen then
            ClosePreferenceMenu()
        end
    end
end)