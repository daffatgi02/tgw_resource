-- =====================================================
-- TGW CHAT SERVER - ARENA-SPECIFIC CHAT SYSTEM
-- =====================================================
-- Purpose: Manage arena-specific chat communication (no voice)
-- Dependencies: tgw_core, tgw_arena, es_extended
-- =====================================================

local ESX = exports['tgw_core']:GetESX()
local TGWCore = exports['tgw_core']

-- Chat system state
local ArenaChatHistory = {}         -- [arenaId] = messageArray
local PlayerMutes = {}              -- [identifier] = muteData
local ChatLimits = {}               -- [identifier] = rateLimitData
local MessageQueue = {}             -- Queued messages for processing

-- Performance tracking
local ChatStats = {
    totalMessages = 0,
    filteredMessages = 0,
    mutedPlayers = 0,
    spamBlocked = 0
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
    InitializeChatSystem()
    StartPerformanceMonitoring()
    LoadPlayerMutes()

    print('^2[TGW-CHAT SERVER]^7 Arena-specific chat system initialized')
end)

function RegisterEventHandlers()
    -- Chat message events
    RegisterNetEvent('tgw:chat:sendMessage', function(message, channel, targetArena)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            ProcessChatMessage(xPlayer.identifier, src, message, channel, targetArena)
        end
    end)

    RegisterNetEvent('tgw:chat:requestHistory', function(arenaId, limit)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer then
            SendChatHistory(xPlayer.identifier, src, arenaId, limit)
        end
    end)

    -- Moderation events
    RegisterNetEvent('tgw:chat:mutePlayer', function(targetIdentifier, duration, reason)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer and TGWCore.IsPlayerAdmin(src) then
            MutePlayer(targetIdentifier, duration, reason, xPlayer.identifier)
        end
    end)

    RegisterNetEvent('tgw:chat:unmutePlayer', function(targetIdentifier)
        local src = source
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer and TGWCore.IsPlayerAdmin(src) then
            UnmutePlayer(targetIdentifier, xPlayer.identifier)
        end
    end)

    -- Arena events integration
    RegisterNetEvent('tgw:arena:playerJoined', function(arenaId, identifier)
        if ChatConfig.ArenaIntegration.announcePlayerJoin then
            BroadcastSystemMessage(arenaId, string.format('%s joined the arena', GetPlayerNameByIdentifier(identifier)))
        end
    end)

    RegisterNetEvent('tgw:arena:playerLeft', function(arenaId, identifier)
        if ChatConfig.ArenaIntegration.announcePlayerLeave then
            BroadcastSystemMessage(arenaId, string.format('%s left the arena', GetPlayerNameByIdentifier(identifier)))
        end
    end)

    RegisterNetEvent('tgw:round:started', function(matchData)
        if ChatConfig.ArenaIntegration.announceRoundStart then
            local arenaId = matchData.arenaId
            BroadcastSystemMessage(arenaId, 'Round started! Good luck!')
        end
    end)

    RegisterNetEvent('tgw:round:result', function(resultData)
        if ChatConfig.ArenaIntegration.announceRoundEnd then
            local arenaId = resultData.arenaId
            local winner = resultData.winner
            local message = winner and string.format('Round ended! Winner: %s', GetPlayerNameByIdentifier(winner)) or 'Round ended in a draw!'
            BroadcastSystemMessage(arenaId, message)
        end
    end)

    -- Player connection events
    RegisterNetEvent('esx:playerLoaded', function(playerId, xPlayer)
        LoadPlayerMuteStatus(xPlayer.identifier)
        InitializePlayerChatLimits(xPlayer.identifier)
    end)

    RegisterNetEvent('esx:playerDropped', function(playerId, reason)
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            CleanupPlayerChatData(xPlayer.identifier)
        end
    end)
end

-- =====================================================
-- MESSAGE PROCESSING
-- =====================================================

function ProcessChatMessage(identifier, playerId, message, channel, targetArena)
    -- Validate player is not muted
    if IsPlayerMuted(identifier) then
        TriggerClientEvent('tgw:chat:error', playerId, 'You are currently muted')
        return false
    end

    -- Check rate limits
    if not CheckRateLimit(identifier) then
        TriggerClientEvent('tgw:chat:error', playerId, 'You are sending messages too quickly')
        return false
    end

    -- Validate message
    local validationResult = ValidateMessage(message, identifier)
    if not validationResult.valid then
        HandleMessageViolation(identifier, playerId, validationResult.violation, message)
        return false
    end

    -- Filter message content
    local filteredMessage = FilterMessage(message)

    -- Determine target arena
    local arenaId = targetArena or GetPlayerArena(identifier)
    if not arenaId and channel == 'arena' then
        TriggerClientEvent('tgw:chat:error', playerId, 'You must be in an arena to use arena chat')
        return false
    end

    -- Create message object
    local messageData = {
        id = GenerateMessageId(),
        sender = identifier,
        senderName = GetPlayerNameByIdentifier(identifier),
        content = filteredMessage,
        originalContent = message,
        channel = channel,
        arenaId = arenaId,
        timestamp = os.time(),
        filtered = filteredMessage ~= message
    }

    -- Store message in history
    StoreMessage(messageData)

    -- Broadcast message to appropriate recipients
    BroadcastMessage(messageData)

    -- Update statistics
    ChatStats.totalMessages = ChatStats.totalMessages + 1
    if messageData.filtered then
        ChatStats.filteredMessages = ChatStats.filteredMessages + 1
    end

    -- Update rate limit
    UpdateRateLimit(identifier)

    print(string.format('^2[TGW-CHAT]^7 %s [%s]: %s', messageData.senderName, channel:upper(), filteredMessage))

    return true
end

function ValidateMessage(message, identifier)
    -- Check message length
    if #message < ChatConfig.SpamDetection.minMessageLength then
        return {valid = false, violation = 'MESSAGE_TOO_SHORT'}
    end

    if #message > ChatConfig.SpamDetection.maxMessageLength then
        return {valid = false, violation = 'MESSAGE_TOO_LONG'}
    end

    -- Check for spam patterns
    if ChatConfig.Filtering.enableSpamFilter then
        local spamCheck = CheckForSpam(message, identifier)
        if not spamCheck.valid then
            return spamCheck
        end
    end

    -- Check for profanity
    if ChatConfig.Filtering.enableProfanityFilter then
        if ContainsProfanity(message) then
            return {valid = false, violation = 'PROFANITY'}
        end
    end

    -- Check for excessive caps
    if ChatConfig.Filtering.enableCapFilter then
        local capsPercentage = CalculateCapsPercentage(message)
        if capsPercentage > ChatConfig.SpamDetection.capsPercentageThreshold then
            return {valid = false, violation = 'CAPS'}
        end
    end

    -- Check for links
    if ChatConfig.Filtering.enableLinkFilter then
        if ContainsUnauthorizedLinks(message) then
            return {valid = false, violation = 'LINKS'}
        end
    end

    return {valid = true}
end

function CheckForSpam(message, identifier)
    local limits = ChatLimits[identifier]
    if not limits then
        return {valid = true}
    end

    local currentTime = os.time()

    -- Check for repeated messages
    if ChatConfig.Filtering.enableRepeatFilter then
        for _, recentMessage in ipairs(limits.recentMessages) do
            if recentMessage.content:lower() == message:lower() and
               currentTime - recentMessage.timestamp < ChatConfig.SpamDetection.repeatWindow then
                return {valid = false, violation = 'SPAM'}
            end
        end
    end

    return {valid = true}
end

function ContainsProfanity(message)
    local lowerMessage = message:lower()
    for _, word in ipairs(ChatConfig.ProfanityList) do
        if lowerMessage:find(word:lower()) then
            return true
        end
    end
    return false
end

function CalculateCapsPercentage(message)
    local totalLetters = 0
    local capsLetters = 0

    for i = 1, #message do
        local char = message:sub(i, i)
        if char:match('%a') then
            totalLetters = totalLetters + 1
            if char:match('%u') then
                capsLetters = capsLetters + 1
            end
        end
    end

    return totalLetters > 0 and (capsLetters / totalLetters) * 100 or 0
end

function ContainsUnauthorizedLinks(message)
    -- Basic URL detection pattern
    local urlPattern = 'https?://[%w-_%.%?%.:/%+=&]+'
    local urls = {}

    for url in message:gmatch(urlPattern) do
        table.insert(urls, url)
    end

    if #urls == 0 then
        return false
    end

    -- Check against allowed/blocked domains
    for _, url in ipairs(urls) do
        local domain = url:match('https?://([%w-_%.]+)')
        if domain then
            -- Check blocked domains
            for _, blocked in ipairs(ChatConfig.LinkFilter.blockedDomains) do
                if domain:find(blocked) then
                    return true
                end
            end

            -- Check whitelist requirement
            if ChatConfig.LinkFilter.requireWhitelist then
                local allowed = false
                for _, allowedDomain in ipairs(ChatConfig.LinkFilter.allowedDomains) do
                    if domain:find(allowedDomain) then
                        allowed = true
                        break
                    end
                end
                if not allowed then
                    return true
                end
            end
        end
    end

    return false
end

function FilterMessage(message)
    local filtered = message

    -- Replace profanity
    if ChatConfig.Filtering.enableProfanityFilter then
        for _, word in ipairs(ChatConfig.ProfanityList) do
            local pattern = word:gsub('%W', '%%%1')
            filtered = filtered:gsub('(?i)' .. pattern, string.rep('*', #word))
        end
    end

    return filtered
end

-- =====================================================
-- MESSAGE BROADCASTING
-- =====================================================

function BroadcastMessage(messageData)
    local recipients = GetMessageRecipients(messageData)

    for _, playerId in ipairs(recipients) do
        TriggerClientEvent('tgw:chat:receiveMessage', playerId, messageData)
    end

    print(string.format('^2[TGW-CHAT BROADCAST]^7 Message sent to %d recipients', #recipients))
end

function GetMessageRecipients(messageData)
    local recipients = {}

    if messageData.channel == 'arena' and messageData.arenaId then
        -- Send to players in the same arena
        local arenaPlayers = GetArenaPlayers(messageData.arenaId)
        for _, playerId in ipairs(arenaPlayers) do
            table.insert(recipients, playerId)
        end

        -- Send to spectators if enabled
        if ChatConfig.Arena.spectatorsCanSeeArenaChat then
            local spectators = GetArenaSpectators(messageData.arenaId)
            for _, playerId in ipairs(spectators) do
                table.insert(recipients, playerId)
            end
        end

    elseif messageData.channel == 'spectator' and messageData.arenaId then
        -- Send to spectators only
        if ChatConfig.Arena.enableSpectatorChat then
            local spectators = GetArenaSpectators(messageData.arenaId)
            for _, playerId in ipairs(spectators) do
                table.insert(recipients, playerId)
            end

            -- Send to arena players if enabled
            if ChatConfig.Arena.arenaPlayersCanSeeSpectatorChat then
                local arenaPlayers = GetArenaPlayers(messageData.arenaId)
                for _, playerId in ipairs(arenaPlayers) do
                    table.insert(recipients, playerId)
                end
            end
        end

    elseif messageData.channel == 'admin' then
        -- Send to admins only
        local adminPlayers = TGWCore.GetOnlineAdmins()
        for _, playerId in ipairs(adminPlayers) do
            table.insert(recipients, playerId)
        end

    elseif messageData.channel == 'system' then
        -- System messages go to everyone in the arena
        if messageData.arenaId then
            local arenaPlayers = GetArenaPlayers(messageData.arenaId)
            local spectators = GetArenaSpectators(messageData.arenaId)

            for _, playerId in ipairs(arenaPlayers) do
                table.insert(recipients, playerId)
            end
            for _, playerId in ipairs(spectators) do
                table.insert(recipients, playerId)
            end
        end
    end

    return recipients
end

function BroadcastSystemMessage(arenaId, message)
    local messageData = {
        id = GenerateMessageId(),
        sender = 'system',
        senderName = 'System',
        content = message,
        channel = 'system',
        arenaId = arenaId,
        timestamp = os.time(),
        filtered = false
    }

    StoreMessage(messageData)
    BroadcastMessage(messageData)
end

function BroadcastToArena(arenaId, message, channel)
    channel = channel or 'system'

    local messageData = {
        id = GenerateMessageId(),
        sender = 'system',
        senderName = 'System',
        content = message,
        channel = channel,
        arenaId = arenaId,
        timestamp = os.time(),
        filtered = false
    }

    StoreMessage(messageData)
    BroadcastMessage(messageData)
end

-- =====================================================
-- RATE LIMITING
-- =====================================================

function CheckRateLimit(identifier)
    if not ChatConfig.RateLimit.enableRateLimit then
        return true
    end

    local limits = ChatLimits[identifier]
    if not limits then
        InitializePlayerChatLimits(identifier)
        limits = ChatLimits[identifier]
    end

    local currentTime = os.time()

    -- Check rate limits
    local recentMessages = 0
    for _, messageTime in ipairs(limits.messageHistory) do
        if currentTime - messageTime < 60 then -- Last minute
            recentMessages = recentMessages + 1
        end
    end

    if recentMessages >= ChatConfig.RateLimit.messagesPerMinute then
        return false
    end

    -- Check burst allowance
    local recentBurst = 0
    for _, messageTime in ipairs(limits.messageHistory) do
        if currentTime - messageTime < 1 then -- Last second
            recentBurst = recentBurst + 1
        end
    end

    if recentBurst >= ChatConfig.RateLimit.messagesPerSecond then
        return false
    end

    return true
end

function UpdateRateLimit(identifier)
    local limits = ChatLimits[identifier]
    if not limits then
        return
    end

    table.insert(limits.messageHistory, os.time())

    -- Keep only recent messages
    local currentTime = os.time()
    for i = #limits.messageHistory, 1, -1 do
        if currentTime - limits.messageHistory[i] > 60 then
            table.remove(limits.messageHistory, i)
        end
    end
end

function InitializePlayerChatLimits(identifier)
    ChatLimits[identifier] = {
        messageHistory = {},
        recentMessages = {},
        violations = 0,
        lastViolation = 0
    }
end

-- =====================================================
-- MODERATION SYSTEM
-- =====================================================

function HandleMessageViolation(identifier, playerId, violation, message)
    local violationConfig = ChatConfig.Violations[violation]
    if not violationConfig then
        return
    end

    -- Record violation
    RecordChatViolation(identifier, violation, message)

    -- Get current violation count
    local violationCount = GetPlayerViolationCount(identifier, violation)

    -- Check if mute is warranted
    if violationCount >= violationConfig.warningsBeforeMute then
        -- Apply mute
        local muteDuration = violationConfig.muteDuration
        if ChatConfig.Moderation.muteEscalation then
            local previousMutes = GetPlayerMuteCount(identifier)
            muteDuration = muteDuration * (ChatConfig.Moderation.escalationMultiplier ^ previousMutes)
        end

        MutePlayer(identifier, muteDuration, violation, 'system')
    else
        -- Send warning
        local warningsLeft = violationConfig.warningsBeforeMute - violationCount
        TriggerClientEvent('tgw:chat:warning', playerId, {
            violation = violation,
            warningsLeft = warningsLeft,
            message = string.format('Warning: %s detected. %d warnings left before mute.', violation, warningsLeft)
        })
    end

    ChatStats.spamBlocked = ChatStats.spamBlocked + 1
end

function MutePlayer(identifier, duration, reason, adminIdentifier)
    local muteEnd = os.time() + duration

    PlayerMutes[identifier] = {
        reason = reason,
        duration = duration,
        muteEnd = muteEnd,
        adminIdentifier = adminIdentifier,
        timestamp = os.time()
    }

    -- Save to database
    MySQL.execute([[
        INSERT INTO tgw_chat_mutes (identifier, reason, duration, mute_end, admin_identifier)
        VALUES (?, ?, ?, FROM_UNIXTIME(?), ?)
        ON DUPLICATE KEY UPDATE
            reason = VALUES(reason),
            duration = VALUES(duration),
            mute_end = VALUES(mute_end),
            admin_identifier = VALUES(admin_identifier),
            created_at = NOW()
    ]], {identifier, reason, duration, muteEnd, adminIdentifier})

    -- Notify player
    local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)
    if playerId then
        TriggerClientEvent('tgw:chat:muted', playerId, {
            reason = reason,
            duration = duration,
            muteEnd = muteEnd
        })
    end

    ChatStats.mutedPlayers = ChatStats.mutedPlayers + 1

    print(string.format('^3[TGW-CHAT MUTE]^7 %s muted for %d seconds - Reason: %s', identifier, duration, reason))
end

function UnmutePlayer(identifier, adminIdentifier)
    if PlayerMutes[identifier] then
        PlayerMutes[identifier] = nil

        -- Remove from database
        MySQL.execute('DELETE FROM tgw_chat_mutes WHERE identifier = ?', {identifier})

        -- Notify player
        local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)
        if playerId then
            TriggerClientEvent('tgw:chat:unmuted', playerId)
        end

        print(string.format('^2[TGW-CHAT UNMUTE]^7 %s unmuted by %s', identifier, adminIdentifier))
        return true
    end

    return false
end

function IsPlayerMuted(identifier)
    local muteData = PlayerMutes[identifier]
    if not muteData then
        return false
    end

    if os.time() >= muteData.muteEnd then
        -- Mute expired, remove it
        PlayerMutes[identifier] = nil
        MySQL.execute('DELETE FROM tgw_chat_mutes WHERE identifier = ?', {identifier})
        return false
    end

    return true
end

-- =====================================================
-- CHAT HISTORY
-- =====================================================

function StoreMessage(messageData)
    if not ChatConfig.History.enableChatHistory then
        return
    end

    local arenaId = messageData.arenaId or 0

    if not ArenaChatHistory[arenaId] then
        ArenaChatHistory[arenaId] = {}
    end

    table.insert(ArenaChatHistory[arenaId], messageData)

    -- Limit history size
    if #ArenaChatHistory[arenaId] > ChatConfig.History.maxHistoryPerArena then
        table.remove(ArenaChatHistory[arenaId], 1)
    end

    -- Save to database if enabled
    if ChatConfig.History.logToDatabase then
        MySQL.execute([[
            INSERT INTO tgw_chat_messages (sender_identifier, arena_id, channel, message, filtered_message, created_at)
            VALUES (?, ?, ?, ?, ?, FROM_UNIXTIME(?))
        ]], {
            messageData.sender,
            messageData.arenaId,
            messageData.channel,
            messageData.originalContent,
            messageData.content,
            messageData.timestamp
        })
    end
end

function SendChatHistory(identifier, playerId, arenaId, limit)
    local playerArena = GetPlayerArena(identifier)

    -- Validate player can access this arena's history
    if arenaId ~= playerArena and not TGWCore.IsPlayerAdmin(GetPlayerIdByIdentifier(identifier)) then
        TriggerClientEvent('tgw:chat:error', playerId, 'You cannot access this arena\'s chat history')
        return
    end

    limit = limit or 20
    local history = ArenaChatHistory[arenaId] or {}
    local recentHistory = {}

    -- Get recent messages
    local startIndex = math.max(1, #history - limit + 1)
    for i = startIndex, #history do
        table.insert(recentHistory, history[i])
    end

    TriggerClientEvent('tgw:chat:historyData', playerId, recentHistory)
end

function GetChatHistory(arenaId, limit)
    limit = limit or ChatConfig.History.maxHistoryPerArena
    local history = ArenaChatHistory[arenaId] or {}

    local result = {}
    local startIndex = math.max(1, #history - limit + 1)
    for i = startIndex, #history do
        table.insert(result, history[i])
    end

    return result
end

-- =====================================================
-- UTILITY FUNCTIONS
-- =====================================================

function GetPlayerArena(identifier)
    local arenaExport = exports['tgw_arena']
    if arenaExport then
        return arenaExport:GetPlayerArena(identifier)
    end
    return nil
end

function GetArenaPlayers(arenaId)
    local arenaExport = exports['tgw_arena']
    if arenaExport then
        return arenaExport:GetArenaPlayers(arenaId)
    end
    return {}
end

function GetArenaSpectators(arenaId)
    local arenaExport = exports['tgw_arena']
    if arenaExport then
        return arenaExport:GetArenaSpectators(arenaId)
    end
    return {}
end

function GetPlayerNameByIdentifier(identifier)
    local playerId = TGWCore.GetPlayerIdByIdentifier(identifier)
    if playerId then
        return GetPlayerName(playerId)
    end
    return identifier:sub(-8) -- Last 8 characters as fallback
end

function GenerateMessageId()
    return string.format('%d_%d', os.time(), math.random(1000, 9999))
end

function RecordChatViolation(identifier, violation, message)
    MySQL.execute([[
        INSERT INTO tgw_chat_violations (identifier, violation_type, message, created_at)
        VALUES (?, ?, ?, NOW())
    ]], {identifier, violation, message})
end

function GetPlayerViolationCount(identifier, violation)
    -- This would query the database for recent violations
    -- Simplified for now
    return 1
end

function GetPlayerMuteCount(identifier)
    -- This would query the database for historical mutes
    -- Simplified for now
    return 0
end

function LoadPlayerMutes()
    MySQL.query([[
        SELECT identifier, reason, duration, UNIX_TIMESTAMP(mute_end) as mute_end, admin_identifier
        FROM tgw_chat_mutes
        WHERE mute_end > NOW()
    ]], {}, function(results)
        if results then
            for _, row in ipairs(results) do
                PlayerMutes[row.identifier] = {
                    reason = row.reason,
                    duration = row.duration,
                    muteEnd = row.mute_end,
                    adminIdentifier = row.admin_identifier
                }
            end
            print(string.format('^2[TGW-CHAT]^7 Loaded %d active mutes', #results))
        end
    end)
end

function LoadPlayerMuteStatus(identifier)
    MySQL.query([[
        SELECT reason, duration, UNIX_TIMESTAMP(mute_end) as mute_end, admin_identifier
        FROM tgw_chat_mutes
        WHERE identifier = ? AND mute_end > NOW()
    ]], {identifier}, function(results)
        if results and #results > 0 then
            local row = results[1]
            PlayerMutes[identifier] = {
                reason = row.reason,
                duration = row.duration,
                muteEnd = row.mute_end,
                adminIdentifier = row.admin_identifier
            }
        end
    end)
end

function CleanupPlayerChatData(identifier)
    ChatLimits[identifier] = nil
end

function StartPerformanceMonitoring()
    CreateThread(function()
        while true do
            Wait(300000) -- Every 5 minutes

            print(string.format('^2[TGW-CHAT STATS]^7 Messages: %d, Filtered: %d, Muted: %d, Spam Blocked: %d',
                ChatStats.totalMessages,
                ChatStats.filteredMessages,
                ChatStats.mutedPlayers,
                ChatStats.spamBlocked
            ))

            -- Cleanup old chat history
            CleanupOldChatHistory()
        end
    end)
end

function CleanupOldChatHistory()
    local retentionTime = ChatConfig.History.historyRetentionDays * 86400
    local cutoffTime = os.time() - retentionTime

    for arenaId, messages in pairs(ArenaChatHistory) do
        for i = #messages, 1, -1 do
            if messages[i].timestamp < cutoffTime then
                table.remove(messages, i)
            end
        end
    end
end

function InitializeChatSystem()
    -- Load existing mutes
    LoadPlayerMutes()

    -- Initialize chat limits for active players
    local players = ESX.GetPlayers()
    for _, playerId in ipairs(players) do
        local xPlayer = ESX.GetPlayerFromId(playerId)
        if xPlayer then
            InitializePlayerChatLimits(xPlayer.identifier)
        end
    end
end

-- =====================================================
-- EXPORTS
-- =====================================================

exports('SendArenaMessage', function(arenaId, message)
    BroadcastToArena(arenaId, message, 'system')
end)

exports('BroadcastToArena', BroadcastToArena)
exports('MutePlayer', MutePlayer)
exports('UnmutePlayer', UnmutePlayer)
exports('GetChatHistory', GetChatHistory)
exports('FilterMessage', FilterMessage)
exports('IsPlayerMuted', IsPlayerMuted)

-- =====================================================
-- ADMIN COMMANDS
-- =====================================================

RegisterCommand('tgw_chat_stats', function(source, args, rawCommand)
    if source == 0 then -- Console only
        print('^2[TGW-CHAT STATS]^7')
        print(string.format('  Total Messages: %d', ChatStats.totalMessages))
        print(string.format('  Filtered Messages: %d', ChatStats.filteredMessages))
        print(string.format('  Muted Players: %d', ChatStats.mutedPlayers))
        print(string.format('  Spam Blocked: %d', ChatStats.spamBlocked))
        print(string.format('  Active Arenas: %d', GetActiveChatArenas()))
    end
end, true)

RegisterCommand('tgw_chat_mute', function(source, args, rawCommand)
    if source == 0 and args[1] and args[2] then -- Console only
        local identifier = args[1]
        local duration = tonumber(args[2]) or 600
        local reason = args[3] or 'Admin mute'

        MutePlayer(identifier, duration, reason, 'console')
        print(string.format('^2[TGW-CHAT]^7 Muted %s for %d seconds', identifier, duration))
    end
end, true)

function GetActiveChatArenas()
    local count = 0
    for _ in pairs(ArenaChatHistory) do
        count = count + 1
    end
    return count
end

-- =====================================================
-- CLEANUP
-- =====================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('^2[TGW-CHAT]^7 Chat system stopped')
    end
end)