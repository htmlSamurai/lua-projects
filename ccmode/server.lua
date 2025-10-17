--ccmode version 39
local teams = { Team1 = "", Team2 = "" }
local captainElements = { Captain1 = nil, Captain2 = nil }
local captainNames = { Captain1 = "", Captain2 = "" }
local maps = {}
local banList = { BanTeam1 = {}, BanTeam2 = {} }
local pickList = { PickTeam1 = {}, PickTeam2 = {} }
local actionQueue = {}
local currentTurn = 1
local isProcessActive = false
local turnTimer = nil
local isTimer1Active = false
local isTimer2Active = false
local team1Time = 450 --сделат тут 450
local team2Time = 450 --сделат тут 450
local activeTeam = nil
local globalPanelState = true -- Панель по умолчанию открыта
local captainCategoryStats = {
    Captain1 = {},
    Captain2 = {}
}
local allMapsCopy = {}
local selectedMaps = {}
local draftHistory = ""
local currentMapIndex = 0
local readyPlayers = {}
local isMatchInProgress = false
local isFirstRound = true
local isWaitingForReady = false
local hasStartResourcePermission = hasObjectPermissionTo(resource, "function.startResource", false)
local raceLeagueResource = "race"
local currentRoundEnded = false
local draftPicksText = ""
local draftPicksHistory = ""
local globalPanelState = nil

-- Загрузка карт
addEventHandler("onResourceStart", resourceRoot, function()
    local mapsFile = fileOpen("maps.json")
    if mapsFile then
        local content = fileRead(mapsFile, fileGetSize(mapsFile))
        fileClose(mapsFile)
        maps = fromJSON(content)
        outputDebugString("[CC] Maps loaded from JSON", 0)
    else
        outputDebugString("[CC] Error loading maps file!", 1)
    end

    if not hasStartResourcePermission then
        outputDebugString("[CC] WARNING: Resource doesn't have permission to start other resources!", 1)
    end
end)

-- Функция для отправки полной истории пиков всем клиентам
function sendFullPicksHistoryToClient(player)
    if draftPicksHistory and #draftPicksHistory > 0 then
        triggerClientEvent(player, "onDraftPicksUpdate", resourceRoot, draftPicksHistory)
    end
end

-- Обработчик запроса полной истории пиков
addEvent("requestFullPicksHistory", true)
addEventHandler("requestFullPicksHistory", resourceRoot, function()
    sendFullPicksHistoryToClient(client)
end)

-- Обработчики подключения игроков
addEventHandler("onPlayerJoin", root, function()
    setTimer(function(player)
        if isElement(player) then
            syncData(player)
            triggerClientEvent(player, "onUpdateTeamTimers", resourceRoot, team1Time, team2Time, activeTeam)
            triggerClientEvent(player, "onUpdateTimerState", resourceRoot, isTimer1Active, isTimer2Active)
            sendFullPicksHistoryToClient(player)
        end
    end, 2000, 1, source)
end)

addEventHandler("onPlayerLogin", root, function()
    setTimer(function(player)
        if isElement(player) then
            syncData(player)
            triggerClientEvent(player, "onUpdateTeamTimers", resourceRoot, team1Time, team2Time, activeTeam)
            triggerClientEvent(player, "onUpdateTimerState", resourceRoot, isTimer1Active, isTimer2Active)
            sendFullPicksHistoryToClient(player)

            -- Синхронизируем состояние панели
            if globalPanelState ~= nil then
                setElementData(player, "ccmode_forced_state", globalPanelState)
                triggerClientEvent(player, "onForcePanelOpen", resourceRoot, globalPanelState)
            end
        end
    end, 2000, 1, source)
end)

-- Запрос текущих таймеров
addEvent("requestCurrentTimers", true)
addEventHandler("requestCurrentTimers", resourceRoot, function()
    triggerClientEvent(client, "onUpdateTeamTimers", resourceRoot, team1Time, team2Time, activeTeam)
    triggerClientEvent(client, "onUpdateTimerState", resourceRoot, isTimer1Active, isTimer2Active)
end)

-- Синхронизация данных
function syncData(player)
    local clientMaps = {}
    for category, mapList in pairs(maps) do
        clientMaps[category] = {}
        for _, mapInfo in ipairs(mapList) do
            table.insert(clientMaps[category], mapInfo.name)
        end
    end

    local turnData = nil
    if isProcessActive and actionQueue[currentTurn] then
        turnData = {
            action = actionQueue[currentTurn].action,
            captain = actionQueue[currentTurn].captain,
            categoryStats = captainCategoryStats
        }
    end

    local matchData = {
        isMatchInProgress = isMatchInProgress,
        isFirstRound = isFirstRound,
        isWaitingForReady = isWaitingForReady,
        currentMapIndex = currentMapIndex,
        selectedMapsCount = selectedMaps and #selectedMaps or 0
    }

    triggerClientEvent(player or root, "onSyncData", resourceRoot,
        teams, captainNames, clientMaps, banList, pickList, turnData, matchData)

    triggerClientEvent(player or root, "onUpdateTeamTimers", resourceRoot, team1Time, team2Time, activeTeam)
    triggerClientEvent(player or root, "onUpdateTimerState", resourceRoot, isTimer1Active, isTimer2Active)
end

-- Функция для принудительной синхронизации состояния таймеров
function syncTimerState(player)
    triggerClientEvent(player or root, "onUpdateTimerState", resourceRoot, isTimer1Active, isTimer2Active)
    triggerClientEvent(player or root, "onUpdateTeamTimers", resourceRoot, team1Time, team2Time, activeTeam)
end

-- Запрос начальных данных
addEvent("requestInitialData", true)
addEventHandler("requestInitialData", resourceRoot, function()
    local clientMaps = {}
    for category, mapList in pairs(maps) do
        clientMaps[category] = {}
        for _, mapInfo in ipairs(mapList) do
            table.insert(clientMaps[category], mapInfo.name)
        end
    end
    triggerClientEvent(client, "onInitialDataReceived", resourceRoot, clientMaps)
end)

-- Установка команд
addEvent("onSetTeams", true)
addEventHandler("onSetTeams", resourceRoot, function(team1Name, team2Name)
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(client)), aclGetGroup("Admin")) then
        outputChatBox("[CC] Only admin can set team names!", client, 255, 0, 0)
        return
    end

    teams.Team1 = team1Name
    teams.Team2 = team2Name
    outputChatBox("[CC] Team names set: "..team1Name.." and "..team2Name, root, 0, 255, 0)
    syncData()
end)

-- Установка капитанов
addEvent("onSetCaptain1", true)
addEventHandler("onSetCaptain1", resourceRoot, function(captain1)
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(client)), aclGetGroup("Admin")) then
        outputChatBox("[CC] Only admin can assign captains!", client, 255, 0, 0)
        return
    end

    if captain1 and not isElement(captain1) then
        outputChatBox("[CC] Captain 1 is not online!", client, 255, 0, 0)
        return
    end

    if isProcessActive then
        for i, turnData in ipairs(actionQueue) do
            if turnData.captain == captainElements.Captain1 then
                turnData.captain = captain1
            end
        end

        if currentTurn <= #actionQueue and actionQueue[currentTurn].captain == captainElements.Captain1 then
            actionQueue[currentTurn].captain = captain1
        end
    end

    captainElements.Captain1 = captain1
    captainNames.Captain1 = captain1 and getPlayerName(captain1, true) or ""

    outputChatBox("[CC] Captain 1: "..(captainNames.Captain1 or "None"), root, 0, 255, 0)
    syncData()
end)

addEvent("onSetCaptain2", true)
addEventHandler("onSetCaptain2", resourceRoot, function(captain2)
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(client)), aclGetGroup("Admin")) then
        outputChatBox("[CC] Only admin can assign captains!", client, 255, 0, 0)
        return
    end

    if captain2 and not isElement(captain2) then
        outputChatBox("[CC] Captain 2 is not online!", client, 255, 0, 0)
        return
    end

    if isProcessActive then
        for i, turnData in ipairs(actionQueue) do
            if turnData.captain == captainElements.Captain2 then
                turnData.captain = captain2
            end
        end

        if currentTurn <= #actionQueue and actionQueue[currentTurn].captain == captainElements.Captain2 then
            actionQueue[currentTurn].captain = captain2
        end
    end

    captainElements.Captain2 = captain2
    captainNames.Captain2 = captain2 and getPlayerName(captain2, true) or ""

    outputChatBox("[CC] Captain 2: "..(captainNames.Captain2 or "None"), root, 0, 255, 0)
    syncData()
end)

-- Обработчик управления таймерами
addEvent("onTimerControl", true)
addEventHandler("onTimerControl", root, function(team, action)
    -- Проверяем права через ACL
    local account = getPlayerAccount(client)
    if not account or not isObjectInACLGroup("user."..getAccountName(account), aclGetGroup("Admin")) then
        outputChatBox("Only administrator can control timers!", client, 255, 0, 0)
        return
    end

    if team == 1 then
        if action == "start" then
            isTimer1Active = true
            outputChatBox("Team 1 timer started", root, 0, 255, 0)
        elseif action == "stop" then
            isTimer1Active = false
            outputChatBox("Team 1 timer stopped", root, 255, 0, 0)
        end
    elseif team == 2 then
        if action == "start" then
            isTimer2Active = true
            outputChatBox("Team 2 timer started", root, 0, 255, 0)
        elseif action == "stop" then
            isTimer2Active = false
            outputChatBox("Team 2 timer stopped", root, 255, 0, 0)
        end
    end

    -- Обновляем состояние таймеров у всех клиентов
    syncTimerState()

    -- Управляем таймером хода
    if isProcessActive then
        if turnTimer then
            if (activeTeam == 1 and not isTimer1Active) or (activeTeam == 2 and not isTimer2Active) then
                -- Останавливаем таймер, если активная команда остановила свой таймер
                killTimer(turnTimer)
                turnTimer = nil
            end
        else
            if (activeTeam == 1 and isTimer1Active) or (activeTeam == 2 and isTimer2Active) then
                -- Запускаем таймер, если активная команда запустила свой таймер
                startTurnTimer()
            end
        end
    end
end)

-- Команда для открытия панели у всех игроков
addCommandHandler("ccopen", function(player)
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(player)), aclGetGroup("Admin")) then
        outputChatBox("[CC] Only administrators can use this command!", player, 255, 0, 0)
        return
    end

    -- Устанавливаем принудительное открытое состояние для всех игроков
    for _, targetPlayer in ipairs(getElementsByType("player")) do
        setElementData(targetPlayer, "ccmode_forced_state", true)
    end

    triggerClientEvent(root, "onForcePanelOpen", resourceRoot, true)
    -- Синхронизируем данные чтобы панель не была пустой
    syncData()
    outputChatBox("[CC] Administrator "..getPlayerName(player, true).." has opened the Captain's Mode panel for all players!", root, 0, 255, 0)
end)

-- Команда для закрытия панели у всех игроков
addCommandHandler("ccclose", function(player)
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(player)), aclGetGroup("Admin")) then
        outputChatBox("[CC] Only administrators can use this command!", player, 255, 0, 0)
        return
    end

    -- Устанавливаем принудительное закрытое состояние для всех игроков
    for _, targetPlayer in ipairs(getElementsByType("player")) do
        setElementData(targetPlayer, "ccmode_forced_state", false)
    end

    -- Меняем событие на onForcePanelOpen с параметром false
    triggerClientEvent(root, "onForcePanelOpen", resourceRoot, false)
    outputChatBox("[CC] Administrator "..getPlayerName(player, true).." has closed the Captain's Mode panel for all players!", root, 255, 0, 0)
end)

-- Запуск Captain Cup
addEvent("startCaptainCup", true)
addEventHandler("startCaptainCup", resourceRoot, function()
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(client)), aclGetGroup("Admin")) then
        outputChatBox("[CC] Only admin can start Captain Cup!", client, 255, 0, 0)
        return
    end

    if isProcessActive then
        outputChatBox("[CC] Captain Cup is already running!", client, 255, 0, 0)
        return
    end

    if teams.Team1 == "" or teams.Team2 == "" then
        outputChatBox("[CC] Set both team names first!", client, 255, 0, 0)
        return
    end

    if captainElements.Captain1 == nil or captainElements.Captain2 == nil then
        outputChatBox("[CC] Assign both captains first!", client, 255, 0, 0)
        return
    end

    -- Инициализация
    team1Time = 450 --15 Секунд таймера
    team2Time = 450 --15 секунд таймера
    activeTeam = 1
    isTimer1Active = true
    isTimer2Active = true
    captainCategoryStats = { Captain1 = {}, Captain2 = {} }
    currentMapIndex = 0
    isFirstRound = true
    isWaitingForReady = false
    readyPlayers = {}

    -- Сохранение карт
    allMapsCopy = {}
    for category, mapList in pairs(maps) do
        allMapsCopy[category] = {}
        for _, mapInfo in ipairs(mapList) do
            table.insert(allMapsCopy[category], {
                name = mapInfo.name,
                resource = mapInfo.resource,
                path = mapInfo.path,
                category = category
            })
        end
    end

    -- Очередь действий
    actionQueue = {
        { action = "ban", captain = captainElements.Captain1 },
        { action = "ban", captain = captainElements.Captain2 },
        { action = "ban", captain = captainElements.Captain1 },
        { action = "ban", captain = captainElements.Captain2 },

        { action = "pick", captain = captainElements.Captain1 },
        { action = "pick", captain = captainElements.Captain2 },
        { action = "pick", captain = captainElements.Captain1 },
        { action = "pick", captain = captainElements.Captain2 },

        { action = "ban", captain = captainElements.Captain1 },
        { action = "ban", captain = captainElements.Captain2 },
        { action = "ban", captain = captainElements.Captain1 },
        { action = "ban", captain = captainElements.Captain2 },

        { action = "pick", captain = captainElements.Captain1 },
        { action = "pick", captain = captainElements.Captain2 },
        { action = "pick", captain = captainElements.Captain1 },
        { action = "pick", captain = captainElements.Captain2 },

        { action = "ban", captain = captainElements.Captain1 },
        { action = "ban", captain = captainElements.Captain2 },
        { action = "ban", captain = captainElements.Captain1 },
        { action = "ban", captain = captainElements.Captain2 },
        { action = "pick", captain = captainElements.Captain1 },
        { action = "pick", captain = captainElements.Captain2 }
    }

    isProcessActive = true
    isMatchInProgress = true
    currentTurn = 1
    banList = { BanTeam1 = {}, BanTeam2 = {} }
    pickList = { PickTeam1 = {}, PickTeam2 = {} }
    selectedMaps = {}

    -- Запуск процесса
    triggerClientEvent(root, "onUpdateTeamTimers", resourceRoot, team1Time, team2Time, activeTeam)
    triggerClientEvent(root, "onUpdateTimerState", resourceRoot, isTimer1Active, isTimer2Active)
    startTurnTimer()
    syncData()

    -- Сообщение о начале
    outputChatBox("════════════════════════════════════════", root, 255, 255, 0)
    outputChatBox("[CC] Captain Cup has started!", root, 0, 255, 0)
    outputChatBox("Team 1: "..teams.Team1.." | Captain: "..captainNames.Captain1, root, 255, 127, 80)
    outputChatBox("Team 2: "..teams.Team2.." | Captain: "..captainNames.Captain2, root, 0, 139, 139)
    outputChatBox("════════════════════════════════════════", root, 255, 255, 0)
end)

-- Обработчик бана/пика карты
addEvent("onBanPick", true)
addEventHandler("onBanPick", root, function(action, mapName)
    if not isProcessActive then
        outputChatBox("[CC] Captain mode is not active!", client, 255, 0, 0)
        return
    end

    local turnData = actionQueue[currentTurn]
    if turnData.captain ~= client then
        local expectedCaptain = (turnData.captain == captainElements.Captain1) and captainNames.Captain1 or captainNames.Captain2
        outputChatBox("[CC] Not your turn! Expected: " .. expectedCaptain, client, 255, 0, 0)
        return
    end

    if turnData.action ~= action then
        outputChatBox("[CC] Expected action " .. turnData.action .. ", not " .. action .. "!", client, 255, 0, 0)
        return
    end

    -- Проверяем доступность карта
    if not isMapAvailable(mapName) then
        outputChatBox("[CC] Map '"..mapName.."' doesn't exist or already picked/banned!", client, 255, 0, 0)
        return
    end

    local mapInfo, category = getMapInfo(mapName)
    if not mapInfo then
        outputChatBox("[CC] Error: map info not found!", client, 255, 0, 0)
        return
    end

    -- Проверка ограничения на выбор карт из одной категории
    if action == "pick" then
        local captainKey = (turnData.captain == captainElements.Captain1) and "Captain1" or "Captain2"
        local currentCount = captainCategoryStats[captainKey][category] or 0

        if currentCount >= 2 then
            outputChatBox("[CC] You've already picked maximum maps ("..currentCount..") from category "..category.."!", client, 255, 0, 0)
            return
        end
    end

    local playerName = getPlayerName(client, true)
    if action == "ban" then
        local teamKey = (turnData.captain == captainElements.Captain1) and "BanTeam1" or "BanTeam2"
        table.insert(banList[teamKey], mapName)
        outputChatBox("[CC] " .. playerName .. " banned map: " .. mapName, root, 255, 51, 51)
    elseif action == "pick" then
        local teamKey = (turnData.captain == captainElements.Captain1) and "PickTeam1" or "PickTeam2"
        table.insert(pickList[teamKey], mapName)
        outputChatBox("[CC] " .. playerName .. " picked map: " .. mapName, root, 0, 204, 0)

        -- Обновляем статистику по категориям
        local captainKey = (turnData.captain == captainElements.Captain1) and "Captain1" or "Captain2"
        captainCategoryStats[captainKey][category] = (captainCategoryStats[captainKey][category] or 0) + 1
    end

    -- Удаляем карту из всех категорий
    for category, mapList in pairs(maps) do
        for i = #mapList, 1, -1 do
            if mapList[i].name == mapName then
                table.remove(mapList, i)
                break
            end
        end
    end

    syncData()
    nextTurn()
end)

-- Проверка доступности карты
function isMapAvailable(mapName)
    for category, mapList in pairs(maps) do
        for _, mapInfo in ipairs(mapList) do
            if mapInfo.name == mapName then
                for _, ban in ipairs(banList.BanTeam1) do if ban == mapName then return false end end
                for _, ban in ipairs(banList.BanTeam2) do if ban == mapName then return false end end
                for _, pick in ipairs(pickList.PickTeam1) do if pick == mapName then return false end end
                for _, pick in ipairs(pickList.PickTeam2) do if pick == mapName then return false end end
                return true
            end
        end
    end
    return false
end

-- Получение информации о карте
function getMapInfo(mapName)
    for category, mapList in pairs(maps) do
        for _, mapInfo in ipairs(mapList) do
            if mapInfo.name == mapName then
                return mapInfo, category
            end
        end
    end
    return nil, nil
end

-- Запуск таймера хода
function startTurnTimer()
    if turnTimer then
        killTimer(turnTimer)
        turnTimer = nil
    end

    local turnData = actionQueue[currentTurn]
    if not turnData or not isProcessActive then return end

    activeTeam = (turnData.captain == captainElements.Captain1) and 1 or 2

    -- Проверяем, разрешено ли запускать таймер для активной команды
    if (activeTeam == 1 and not isTimer1Active) or (activeTeam == 2 and not isTimer2Active) then
        return -- Таймер остановлен администратором
    end

    triggerClientEvent(root, "onUpdateTeamTimers", resourceRoot, team1Time, team2Time, activeTeam)

    -- Запускаем таймер только если процесс активен и таймер разрешен
    turnTimer = setTimer(function()
        if not isProcessActive then
            if turnTimer then
                killTimer(turnTimer)
                turnTimer = nil
            end
            return
        end

        -- Проверяем, не остановлен ли таймер администратором
        if (activeTeam == 1 and not isTimer1Active) or (activeTeam == 2 and not isTimer2Active) then
            return
        end

        if activeTeam == 1 then
            if team1Time > 0 then
                team1Time = team1Time - 1
                triggerClientEvent(root, "onUpdateTeamTimers", resourceRoot, team1Time, team2Time, activeTeam)
            else
                timeExpired()
            end
        else
            if team2Time > 0 then
                team2Time = team2Time - 1
                triggerClientEvent(root, "onUpdateTeamTimers", resourceRoot, team1Time, team2Time, activeTeam)
            else
                timeExpired()
            end
        end
    end, 1000, 0)
end

-- Обработчик истечения времени
function timeExpired()
    if not isProcessActive then return end

    local turnData = actionQueue[currentTurn]
    if not turnData then return end

    -- Проверяем, не остановлен ли таймер администратором
    if (activeTeam == 1 and not isTimer1Active) or (activeTeam == 2 and not isTimer2Active) then
        return
    end

    local captainName = (turnData.captain == captainElements.Captain1) and captainNames.Captain1 or captainNames.Captain2
    local teamKey = (turnData.captain == captainElements.Captain1) and "Team1" or "Team2"

    outputChatBox("[CC] Time's up for " .. captainName .. "! Selecting random map...", root, 255, 0, 0)
    fillRemainingSlots(teamKey)
end

-- Автоматический выбор карты при истечении времени
function fillRemainingSlots(teamKey)
    local availableMaps = getAllAvailableMaps()

    if #availableMaps == 0 then
        outputChatBox("[CC] No available maps for auto-selection!", root, 255, 0, 0)
        nextTurn()
        return
    end

    local turnData = actionQueue[currentTurn]
    local randomMap = availableMaps[math.random(1, #availableMaps)]

    if turnData.action == "ban" then
        table.insert(banList["Ban"..teamKey], randomMap.name)
        outputChatBox("[CC] Auto-ban for "..teamKey..": "..randomMap.name, root, 255, 165, 0)
    else
        table.insert(pickList["Pick"..teamKey], randomMap.name)
        outputChatBox("[CC] Auto-pick for "..teamKey..": "..randomMap.name, root, 0, 255, 255)

        local captainKey = (turnData.captain == captainElements.Captain1) and "Captain1" or "Captain2"
        captainCategoryStats[captainKey][randomMap.category] = (captainCategoryStats[captainKey][randomMap.category] or 0) + 1
    end

    for category, mapList in pairs(maps) do
        for i = #mapList, 1, -1 do
            if mapList[i].name == randomMap.name then
                table.remove(mapList, i)
                break
            end
        end
    end

    syncData()
    nextTurn()
end

-- Получение всех доступных карт
function getAllAvailableMaps()
    local availableMaps = {}
    for category, mapList in pairs(maps) do
        for _, mapInfo in ipairs(mapList) do
            local isUsed = false
            for _, ban in ipairs(banList.BanTeam1) do if ban == mapInfo.name then isUsed = true break end end
            for _, ban in ipairs(banList.BanTeam2) do if ban == mapInfo.name then isUsed = true break end end
            for _, pick in ipairs(pickList.PickTeam1) do if pick == mapInfo.name then isUsed = true break end end
            for _, pick in ipairs(pickList.PickTeam2) do if pick == mapInfo.name then isUsed = true break end end

            if not isUsed then
                table.insert(availableMaps, {
                    name = mapInfo.name,
                    category = category,
                    path = mapInfo.path,
                    resource = mapInfo.resource
                })
            end
        end
    end
    return availableMaps
end

-- Переход к следующему ходу
function nextTurn()
    if turnTimer then
        killTimer(turnTimer)
        turnTimer = nil
    end

    currentTurn = currentTurn + 1

    if currentTurn > #actionQueue then
        isProcessActive = false
        activeTeam = nil
        isMatchInProgress = true
        currentMapIndex = 0

        -- Сохраняем выбранные карты
        selectedMaps = getSelectedMapResources()

        -- Формируем текст истории пиков
        draftPicksHistory = "[CC]═╣ Ban/Pick process completed! ╠═\n\n"
        draftPicksHistory = draftPicksHistory .. "[CC] Selected maps:\n"

        local allPicks = {}
        local team1Picks = pickList.PickTeam1 or {}
        local team2Picks = pickList.PickTeam2 or {}
        local maxPicks = math.max(#team1Picks, #team2Picks)

        for i = 1, maxPicks do
            if team1Picks[i] then
                table.insert(allPicks, {
                    name = team1Picks[i],
                    team = teams.Team1
                })
            end
            if team2Picks[i] then
                table.insert(allPicks, {
                    name = team2Picks[i],
                    team = teams.Team2
                })
            end
        end

        outputChatBox(" ", root, 0, 255, 0)
        outputChatBox("[CC]═╣ Ban/Pick process completed! ╠═", root, 0, 255, 255)
        outputChatBox(" ", root, 0, 255, 0)
        outputChatBox("[CC] Selected maps", root, 0, 255, 255)

        for i, pick in ipairs(allPicks) do
            local line = "Map №"..i.." - "..pick.name.." | Picked by: "..pick.team
            outputChatBox(line, root, 0, 255, 0)
            draftPicksHistory = draftPicksHistory .. line .. "\n"
        end

        triggerClientEvent(root, "onDraftPicksUpdate", resourceRoot, draftPicksHistory)

        outputChatBox(" ", root, 0, 255, 0)
        outputChatBox("[CC] Captains, write /rdy when ready to start the first map", root, 255, 255, 0)
        outputChatBox(" ", root, 0, 255, 0)

        actionQueue = {}
        currentTurn = 1
    else
        local turnData = actionQueue[currentTurn]
        local nextCaptainName = (turnData.captain == captainElements.Captain1) and captainNames.Captain1 or captainNames.Captain2
        outputChatBox("[CC] Turn for " .. nextCaptainName .. " (" .. turnData.action .. ")", root, 255, 255, 0)

        activeTeam = (turnData.captain == captainElements.Captain1) and 1 or 2
        triggerClientEvent(root, "onUpdateTeamTimers", resourceRoot, team1Time, team2Time, activeTeam)
        startTurnTimer()
    end

    syncData()
end

-- Получение выбранных карт с ресурсами
function getSelectedMapResources()
    local mapResources = {}
    local allMaps = {}

    for category, mapList in pairs(allMapsCopy) do
        for _, mapInfo in ipairs(mapList) do
            allMaps[mapInfo.name] = {
                name = mapInfo.name,
                resource = mapInfo.resource,
                category = category
            }
        end
    end

    local allPicks = {}
    local maxPicks = math.max(#pickList.PickTeam1, #pickList.PickTeam2)

    for i = 1, maxPicks do
        if pickList.PickTeam1[i] then
            table.insert(allPicks, {
                name = pickList.PickTeam1[i],
                team = teams.Team1
            })
        end
        if pickList.PickTeam2[i] then
            table.insert(allPicks, {
                name = pickList.PickTeam2[i],
                team = teams.Team2
            })
        end
    end

    for _, pick in ipairs(allPicks) do
        local mapData = allMaps[pick.name]
        if mapData then
            table.insert(mapResources, {
                name = mapData.name,
                resource = mapData.resource,
                team = pick.team,
                category = mapData.category
            })
        else
            outputDebugString("[CC] Resource not found for map: "..pick.name, 2)
        end
    end

    return mapResources
end

-- Обработчик завершения раунда
function onRoundEnded()
    if not isMatchInProgress then return end

    currentRoundEnded = true
    isWaitingForReady = true
    readyPlayers = {}

    local nextMapIndex = currentMapIndex + 1
    local nextMap = selectedMaps[nextMapIndex]

    if not nextMap then
        outputChatBox("[CC] All rounds completed! Match finished.", root, 0, 255, 255)
        isMatchInProgress = false
        return
    end

    outputChatBox("════════════════════════════════════════", root, 255, 255, 0)
    outputChatBox("[CC] Round has been ended!", root, 0, 255, 255)
    outputChatBox("Next map: "..nextMap.name, root, 0, 255, 0)
    outputChatBox("Category: "..nextMap.category, root, 0, 255, 255)
    outputChatBox("Pick by: "..nextMap.team, root, 0, 255, 255)
    outputChatBox("[CC] Captains, write /rdy to continue", root, 0, 255, 255)
    outputChatBox("════════════════════════════════════════", root, 255, 255, 0)
end

-- Обработчик события из race league
addEvent("onRaceRoundFinished", true)
addEventHandler("onRaceRoundFinished", root, function()
    outputDebugString("onRaceRoundFinished received", 3)
    onRoundEnded()
end)

-- Команда готовности
function playerReady(player)
    if not isMatchInProgress then
        outputChatBox("[CC] Match not started or already finished!", player, 255, 0, 0)
        return
    end

    local isCaptain = false
    local captainKey = nil

    if player == captainElements.Captain1 then
        isCaptain = true
        captainKey = "Captain1"
    elseif player == captainElements.Captain2 then
        isCaptain = true
        captainKey = "Captain2"
    end

    if not isCaptain then
        outputChatBox("[CC] Only captains can use this command!", player, 255, 0, 0)
        return
    end

    if not currentRoundEnded and not isFirstRound then
        outputChatBox("[CC] You can't use this command now!", player, 255, 0, 0)
        outputChatBox("[CC] Wait for the current round to end", player, 255, 0, 0)
        return
    end

    if readyPlayers[player] then
        outputChatBox("[CC] You've already confirmed readiness!", player, 255, 255, 0)
        return
    end

    readyPlayers[player] = true
    local captainName = getPlayerName(player, true)
    outputChatBox(captainName.." is ready for the next round!", root, 0, 255, 0)

    local captain1Ready = not isElement(captainElements.Captain1) or readyPlayers[captainElements.Captain1]
    local captain2Ready = not isElement(captainElements.Captain2) or readyPlayers[captainElements.Captain2]

    if captain1Ready and captain2Ready then
        isWaitingForReady = false
        currentRoundEnded = false
        if isFirstRound then
            isFirstRound = false
        end
        startNextMap()
    end
end
addCommandHandler("rdy", playerReady)

-- Запуск следующей карты
function startNextMap()
    if not selectedMaps or #selectedMaps == 0 then
        selectedMaps = getSelectedMapResources()
        if not selectedMaps or #selectedMaps == 0 then
            outputChatBox("[CC] Error: no selected maps found!", root, 255, 0, 0)
            return false
        end
    end

    if currentMapIndex >= #selectedMaps then
        outputChatBox("[CC] GGWP", root, 0, 255, 0)
        isMatchInProgress = false
        return false
    end

    currentMapIndex = currentMapIndex + 1
    local currentMap = selectedMaps[currentMapIndex]

    if not currentMap then
        outputChatBox("[CC] Error: map data not found!", root, 255, 0, 0)
        return false
    end

    local mapResource = getResourceFromName(currentMap.resource)
    if not mapResource then
        outputChatBox("[CC] Map resource '"..currentMap.resource.."' not found!", root, 255, 0, 0)
        return false
    end

    -- Остановка текущей карты
    local currentResource = getElementData(root, "currentMap.resource")
    if currentResource then
        local runningResource = getResourceFromName(currentResource)
        if runningResource and getResourceState(runningResource) == "running" then
            if not stopResource(runningResource) then
                outputDebugString("[CC] Failed to stop current map", 2)
            end
        end
    end

    -- Запуск новой карты
    local success, err = pcall(function()
        if getResourceState(mapResource) ~= "running" then
            if startResource(mapResource) then
                outputChatBox("[CC] Resource "..currentMap.resource.." started automatically", root, 0, 255, 255)
            else
                error("Failed to start map resource")
            end
        else
            outputChatBox("[CC] Resource "..currentMap.resource.." is already running", root, 0, 255, 255)
        end
    end)

    if not success then
        outputDebugString("[CC] Error processing map "..currentMap.resource..": "..tostring(err), 2)
        return false
    end

    -- Обновление информации
    setElementData(root, "currentMap", {
        name = currentMap.name,
        resource = currentMap.resource,
        index = currentMapIndex,
        total = #selectedMaps,
        team = currentMap.team,
        category = currentMap.category
    })

    outputChatBox("════════════════════════════════════════", root, 255, 255, 0)
    outputChatBox("[CC] Round № "..currentMapIndex, root, 0, 255, 0)
    outputChatBox("Map: "..currentMap.name, root, 255, 255, 0)
    outputChatBox("Category: "..currentMap.category, root, 255, 255, 0)
    outputChatBox("Pick by: "..currentMap.team, root, 255, 255, 0)
    outputChatBox("════════════════════════════════════════", root, 255, 255, 0)

    return true
end

-- Команда для принудильного завершения раунда
addCommandHandler("forceroundend", function(player)
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(player)), aclGetGroup("Admin")) then
        outputChatBox("[CC] Only for admins", player, 255, 0, 0)
        return
    end
    outputChatBox("[CC] Admin forced round end", root, 255, 0, 0)
    onRoundEnded()
end)

-- Команда для проверки состояния
addCommandHandler("checkround", function(player)
    local stateNames = {
        ["DRAFT"] = "Draft",
        ["WAITING"] = "Waiting for ready",
        ["PLAYING"] = "Round in progress",
        ["ENDED"] = "Round ended"
    }

    local currentState = "DRAFT"
    if isMatchInProgress then
        if isWaitingForReady then
            currentState = "WAITING"
        else
            currentState = "PLAYING"
        end
    end

    outputChatBox("Current system state:", player, 0, 255, 0)
    outputChatBox("State: "..(stateNames[currentState] or currentState), player)
    outputChatBox("isFirstRound: "..tostring(isFirstRound), player)
    outputChatBox("isWaitingForReady: "..tostring(isWaitingForReady), player)
    outputChatBox("Captains readiness:", player)
    outputChatBox(captainNames.Captain1..": "..tostring(readyPlayers[captainElements.Captain1]), player)
    outputChatBox(captainNames.Captain2..": "..tostring(readyPlayers[captainElements.Captain2]), player)

    local currentMap = getElementData(root, "currentMap")
    if currentMap then
        outputChatBox("Current map: "..currentMap.name.." ("..currentMap.index.."/"..currentMap.total..")", player)
    end
end)

-- Серверный таймер для обновления времени
--setTimer(function()
  --  if isProcessActive and activeTeam then
    --    if activeTeam == 1 and isTimer1Active and team1Time > 0 then
      --      team1Time = team1Time - 1
       --     triggerClientEvent(root, "onUpdateTeamTimers", resourceRoot, team1Time, team2Time, activeTeam)
        -- elseif activeTeam == 2 and isTimer2Active and team2Time > 0 then
--            team2Time = team2Time - 1
  --          triggerClientEvent(root, "onUpdateTeamTimers", resourceRoot, team1Time, team2Time, activeTeam)
    --    end
--    end
-- end, 1000, 0)
