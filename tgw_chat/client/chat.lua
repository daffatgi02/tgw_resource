-- =====================================================
-- TGW CHAT CLIENT - ARENA-SPECIFIC CHAT UI
-- =====================================================
-- Purpose: Handle arena-specific chat display and input
-- Dependencies: tgw_core
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']

-- Chat client state
local ChatMessages = {}            -- Array of displayed messages
local ChatInput = ''               -- Current input text
local ChatInputActive = false      -- Is chat input active
local CurrentChannel = 'arena'     -- Current chat channel
local PlayerMuted = false          -- Is player muted
local MuteInfo = nil               -- Mute information

-- Display settings
local ShowChat = true
local ChatOpacity = 1.0
local MessageDisplayTime = ChatConfig.Display.messageDisplayTime or 8000

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
    RegisterKeybinds()
    StartChatSystem()

    print('^2[TGW-CHAT CLIENT]^7 Arena-specific chat client initialized')
end)

function RegisterEventHandlers()
    -- Chat message events
    RegisterNetEvent('tgw:chat:receiveMessage', function(messageData)
        ReceiveMessage(messageData)
    end)

    RegisterNetEvent('tgw:chat:error', function(errorMessage)
        ShowChatError(errorMessage)
    end)

    RegisterNetEvent('tgw:chat:warning', function(warningData)
        ShowChatWarning(warningData)
    end)

    RegisterNetEvent('tgw:chat:muted', function(muteData)
        HandlePlayerMuted(muteData)
    end)

    RegisterNetEvent('tgw:chat:unmuted', function()
        HandlePlayerUnmuted()
    end)

    RegisterNetEvent('tgw:chat:historyData', function(historyData)
        LoadChatHistory(historyData)
    end)

    -- Game state events
    RegisterNetEvent('tgw:arena:joined', function(arenaId)
        -- Clear chat and request history for new arena
        ClearChatMessages()
        RequestChatHistory(arenaId)
        CurrentChannel = 'arena'
    end)

    RegisterNetEvent('tgw:arena:left', function()
        -- Clear arena chat when leaving
        ClearChatMessages()
        CurrentChannel = 'system'
    end)

    RegisterNetEvent('tgw:round:freezeStart', function()
        if ChatConfig.ArenaIntegration.disableChatDuringFreezePhase then
            DisableChatInput()
        end
    end)

    RegisterNetEvent('tgw:round:started', function()
        EnableChatInput()
    end)
end

function RegisterCommands()
    -- Main chat command
    RegisterCommand(ChatConfig.Commands.chatCommand or 'say', function(source, args, rawCommand)
        if #args > 0 then
            local message = table.concat(args, ' ')
            SendChatMessage(message, CurrentChannel)
        else
            ActivateChatInput()
        end
    end, false)

    -- Arena chat shortcut
    RegisterCommand(ChatConfig.Commands.arenaCommand or 'a', function(source, args, rawCommand)
        if #args > 0 then
            local message = table.concat(args, ' ')
            SendChatMessage(message, 'arena')
        else
            ActivateChatInput('arena')
        end
    end, false)

    -- Spectator chat shortcut
    RegisterCommand(ChatConfig.Commands.spectatorCommand or 's', function(source, args, rawCommand)
        if #args > 0 then
            local message = table.concat(args, ' ')
            SendChatMessage(message, 'spectator')
        else
            ActivateChatInput('spectator')
        end
    end, false)

    -- Clear chat command
    RegisterCommand(ChatConfig.Commands.clearCommand or 'clear', function(source, args, rawCommand)
        ClearChatMessages()
        TGWCore.ShowTGWNotification('Chat cleared', 'info', 2000)
    end, false)

    -- Chat history command
    RegisterCommand(ChatConfig.Commands.historyCommand or 'history', function(source, args, rawCommand)
        local arenaId = GetCurrentArena()
        if arenaId then
            RequestChatHistory(arenaId)
        end
    end, false)

    -- Toggle chat visibility
    RegisterCommand('toggle_chat', function(source, args, rawCommand)
        ShowChat = not ShowChat
        TGWCore.ShowTGWNotification(
            string.format('Chat %s', ShowChat and 'enabled' or 'disabled'),
            'info',
            2000
        )
    end, false)
end

function RegisterKeybinds()
    -- Open chat keybind
    RegisterKeyMapping('open_chat', 'Open Chat', 'keyboard', ChatConfig.Keybinds.openChatKey or 'T')

    RegisterCommand('open_chat', function()
        if not ChatInputActive then
            ActivateChatInput()
        end
    end, false)
end

-- =====================================================
-- CHAT INPUT SYSTEM
-- =====================================================

function ActivateChatInput(channel)
    if PlayerMuted then
        ShowMuteMessage()
        return
    end

    ChatInputActive = true
    CurrentChannel = channel or CurrentChannel
    ChatInput = ''

    -- Start input loop
    CreateThread(function()
        while ChatInputActive do
            Wait(0)

            -- Disable game controls while typing
            DisableAllControlActions(0)

            -- Handle text input
            HandleChatInput()

            -- Draw chat input UI
            DrawChatInput()
        end
    end)
end

function HandleChatInput()
    -- Check for cancel (ESC)
    if IsControlJustPressed(0, 177) then -- ESC
        CancelChatInput()
        return
    end

    -- Check for send (ENTER)
    if IsControlJustPressed(0, 191) then -- ENTER
        SendCurrentMessage()
        return
    end

    -- Handle character input
    for i = 0, 255 do
        if IsControlJustPressed(0, i) then
            local char = GetCharFromControl(i)
            if char and char ~= '' then
                ChatInput = ChatInput .. char
            end
        end
    end

    -- Handle backspace
    if IsControlPressed(0, 194) then -- BACKSPACE
        if #ChatInput > 0 then
            ChatInput = ChatInput:sub(1, -2)
        end
    end

    -- Limit input length
    if #ChatInput > (ChatConfig.SpamDetection.maxMessageLength or 200) then
        ChatInput = ChatInput:sub(1, ChatConfig.SpamDetection.maxMessageLength or 200)
    end
end

function GetCharFromControl(control)
    -- Basic character mapping (this would be more comprehensive in production)
    local charMap = {
        [10] = 'a', [11] = 'b', [12] = 'c', [13] = 'd', [14] = 'e', [15] = 'f',
        [16] = 'g', [17] = 'h', [18] = 'i', [19] = 'j', [20] = 'k', [21] = 'l',
        [22] = 'm', [23] = 'n', [24] = 'o', [25] = 'p', [26] = 'q', [27] = 'r',
        [28] = 's', [29] = 't', [30] = 'u', [31] = 'v', [32] = 'w', [33] = 'x',
        [34] = 'y', [35] = 'z', [157] = '1', [158] = '2', [159] = '3', [160] = '4',
        [161] = '5', [162] = '6', [163] = '7', [164] = '8', [165] = '9', [166] = '0',
        [44] = ' '
    }

    return charMap[control]
end

function SendCurrentMessage()
    if #ChatInput > 0 then
        SendChatMessage(ChatInput, CurrentChannel)
    end
    CancelChatInput()
end

function CancelChatInput()
    ChatInputActive = false
    ChatInput = ''
end

function SendChatMessage(message, channel)
    if PlayerMuted then
        ShowMuteMessage()
        return
    end

    if #message == 0 then
        return
    end

    -- Get current arena for targeting
    local arenaId = GetCurrentArena()

    TriggerServerEvent('tgw:chat:sendMessage', message, channel, arenaId)
end

-- =====================================================
-- MESSAGE HANDLING
-- =====================================================

function ReceiveMessage(messageData)
    -- Add timestamp for display
    messageData.displayTime = GetGameTimer()

    -- Insert message
    table.insert(ChatMessages, messageData)

    -- Limit chat history
    if #ChatMessages > (ChatConfig.Display.maxVisibleMessages or 10) then
        table.remove(ChatMessages, 1)
    end

    -- Play chat sound if enabled
    if ChatConfig.Display.enableChatSounds then
        PlayChatSound(messageData.channel)
    end

    print(string.format('^2[TGW-CHAT]^7 %s [%s]: %s',
        messageData.senderName, messageData.channel:upper(), messageData.content))
end

function LoadChatHistory(historyData)
    ChatMessages = {}

    for _, messageData in ipairs(historyData) do
        messageData.displayTime = GetGameTimer() - 1000 -- Show as recent
        table.insert(ChatMessages, messageData)
    end

    TGWCore.ShowTGWNotification(string.format('Loaded %d chat messages', #historyData), 'info', 2000)
end

function ClearChatMessages()
    ChatMessages = {}
end

-- =====================================================
-- CHAT DISPLAY SYSTEM
-- =====================================================

function StartChatSystem()
    CreateThread(function()
        while true do
            Wait(0)

            if ShowChat then
                DrawChatMessages()

                -- Clean up old messages
                CleanupOldMessages()
            end
        end
    end)
end

function DrawChatMessages()
    if #ChatMessages == 0 then
        return
    end

    local style = ChatConfig.Style
    local currentTime = GetGameTimer()

    -- Draw background
    DrawRect(
        style.chatX + style.chatWidth / 2,
        style.chatY + style.chatHeight / 2,
        style.chatWidth,
        style.chatHeight,
        style.backgroundColor[1],
        style.backgroundColor[2],
        style.backgroundColor[3],
        style.backgroundColor[4] * ChatOpacity
    )

    -- Draw messages
    local yOffset = 0
    for i = #ChatMessages, 1, -1 do
        local message = ChatMessages[i]
        local messageAge = currentTime - message.displayTime

        -- Calculate fade
        local alpha = 1.0
        if messageAge > MessageDisplayTime then
            local fadeTime = ChatConfig.Display.fadeOutTime or 1000
            local fadeProgress = (messageAge - MessageDisplayTime) / fadeTime
            alpha = math.max(0, 1.0 - fadeProgress)
        end

        if alpha > 0 then
            DrawChatMessage(message, yOffset, alpha)
            yOffset = yOffset + 0.03
        end
    end
end

function DrawChatMessage(messageData, yOffset, alpha)
    local style = ChatConfig.Style
    local channel = ChatConfig.Channels[messageData.channel]
    local messageColor = ChatConfig.MessageColors[messageData.channel] or ChatConfig.MessageColors.normal

    local x = style.chatX + 0.01
    local y = style.chatY + style.chatHeight - 0.05 - yOffset

    -- Format message text
    local displayText = FormatMessageForDisplay(messageData)

    -- Draw message
    SetTextFont(style.fontFamily)
    SetTextProportional(true)
    SetTextScale(style.fontSize, style.fontSize)
    SetTextColour(
        messageColor[1],
        messageColor[2],
        messageColor[3],
        math.floor(255 * alpha * ChatOpacity)
    )
    SetTextEntry('STRING')
    AddTextComponentString(displayText)
    DrawText(x, y)
end

function DrawChatInput()
    if not ChatInputActive then
        return
    end

    local style = ChatConfig.Style
    local inputY = style.chatY + style.chatHeight + 0.01

    -- Draw input background
    DrawRect(
        style.chatX + style.chatWidth / 2,
        inputY + 0.025,
        style.chatWidth,
        0.05,
        0, 0, 0, 200
    )

    -- Draw channel indicator
    local channelText = string.format('[%s] ', CurrentChannel:upper())
    SetTextFont(style.fontFamily)
    SetTextProportional(true)
    SetTextScale(style.fontSize, style.fontSize)
    SetTextColour(255, 255, 0, 255)
    SetTextEntry('STRING')
    AddTextComponentString(channelText)
    DrawText(style.chatX + 0.01, inputY)

    -- Draw input text
    local inputText = ChatInput .. '_' -- Add cursor
    SetTextColour(255, 255, 255, 255)
    SetTextEntry('STRING')
    AddTextComponentString(inputText)
    DrawText(style.chatX + 0.01 + GetTextScaleHeight(channelText, style.fontSize, style.fontFamily), inputY)

    -- Draw instructions
    local instructions = 'ENTER to send | ESC to cancel'
    SetTextScale(0.3, 0.3)
    SetTextColour(150, 150, 150, 255)
    SetTextEntry('STRING')
    AddTextComponentString(instructions)
    DrawText(style.chatX + 0.01, inputY + 0.03)
end

function FormatMessageForDisplay(messageData)
    local timestamp = ''
    if ChatConfig.Display.showTimestamps then
        local timeFormat = ChatConfig.Display.show24HourTime and '%H:%M' or '%I:%M %p'
        timestamp = string.format('[%s] ', os.date(timeFormat, messageData.timestamp))
    end

    local channel = ChatConfig.Channels[messageData.channel]
    local prefix = channel and channel.prefix or ''

    local arenaInfo = ''
    if ChatConfig.Display.showArenaNumbers and messageData.arenaId and messageData.arenaId > 0 then
        arenaInfo = string.format('[Arena %d] ', messageData.arenaId)
    end

    return string.format('%s%s%s%s: %s',
        timestamp,
        prefix,
        arenaInfo,
        messageData.senderName,
        messageData.content
    )
end

function GetTextScaleHeight(text, scale, font)
    -- This would calculate text width for proper spacing
    -- Simplified for now
    return #text * scale * 0.01
end

-- =====================================================
-- MUTE HANDLING
-- =====================================================

function HandlePlayerMuted(muteData)
    PlayerMuted = true
    MuteInfo = muteData

    local duration = muteData.duration
    local reason = muteData.reason

    local muteMessage = string.format(
        'You have been muted for %d seconds\nReason: %s',
        duration,
        reason
    )

    TGWCore.ShowTGWNotification(muteMessage, 'error', 8000)

    -- Start mute countdown
    StartMuteCountdown(muteData.muteEnd)
end

function HandlePlayerUnmuted()
    PlayerMuted = false
    MuteInfo = nil

    TGWCore.ShowTGWNotification('You have been unmuted', 'success', 3000)
end

function StartMuteCountdown(muteEnd)
    CreateThread(function()
        while PlayerMuted and os.time() < muteEnd do
            Wait(1000)
        end

        if PlayerMuted and os.time() >= muteEnd then
            -- Mute expired
            PlayerMuted = false
            MuteInfo = nil
            TGWCore.ShowTGWNotification('Your mute has expired', 'success', 3000)
        end
    end)
end

function ShowMuteMessage()
    if MuteInfo then
        local remaining = MuteInfo.muteEnd - os.time()
        TGWCore.ShowTGWNotification(
            string.format('You are muted for %d more seconds\nReason: %s', remaining, MuteInfo.reason),
            'error',
            3000
        )
    else
        TGWCore.ShowTGWNotification('You are currently muted', 'error', 2000)
    end
end

-- =====================================================
-- WARNING AND ERROR HANDLING
-- =====================================================

function ShowChatWarning(warningData)
    local message = string.format(
        'Chat Warning: %s\n%s',
        warningData.violation,
        warningData.message
    )

    TGWCore.ShowTGWNotification(message, 'warning', 5000)
    PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 1)
end

function ShowChatError(errorMessage)
    TGWCore.ShowTGWNotification(errorMessage, 'error', 3000)
    PlaySoundFrontend(-1, 'ERROR', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 1)
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function CleanupOldMessages()
    local currentTime = GetGameTimer()
    local maxAge = MessageDisplayTime + (ChatConfig.Display.fadeOutTime or 1000)

    for i = #ChatMessages, 1, -1 do
        local messageAge = currentTime - ChatMessages[i].displayTime
        if messageAge > maxAge then
            table.remove(ChatMessages, i)
        end
    end
end

function PlayChatSound(channel)
    if channel == 'system' then
        PlaySoundFrontend(-1, 'CHECKPOINT_PERFECT', 'HUD_MINI_GAME_SOUNDSET', 1)
    elseif channel == 'admin' then
        PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', 1)
    else
        PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', 1)
    end
end

function GetCurrentArena()
    local arenaExport = exports['tgw_arena']
    if arenaExport then
        return arenaExport:GetPlayerArena()
    end
    return nil
end

function RequestChatHistory(arenaId)
    TriggerServerEvent('tgw:chat:requestHistory', arenaId, 20)
end

function DisableChatInput()
    if ChatInputActive then
        CancelChatInput()
    end
    -- Could add visual indication that chat is disabled
end

function EnableChatInput()
    -- Re-enable chat if it was disabled
end

function SetChatOpacity(opacity)
    ChatOpacity = math.max(0, math.min(1, opacity))
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('SendMessage', function(message, channel)
    SendChatMessage(message, channel or CurrentChannel)
end)

exports('ClearChat', ClearChatMessages)

exports('SetChatOpacity', SetChatOpacity)

exports('IsInputActive', function()
    return ChatInputActive
end)

exports('GetChatMessages', function()
    return ChatMessages
end)

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if ChatInputActive then
            CancelChatInput()
        end
    end
end)