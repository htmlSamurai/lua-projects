-- Серверная часть Captain's Mode
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
local team1Time = 15
local team2Time = 15
local activeTeam = nil
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
local roundEndDetectionEnabled = true
local currentRoundEnded = false -- Добавляем флаг завершения раунда
local draftPicksText = ""
local draftPicksHistory = "" -- Отдельная переменная для истории пиков

-- Добавить в server.lua где-нибудь в начале (после объявления переменных)
addEventHandler("onPlayerJoin", root, function()
    -- Ждем немного, чтобы игрок успел загрузиться
    setTimer(function(player)
        if isElement(player) then
            syncData(player) -- Отправляем текущие данные новому игроку

            -- Если есть история драфта, отправляем ее
            if draftHistory and #draftHistory > 0 then
                triggerClientEvent(player, "onDraftHistoryUpdate", resourceRoot, draftHistory)
            end
        end
    end, 1000, 1, source)
end)

-- Также добавить обработчик для переподключившихся игроков
addEventHandler("onPlayerLogin", root, function()
    setTimer(function(player)
        if isElement(player) then
            syncData(player)
            if draftHistory and #draftHistory > 0 then
                triggerClientEvent(player, "onDraftHistoryUpdate", resourceRoot, draftHistory)
            end
        end
    end, 1000, 1, source)
end)

-- Загрузка карт из JSON (без изменений)
addEventHandler("onResourceStart", resourceRoot, function()
    local mapsFile = fileOpen("maps.json")
    if mapsFile then
        local content = fileRead(mapsFile, fileGetSize(mapsFile))
        fileClose(mapsFile)
        maps = fromJSON(content)
        outputDebugString("[CC]Карты успешно загружены из JSON", 0)
    else
        outputDebugString("[CC]Ошибка загрузки файла карт!", 1)
    end

    if not hasStartResourcePermission then
        outputDebugString("[CC]ВНИМАНИЕ: Ресурс не имеет прав на запуск других ресурсов!", 1)
    end
end)

-- Переработанный обработчик завершения раунда
function onRoundEnded()
    if not isMatchInProgress then return end

    currentRoundEnded = true
    isWaitingForReady = true
    readyPlayers = {} -- Сбрасываем готовность капитанов

    local nextMapIndex = currentMapIndex + 1
    local nextMap = selectedMaps[nextMapIndex]

    if not nextMap then
        outputChatBox("[CC]Все раунды завершены! Матч окончен.", root, 0, 255, 255)
        isMatchInProgress = false
        return
    end

    outputChatBox("════════════════════════════════════════", root, 255, 255, 0)
    outputChatBox("[CC]Round has been ended!", root, 0, 255, 255)
    outputChatBox("Next map: "..nextMap.name, root, 0, 255, 0)
    outputChatBox("Category: "..nextMap.category, root, 0, 255, 255)
    outputChatBox("Pick by: "..nextMap.team, root, 0, 255, 255)
    outputChatBox("[CC]Captains, write /rdy to continue", root, 0, 255, 255)
    outputChatBox("════════════════════════════════════════", root, 255, 255, 0)
end

-- Обработчик события из race league
addEvent("onRaceRoundFinished", true)
addEventHandler("onRaceRoundFinished", root, function()
    onRoundEnded()
end)

-- Переработанная команда готовности
function playerReady(player)
    if not isMatchInProgress then
        outputChatBox("[CC]Match not started or already finished!", player, 255, 0, 0)
        return
    end

    -- Проверяем, является ли игрок капитаном
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
        outputChatBox("[CC]Only captains can use this command!", player, 255, 0, 0)
        return
    end

    -- Проверяем состояние матча
    if not currentRoundEnded and not isFirstRound then
        outputChatBox("[CC]You can't use this command now!", player, 255, 0, 0)
        outputChatBox("[CC]Wait for the current round to end", player, 255, 0, 0)
        return
    end

    -- Проверяем, не подтверждал ли уже капитан готовность
    if readyPlayers[player] then
        outputChatBox("[CC]You've already confirmed readiness!", player, 255, 255, 0)
        return
    end

    -- Отмечаем капитана как готового
    readyPlayers[player] = true
    local captainName = getPlayerName(player, true)
    outputChatBox(captainName.."  is ready for the next round!", root, 0, 255, 0)

    -- Проверяем готовность обоих капитанов
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
            outputChatBox("[CC] Ошибка: не найдены выбранные карты!", root, 255, 0, 0)
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
        outputChatBox("[CC] Map resource'"..currentMap.resource.."' not found!", root, 255, 0, 0)
        return false
    end

    -- Остановка текущей карты
    local currentResource = getElementData(root, "currentMap.resource")
    if currentResource then
        local runningResource = getResourceFromName(currentResource)
        if runningResource and getResourceState(runningResource) == "running" then
            if not stopResource(runningResource) then
                outputDebugString("[CC] Не удалось остановить текущую карту", 2)
            end
        end
    end

    -- Запуск новой карты
    local success, err = pcall(function()
        if getResourceState(mapResource) ~= "running" then
            if startResource(mapResource) then
                outputChatBox("[CC] Ресурс "..currentMap.resource.." автоматически запущен", root, 0, 255, 255)
            else
                error("Не удалось запустить ресурс карты")
            end
        else
            outputChatBox("[CC] Ресурс "..currentMap.resource.." уже запущен", root, 0, 255, 255)
        end
    end)

    if not success then
        -- Убираем ложное сообщение об ошибке
        outputDebugString("[CC] Ошибка при обработке карты "..currentMap.resource..": "..tostring(err), 2)
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

    -- Отправляем все данные, включая историю драфта
    triggerClientEvent(player or root, "onSyncData", resourceRoot,
            teams, captainNames, clientMaps, banList, pickList, turnData, matchData)
    triggerClientEvent(player or root, "onUpdateTimerState", resourceRoot, isTimer1Active, isTimer2Active)

    -- Отправляем историю драфта, если она есть
    if draftHistory and #draftHistory > 0 then
        triggerClientEvent(player or root, "onDraftHistoryUpdate", resourceRoot, draftHistory)
    end
end

-- Запуск Captain Cup
function startCaptainCup()
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(client)), aclGetGroup("Admin")) then
        outputChatBox("[CC]Только администратор может начать Captain Cup!", client, 255, 0, 0)
        return
    end

    if isProcessActive then
        outputChatBox("[CC Admin]Captain Cup уже запущен!", client, 255, 0, 0)
        return
    end

    if teams.Team1 == "" or teams.Team2 == "" then
        outputChatBox("[CC Admin]Сначала установите названия обеих команд!", client, 255, 0, 0)
        return
    end

    if captainElements.Captain1 == nil or captainElements.Captain2 == nil then
        outputChatBox("[CC Admin]Сначала установите капитанов обеих команд!", client, 255, 0, 0)
        return
    end

    -- Инициализация
    team1Time = 15
    team2Time = 15
    activeTeam = 1
    isTimer1Active = true
    isTimer2Active = true
    captainCategoryStats = { Captain1 = {}, Captain2 = {} }
    currentMapIndex = 0
    isFirstRound = true
    isWaitingForReady = false
    readyPlayers = {}
    roundEndDetectionEnabled = true

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
    outputChatBox("[CC]CC Match has started!", root, 0, 255, 0)
    outputChatBox("Team 1: "..teams.Team1.." | Captain: "..captainNames.Captain1, root, 255, 127, 80)
    outputChatBox("Team 2: "..teams.Team2.." | Captain: "..captainNames.Captain2, root, 0, 139, 139)
    outputChatBox("════════════════════════════════════════", root, 255, 255, 0)
end
addEvent("startCaptainCup", true)
addEventHandler("startCaptainCup", resourceRoot, startCaptainCup)

-- Обработчик бана/пика карты
addEvent("onBanPick", true)
addEventHandler("onBanPick", root, function(action, mapName)
    if not isProcessActive then
        outputChatBox("[CC]Captain mode is not active!", client, 255, 0, 0)
        return
    end

    local turnData = actionQueue[currentTurn]
    if turnData.captain ~= client then
        local expectedCaptain = (turnData.captain == captainElements.Captain1) and captainNames.Captain1 or captainNames.Captain2
        outputChatBox("[CC]Not your turn! Expected: " .. expectedCaptain, client, 255, 0, 0)
        return
    end

    if turnData.action ~= action then
        outputChatBox("[CC]Expected action " .. turnData.action .. ", not " .. action .. "!", client, 255, 0, 0)
        return
    end

    -- Проверяем доступность карты
    if not isMapAvailable(mapName) then
        outputChatBox("[CC]Map '"..mapName.."' doesn't exist or already picked/banned!", client, 255, 0, 0)
        return
    end

    local mapInfo, category = getMapInfo(mapName)
    if not mapInfo then
        outputChatBox("[CC]Error: map info not found!", client, 255, 0, 0)
        return
    end

    -- Проверка ограничения на выбор карт из одной категории (только для пиков)
    if action == "pick" then
        local captainKey = (turnData.captain == captainElements.Captain1) and "Captain1" or "Captain2"
        local currentCount = captainCategoryStats[captainKey][category] or 0

        -- Если уже выбрано 2 карты из этой категории
        if currentCount >= 2 then
            outputChatBox("[CC]You've already picked maximum maps ("..currentCount..") from category "..category.."!", client, 255, 0, 0)
            return
        end
    end

    local playerName = getPlayerName(client, true)
    if action == "ban" then
        local teamKey = (turnData.captain == captainElements.Captain1) and "BanTeam1" or "BanTeam2"
        table.insert(banList[teamKey], mapName)
        outputChatBox("[CC]" .. playerName .. " banned map: " .. mapName, root, 255, 165, 0)
    elseif action == "pick" then
        local teamKey = (turnData.captain == captainElements.Captain1) and "PickTeam1" or "PickTeam2"
        table.insert(pickList[teamKey], mapName)
        outputChatBox("[CC]" .. playerName .. " picked map: " .. mapName, root, 0, 255, 255)

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

    -- Синхронизируем изменения с клиентами
    syncData()
    nextTurn()
end)

-- Функция проверки доступности карты
function isMapAvailable(mapName)
    for category, mapList in pairs(maps) do
        for _, mapInfo in ipairs(mapList) do
            if mapInfo.name == mapName then
                -- Проверяем, не забанена ли карта и не выбрана ли уже
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
        local picksHistoryText = "[CC]═╣ Ban/Pick process completed! ╠═\n\n"
        picksHistoryText = picksHistoryText .. "[CC]Selected maps:\n"

        -- Получаем все пики в правильном порядке
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

        -- Формируем текст для истории и чата
        outputChatBox(" ", root, 0, 255, 0)
        outputChatBox("[CC]═╣ Ban/Pick process completed! ╠═", root, 0, 255, 255)
        outputChatBox(" ", root, 0, 255, 0)
        outputChatBox("[CC]Selected maps", root, 0, 255, 255)

        for i, pick in ipairs(allPicks) do
            local line = "Map №"..i.." - "..pick.name.." | Picked by: "..pick.team
            outputChatBox(line, root, 0, 255, 0)
            picksHistoryText = picksHistoryText .. line .. "\n"
        end

        -- Сохраняем историю в глобальную переменную
        draftPicksHistory = picksHistoryText

        -- Отправляем историю всем клиентам
        triggerClientEvent(root, "onDraftPicksUpdate", resourceRoot, draftPicksHistory)

        outputChatBox(" ", root, 0, 255, 0)
        outputChatBox("[CC]Captains, write /rdy when ready to start the first map", root, 0, 255, 255)
        outputChatBox(" ", root, 0, 255, 0)

        actionQueue = {}
        currentTurn = 1
    else
        local turnData = actionQueue[currentTurn]
        local nextCaptainName = (turnData.captain == captainElements.Captain1) and captainNames.Captain1 or captainNames.Captain2
        outputChatBox("[CC]Turn for " .. nextCaptainName .. " (" .. turnData.action .. ")", root, 0, 255, 0)

        activeTeam = (turnData.captain == captainElements.Captain1) and 1 or 2
        triggerClientEvent(root, "onUpdateTeamTimers", resourceRoot, team1Time, team2Time, activeTeam)
        startTurnTimer()
    end

    syncData()
end

-- Запуск таймера хода
function startTurnTimer()
    if turnTimer then
        killTimer(turnTimer)
        turnTimer = nil
    end

    local turnData = actionQueue[currentTurn]
    if not turnData then return end

    activeTeam = (turnData.captain == captainElements.Captain1) and 1 or 2

    triggerClientEvent(root, "onUpdateTeamTimers", resourceRoot, team1Time, team2Time, activeTeam)

    -- Запускаем таймер только если процесс активен
    if isProcessActive then
        turnTimer = setTimer(function()
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
end

-- Обработчик истечения времени
function timeExpired()
    if not isProcessActive then return end

    local turnData = actionQueue[currentTurn]
    if not turnData then return end

    local captainName = (turnData.captain == captainElements.Captain1) and captainNames.Captain1 or captainNames.Captain2
    local teamKey = (turnData.captain == captainElements.Captain1) and "Team1" or "Team2"

    outputChatBox("[CC]Time's up for" .. captainName .. "! Selecting random map...", root, 255, 0, 0)
    fillRemainingSlots(teamKey)
end

-- Автоматический выбор карты при истечении времени
function fillRemainingSlots(teamKey)
    local availableMaps = getAllAvailableMaps()

    if #availableMaps == 0 then
        outputChatBox("[CC]No available maps for auto-selection!", root, 255, 0, 0)
        nextTurn()
        return
    end

    local turnData = actionQueue[currentTurn]
    local randomMap = availableMaps[math.random(1, #availableMaps)]

    if turnData.action == "ban" then
        table.insert(banList["Ban"..teamKey], randomMap.name)
        outputChatBox("[CC]Auto-ban for "..teamKey..": "..randomMap.name, root, 255, 165, 0)
    else
        table.insert(pickList["Pick"..teamKey], randomMap.name)
        outputChatBox("[CC]Auto-pick for "..teamKey..": "..randomMap.name, root, 0, 255, 255)

        -- Обновляем статистику по категориям
        local captainKey = (turnData.captain == captainElements.Captain1) and "Captain1" or "Captain2"
        captainCategoryStats[captainKey][randomMap.category] = (captainCategoryStats[captainKey][randomMap.category] or 0) + 1
    end

    -- Удаляем карту из всех категорий
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

-- Получение выбранных карт с ресурсами
function getSelectedMapResources()
    local mapResources = {}
    local allMaps = {}

    -- Собираем все карты из всех категорий для поиска
    for category, mapList in pairs(allMapsCopy) do
        for _, mapInfo in ipairs(mapList) do
            allMaps[mapInfo.name] = {
                name = mapInfo.name,
                resource = mapInfo.resource,
                category = category
            }
        end
    end

    -- Собираем все выбранные карты в правильном порядке
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

    -- Находим ресурсы для каждой карты
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
            outputDebugString("[CC]Не найден ресурс для карты: "..pick.name, 2)
        end
    end

    return mapResources
end

-- Обработчик запроса начальных данных
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

-- Добавьте новый обработчик для запроса истории пиков:
addEvent("requestFullPicksHistory", true)
addEventHandler("requestFullPicksHistory", resourceRoot, function()
    triggerClientEvent(client, "onDraftPicksUpdate", resourceRoot, draftPicksHistory)
end)

-- Обработчик установки команд
addEvent("onSetTeams", true)
addEventHandler("onSetTeams", resourceRoot, function(team1Name, team2Name)
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(client)), aclGetGroup("Admin")) then
        outputChatBox("[CC]Only admin can set team names!", client, 255, 0, 0)
        return
    end

    teams.Team1 = team1Name
    teams.Team2 = team2Name
    outputChatBox("[CC]Team names has been changed "..team1Name.." и "..team2Name, root, 0, 255, 0)
    syncData()
end)

-- Обработчик установки капитанов
addEvent("onSetCaptain1", true)
addEventHandler("onSetCaptain1", resourceRoot, function(captain1)
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(client)), aclGetGroup("Admin")) then
        outputChatBox("[CC]Only admin can give captain role!", client, 255, 0, 0)
        return
    end

    if captain1 and not isElement(captain1) then
        outputChatBox("[CC]Капитан 1 не в сети!", client, 255, 0, 0)
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

    outputChatBox("[CC]Captain 1: "..(captainNames.Captain1 or "no"), root, 0, 255, 0)
    syncData()
end)

addEvent("onSetCaptain2", true)
addEventHandler("onSetCaptain2", resourceRoot, function(captain2)
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(client)), aclGetGroup("Admin")) then
        outputChatBox("[CC]Only admin can give captain role!", client, 255, 0, 0)
        return
    end

    if captain2 and not isElement(captain2) then
        outputChatBox("[CC]Капитан 2 не в сети!", client, 255, 0, 0)
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

    outputChatBox("[CC]Captain 2: "..(captainNames.Captain2 or "Нет"), root, 0, 255, 0)
    syncData()
end)

addEvent("checkPlayerPermission", true)
addEventHandler("checkPlayerPermission", resourceRoot, function()
    local hasPermission = hasObjectPermissionTo(client, "command.start", false)
    triggerClientEvent(client, "onPermissionCheckResult", resourceRoot, hasPermission)
end)

-- Обработчик управления таймерами
addEvent("onTimerControl", true)
addEventHandler("onTimerControl", resourceRoot, function(team, action)
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(client)), aclGetGroup("Admin")) then
        outputChatBox("[CC]Only admin can control timer", client, 255, 0, 0)
        return
    end

    if team == 1 then
        if action == "start" then
            isTimer1Active = true
        elseif action == "stop" then
            isTimer1Active = false
        end
    elseif team == 2 then
        if action == "start" then
            isTimer2Active = true
        elseif action == "stop" then
            isTimer2Active = false
        end
    end

    triggerClientEvent(root, "onUpdateTimerState", resourceRoot, isTimer1Active, isTimer2Active)
end)

-- Команда для принудительного завершения раунда (для админов)
addCommandHandler("forceroundend", function(player)
    if not isObjectInACLGroup("user."..getAccountName(getPlayerAccount(player)), aclGetGroup("Admin")) then
        outputChatBox("[CC]Only for admins", player, 255, 0, 0)
        return
    end
    outputChatBox("[CC]Admin forced round end", root, 255, 0, 0)
    onRoundEnded()
end)

-- Команда для проверки состояния
addCommandHandler("checkround", function(player)
    local stateNames = {
        ["DRAFT"] = "Драфт",
        ["WAITING"] = "Ожидание готовности",
        ["PLAYING"] = "Раунд в процессе",
        ["ENDED"] = "Раунд завершен"
    }

    local currentState = "DRAFT"
    if isMatchInProgress then
        if isWaitingForReady then
            currentState = "WAITING"
        else
            currentState = "PLAYING"
        end
    end

    outputChatBox("Текущее состояние системы:", player, 0, 255, 0)
    outputChatBox("Состояние: "..(stateNames[currentState] or currentState), player)
    outputChatBox("isFirstRound: "..tostring(isFirstRound), player)
    outputChatBox("isWaitingForReady: "..tostring(isWaitingForReady), player)
    outputChatBox("Готовность капитанов:", player)
    outputChatBox(captainNames.Captain1..": "..tostring(readyPlayers[captainElements.Captain1]), player)
    outputChatBox(captainNames.Captain2..": "..tostring(readyPlayers[captainElements.Captain2]), player)

    local currentMap = getElementData(root, "currentMap")
    if currentMap then
        outputChatBox("Текущая карта: "..currentMap.name.." ("..currentMap.index.."/"..currentMap.total..")", player)
    end
end)

addEvent("requestDraftBans", true)
addEventHandler("requestDraftBans", resourceRoot, function()
    if draftHistory then
        -- Отправляем только баны (первую часть истории)
        local bansPart = string.match(draftHistory, "(.-)════════════════════════════════════════\n║        Captain's Cup Picks        ║") or ""
        triggerClientEvent(client, "onDraftBansUpdate", resourceRoot, bansPart)
    end
end)

addEvent("requestDraftPicks", true)
addEventHandler("requestDraftPicks", resourceRoot, function()
    if draftHistory then
        -- Отправляем только пики (вторую часть истории)
        local picksPart = string.match(draftHistory, "════════════════════════════════════════\n║        Captain's Cup Picks        ║.*") or ""
        triggerClientEvent(client, "onDraftPicksUpdate", resourceRoot, picksPart)
    end
end)



-- Таймер для обновления времени (только серверный)
--setTimer(function()
--    if isProcessActive and activeTeam then
--        if activeTeam == 1 and isTimer1Active and team1Time > 0 then
--            team1Time = team1Time - 1
        --       elseif activeTeam == 2 and isTimer2Active and team2Time > 0 then
--            team2Time = team2Time - 1
 --       end
--       triggerClientEvent(root, "onUpdateTeamTimers", resourceRoot, team1Time, team2Time, activeTeam)
 --   end
--end, 1000, 0)
