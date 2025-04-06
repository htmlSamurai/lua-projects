local tabPanel, mainTab, settingsTab
local City, Classic, Motorbike, Circuit, Offroad, Airplane
local Team1, Team2, Captain1, Captain2, BanTeam1, BanTeam2, PickTeam1, PickTeam2
local Button
local BackgroundImage
local ExtraImage
local currentTurnData = {}
local maps = {}
local teams = {}
local captains = {}
local banList = {}
local pickList = {}
local isPanelVisible = true
local sound = nil
local isAdmin = false -- По умолчанию false

-- Таймеры команд
local team1Time = 100
local team2Time = 100
local activeTeam = nil
local team1TimerLabel, team2TimerLabel
local team1NameLabel, team2NameLabel
local start1Btn, start2Btn, stop1Btn, stop2Btn
local isTimer1Active = false
local isTimer2Active = false
local draftPicksHistory = ""
local draftHistoryLabel = nil
local draftHistoryText = ""
local fullPicksHistory = ""
-- Шрифты и размеры
local screenX, screenY = guiGetScreenSize()
local px, py = (screenX / 1920) / 1.2, (screenY / 1080) / 1.2
local bigFont = guiCreateFont("ru_Arial.ttf", 50)

-- Включение музыки
local function startMusic()
    if not sound then
        sound = playSound(":/background_music.mp3", true)
        if sound then
            setSoundVolume(sound, 0.5)
            outputChatBox("Background music enabled!", 0, 255, 0)
        else
            outputChatBox("Error loading music! Check 'background_music.mp3'.", 255, 0, 0)
        end
    end
end

-- Выключение музыки
local function stopMusic()
    if sound then
        stopSound(sound)
        sound = nil
        outputChatBox("Background music disabled!", 255, 255, 0)
    end
end

local function updateCursorVisibility()
    showCursor(isPanelVisible)  -- Курсор виден, если панель видима
end

-- Обновление отображения таймеров
local function updateTimersDisplay()
    if not isElement(team1TimerLabel) or not isElement(team2TimerLabel) then return end

    -- Форматируем время как MM:SS
    local function formatTime(seconds)
        local mins = math.floor(seconds / 60)
        local secs = seconds % 60
        return string.format("%02d:%02d", mins, secs)
    end

    guiSetText(team1TimerLabel, formatTime(team1Time))
    guiSetText(team2TimerLabel, formatTime(team2Time))

    -- Цвета для активного/неактивного таймера
    if activeTeam == 1 then
        guiLabelSetColor(team1TimerLabel, 255, 127, 80) -- Оранжевый (активный)
        guiLabelSetColor(team2TimerLabel, 150, 150, 150) -- Серый (неактивный)
    elseif activeTeam == 2 then
        guiLabelSetColor(team1TimerLabel, 150, 150, 150) -- Серый (неактивный)
        guiLabelSetColor(team2TimerLabel, 0, 139, 139) -- Бирюзовый (активный)
    else
        guiLabelSetColor(team1TimerLabel, 255, 255, 255) -- Белый (по умолчанию)
        guiLabelSetColor(team2TimerLabel, 255, 255, 255) -- Белый (по умолчанию)
    end
end

-- Получение выбранной карты
local function getSelectedMap()
    for _, grid in pairs({City, Classic, Motorbike, Circuit, Offroad, Airplane}) do
        local row = guiGridListGetSelectedItem(grid)
        if row ~= -1 then
            return guiGridListGetItemText(grid, row, 1), grid
        end
    end
    return nil, nil
end

-- Клиентская часть
addEvent("onDraftHistoryUpdate", true)
addEventHandler("onDraftHistoryUpdate", resourceRoot, function(historyText)
    -- Здесь обновляем интерфейс с историей драфта
    if guiInfo.history then
        guiSetText(guiInfo.history, historyText)
    end
    -- Сохраняем историю в переменную для последующего использования
    draftHistoryClient = historyText
end)

-- Обновление интерфейса
local function updateGUI()
    if not mainTab then return end

    -- Очистка и заполнение списков карт
    for category, grid in pairs({
        City = City,
        Classic = Classic,
        Motorbike = Motorbike,
        Circuit = Circuit,
        Offroad = Offroad,
        Airplane = Airplane
    }) do
        guiGridListClear(grid)
        if maps[category] then
            for _, mapName in ipairs(maps[category]) do
                guiGridListAddRow(grid, mapName)
            end
        end
    end

    -- Обновление команд и капитанов
    for grid, data in pairs({
        [Team1] = teams.Team1 or "unknown",
        [Team2] = teams.Team2 or "unknown",
        [Captain1] = captains.Captain1 or "unknown",
        [Captain2] = captains.Captain2 or "unknown"
    }) do
        guiGridListClear(grid)
        guiGridListAddRow(grid, data)
    end

    -- Обновление банов и пиков
    for grid, list in pairs({
        [BanTeam1] = banList.BanTeam1 or {},
        [BanTeam2] = banList.BanTeam2 or {},
        [PickTeam1] = pickList.PickTeam1 or {},
        [PickTeam2] = pickList.PickTeam2 or {}
    }) do
        guiGridListClear(grid)
        for _, item in ipairs(list) do
            guiGridListAddRow(grid, item)
        end
    end
end

-- Функция для обновления состояния кнопок
local function updateTimerButtons()
    guiSetEnabled(start1Btn, not isTimer1Active)
    guiSetEnabled(stop1Btn, isTimer1Active)
    guiSetEnabled(start2Btn, not isTimer2Active)
    guiSetEnabled(stop2Btn, isTimer2Active)
    
    -- Функция для запроса прав у сервера
    local function checkAdminStatus()
        triggerServerEvent("checkPlayerPermission", localPlayer)
    end

    -- Обработчик ответа от сервера
    addEvent("onPermissionCheckResult", true)
    addEventHandler("onPermissionCheckResult", resourceRoot, function(result)
        isAdmin = result
        updateTimerButtons() -- Обновляем кнопки после получения результата
    end)

    guiSetVisible(start1Btn, isAdmin)
    guiSetVisible(stop1Btn, isAdmin)
    guiSetVisible(start2Btn, isAdmin)
    guiSetVisible(stop2Btn, isAdmin)
end

-- Функция для подсветки категорий
local function updateCategoryHighlights()
    -- Получаем текущего капитана (если это его ход)
    local turnData = currentTurnData or {}
    local captainKey = (turnData.captain == localPlayer) and
            ((turnData.captain == captains.Captain1) and "Captain1" or "Captain2") or nil

    if not captainKey or turnData.action ~= "pick" then return end

    -- Подсвечиваем категории, из которых уже выбрано 2 карты
    for category, grid in pairs({
        City = City,
        Classic = Classic,
        Motorbike = Motorbike,
        Circuit = Circuit,
        Offroad = Offroad,
        Airplane = Airplane
    }) do
        local count = currentTurnData.categoryStats and currentTurnData.categoryStats[captainKey] and currentTurnData.categoryStats[captainKey][category] or 0
        if count >= 2 then
            guiSetProperty(grid, "NormalTextColour", "FFFF0000") -- Красный цвет
        else
            guiSetProperty(grid, "NormalTextColour", "FFFFFFFF") -- Белый цвет
        end
    end
end

-- Создание GUI
addEventHandler("onClientResourceStart", resourceRoot, function()
    -- Основное окно
    tableGUI = guiCreateWindow((screenX - 1920 * px) / 2, (screenY - 1080 * py) / 2, 1920 * px, 1080 * py, "Captain's Mode | Version 5.0", false)
    guiWindowSetSizable(tableGUI, false)

    -- Панель вкладок
    tabPanel = guiCreateTabPanel(10 * px, 30 * py, 1900 * px, 1040 * py, false, tableGUI)
    mainTab = guiCreateTab("Main", tabPanel)
    settingsTab = guiCreateTab("Settings", tabPanel)
    InfoTab = guiCreateTab("Information", tabPanel)
    HistoryTab = guiCreateTab("Match Maps", tabPanel)

    -- Основная вкладка (Main)
    BackgroundImage = guiCreateStaticImage(682 * px, 564 * py, 590 * px, 455 * py, ":/background.png", false, mainTab)

    -- Создаем элементы GUI для категорий карт
    City = guiCreateGridList(9 * px, 24 * py, 330 * px, 327 * py, false, mainTab)
    guiGridListAddColumn(City, "City Maps", 0.9)

    Classic = guiCreateGridList(10 * px, 360 * py, 330 * px, 327 * py, false, mainTab)
    guiGridListAddColumn(Classic, "Classic Maps", 0.9)

    Motorbike = guiCreateGridList(10 * px, 695 * py, 330 * px, 327 * py, false, mainTab)
    guiGridListAddColumn(Motorbike, "Moto Maps", 0.9)

    Circuit = guiCreateGridList(349 * px, 24 * py, 330 * px, 327 * py, false, mainTab)
    guiGridListAddColumn(Circuit, "Circuit Maps", 0.9)

    Offroad = guiCreateGridList(349 * px, 360 * py, 330 * px, 327 * py, false, mainTab)
    guiGridListAddColumn(Offroad, "Offroad Maps", 0.9)

    Airplane = guiCreateGridList(350 * px, 695 * py, 330 * px, 327 * py, false, mainTab)
    guiGridListAddColumn(Airplane, "Plane Maps", 0.9)

    -- Команды и капитаны
    Team1 = guiCreateGridList(1275 * px, 25 * py, 315 * px, 182 * py, false, mainTab)
    guiGridListAddColumn(Team1, "Team 1", 0.9)
    Team2 = guiCreateGridList(1595 * px, 25 * py, 315 * px, 182 * py, false, mainTab)
    guiGridListAddColumn(Team2, "Team 2", 0.9)
    Captain1 = guiCreateGridList(1275 * px, 210 * py, 315 * px, 182 * py, false, mainTab)
    guiGridListAddColumn(Captain1, "Captain 1", 0.9)
    Captain2 = guiCreateGridList(1598 * px, 210 * py, 312 * px, 182 * py, false, mainTab)
    guiGridListAddColumn(Captain2, "Captain 2", 0.9)
    BanTeam1 = guiCreateGridList(1275 * px, 400 * py, 314 * px, 295 * py, false, mainTab)
    guiGridListAddColumn(BanTeam1, "Team 1 Bans", 0.9)
    BanTeam2 = guiCreateGridList(1598 * px, 400 * py, 314 * px, 295 * py, false, mainTab)
    guiGridListAddColumn(BanTeam2, "Team 2 Bans", 0.9)
    PickTeam1 = guiCreateGridList(1275 * px, 700 * py, 314 * px, 322 * py, false, mainTab)
    guiGridListAddColumn(PickTeam1, "Team 1 Picks", 0.9)
    PickTeam2 = guiCreateGridList(1596 * px, 700 * py, 314 * px, 322 * py, false, mainTab)
    guiGridListAddColumn(PickTeam2, "Team 2 Picks", 0.9)

    -- Кнопка Ban/Pick
    Button = guiCreateButton(682 * px, 442 * py, 590 * px, 118 * py, "BAN/PICK", false, mainTab)

    -- Таймеры команд
    team1NameLabel = guiCreateLabel(677 * px, 50 * py, 295 * px, 400 * py, "TEAM 1", false, mainTab)
    team2NameLabel = guiCreateLabel(977 * px, 50 * py, 295 * px, 400 * py, "TEAM 2", false, mainTab)
    guiSetFont(team1NameLabel, bigFont)
    guiSetFont(team2NameLabel, bigFont)
    guiLabelSetHorizontalAlign(team1NameLabel, "center")
    guiLabelSetHorizontalAlign(team2NameLabel, "center")
    guiLabelSetColor(team1NameLabel, 255, 127, 80) -- Оранжевый
    guiLabelSetColor(team2NameLabel, 0, 139, 139) -- Бирюзовый

    team1TimerLabel = guiCreateLabel(682 * px, 150 * py, 295 * px, 80 * py, "07:30", false, mainTab)
    team2TimerLabel = guiCreateLabel(977 * px, 150 * py, 295 * px, 80 * py, "07:30", false, mainTab)
    guiSetFont(team1TimerLabel, bigFont)
    guiSetFont(team2TimerLabel, bigFont)
    guiLabelSetHorizontalAlign(team1TimerLabel, "center")
    guiLabelSetHorizontalAlign(team2TimerLabel, "center")

    -- Кнопки управления таймерами (под каждым таймером)
    start1Btn = guiCreateButton(770 * px, 280 * py, 145 * px, 40 * py, "START 1", false, mainTab)
    stop1Btn = guiCreateButton(770 * px, 340 * py, 145 * px, 40 * py, "STOP 1", false, mainTab)
    start2Btn = guiCreateButton(1045 * px, 280 * py, 145 * px, 40 * py, "START 2", false, mainTab)
    stop2Btn = guiCreateButton(1045 * px, 340 * py, 145 * px, 40 * py, "STOP 2", false, mainTab)

    -- Дополнительное изображение
    ExtraImage = guiCreateStaticImage(682 * px, 260 * py, 590 * px, 178 * py, ":/extra_image.png", false, mainTab)
    if not ExtraImage then
        outputChatBox("Ошибка загрузки изображения!", 255, 0, 0)
    end

    -- Вкладка настроек (Settings)
    local settingsLabel = guiCreateLabel(20 * px, 20 * py, 300 * px, 30 * py, "Captain's Cup Settings", false, settingsTab)
    guiLabelSetHorizontalAlign(settingsLabel, "center")
    guiSetFont(settingsLabel, "default-bold-small")

    -- Поля для ввода команд
    local team1Label = guiCreateLabel(20 * px, 60 * py, 150 * px, 20 * py, "Team 1 name:", false, settingsTab)
    local team1Edit = guiCreateEdit(180 * px, 60 * py, 200 * px, 25 * py, "", false, settingsTab)

    local team2Label = guiCreateLabel(20 * px, 100 * py, 150 * px, 20 * py, "Team 2 name:", false, settingsTab)
    local team2Edit = guiCreateEdit(180 * px, 100 * py, 200 * px, 25 * py, "", false, settingsTab)

    -- Кнопка установки названий команд
    local setTeamsButton = guiCreateButton(20 * px, 140 * py, 360 * px, 30 * py, "Set Team Names", false, settingsTab)

    -- Кнопка запуска Captain Cup
    local startCupButton = guiCreateButton(20 * px, 320 * py, 360 * px, 40 * py, "START CC", false, settingsTab)
    guiSetProperty(startCupButton, "NormalTextColour", "FF00FF00")

    -- Панель игроков (All Players)
    local playersLabel = guiCreateLabel(400 * px, 20 * py, 500 * px, 20 * py, "All Players", false, settingsTab)
    guiSetFont(playersLabel, "default-bold-small")

    -- Увеличиваем размер панели игроков
    local playersGrid = guiCreateGridList(400 * px, 50 * py, 500 * px, 350 * py, false, settingsTab)
    guiGridListAddColumn(playersGrid, "Players", 0.9) -- Только один столбец

    -- Кнопки для назначения капитанов
    local captain1Btn = guiCreateButton(400 * px, 410 * py, 240 * px, 40 * py, "Set team 1 Captain", false, settingsTab)
    local captain2Btn = guiCreateButton(660 * px, 410 * py, 240 * px, 40 * py, "Set team 2 Captain", false, settingsTab)
    local refreshBtn = guiCreateButton(400 * px, 460 * py, 500 * px, 30 * py, "Refresh Players", false, settingsTab)

    local infoText = [[
Welcome to Captain's Mode.
This script was created for the Captain’s Cup 2015 tournament by LSR Team.

User Guide
1. This script works with a modified version of the race_league script by Vally.
2. Server administrators must add the main resource (ccmode) to the acl.xml file.
3. Server administrators must add maps to the maps.json list.
3.1. Example of adding a map:

json code
{"name": "Dra Dragon Dakar 5", "resource": "race-DrADragonDakar5"}

4. Disable all resources that interfere with the script’s logic or functionality. Examples of such scripts: votemanager, race_team, race_league.
5. After launching the resource, perform the following steps:
5.1. Open the race_league team creation panel (F2, create teams, click Start CW, then close the panel).
5.2. Open the ccmode panel (press "J").
5.3. In the Setting tab, set the team names.
5.4. In the Setting tab, assign two captains.
5.5. If the team captains are ready to proceed to the drafting stage, click Start Captain’s Match.

Draft Stage Process
6.1. During the draft stage, captains ban and pick maps for the match.
6.2. A maximum of 2 maps can be selected from one category. If a captain tries to pick a third map, they will receive a private notification that the selection limit for that category has been reached.
6.3. If a captain fails to pick or ban a map in time, the script will automatically select or ban random maps once the timer expires.
6.4. On the main ccmode panel, the administrator has access to the following buttons: START 1, START 2, STOP 1, STOP 2. These buttons are used to pause or resume team timers.

6.4.1. If any captain disconnects (Exit / Timeout), the timer must be paused using STOP. After the player returns, they must be reassigned as captain.

6.4.2. The team captain can be changed in the Settings tab, allowing another player to pick/ban maps.

6.4.3. Important! The captain’s nickname must not contain color codes (e.g., #ffff00nickname).
6.5. After the draft stage, all selected maps will be displayed:

On the main CC Match panel.

In the chat as a notification.
6.6. To start the next map, captains must type /rdy.

6.6.1. The system will automatically launch the next map. The administrator doesn’t need to do anything—they can relax, smoke bamboo, fap, or whatever else they do.....
6.6.2. If the script fails to find map resource for the next map, check resource name in maps.json.
6.7. After each round, the next map’s details will be displayed in the chat.

After the match ends, the ccmode resource must be disabled.

Developers:
Current version: GARIK08, THIRTYTWO, Mateoryt.

Previous version: lukum, GARIK08.
]]
--500, 200
    local infoLabel = guiCreateLabel(20 * px, 30 * py, 1000 * px, 1500 * py, infoText, false, InfoTab)
    guiLabelSetHorizontalAlign(infoLabel, "left", true) -- Разрешаем перенос слов

    -- Создаем элемент истории
    -- В обработчике создания GUI (onClientResourceStart):
    draftHistoryLabel = guiCreateLabel(20, 30, 500, 400,
            "Здесь будет отображаться история выбранных карт после завершения драфта",
            false, HistoryTab)
    guiLabelSetHorizontalAlign(draftHistoryLabel, "left", true)
    guiSetFont(draftHistoryLabel, "default-bold-small")
    guiLabelSetColor(draftHistoryLabel, 255, 255, 255)

    addEventHandler("onClientResourceStart", resourceRoot, function()
        setTimer(function()
            triggerServerEvent("requestDraftPicks", resourceRoot)
        end, 1000, 1)
    end)

    -- Если есть сохраненная история, показываем ее
    if #draftHistoryText > 0 then
        guiSetText(draftHistoryLabel, draftHistoryText)
    end

    triggerServerEvent("requestInitialData", resourceRoot)

    -- Функция обновления списка игроков
    local function updatePlayersList()
        guiGridListClear(playersGrid)
        for _, player in ipairs(getElementsByType("player")) do
            local row = guiGridListAddRow(playersGrid)
            guiGridListSetItemText(playersGrid, row, 1, getPlayerName(player, true), false, false)
        end
    end

    -- Обработчик кнопки обновления списка игроков
    addEventHandler("onClientGUIClick", refreshBtn, function()
        updatePlayersList()
        outputChatBox("Players list updated!", 0, 255, 0)
    end, false)

    -- Обработчики кнопок назначения капитанов
    addEventHandler("onClientGUIClick", captain1Btn, function()
        local row = guiGridListGetSelectedItem(playersGrid)
        if row ~= -1 then
            local playerName = guiGridListGetItemText(playersGrid, row, 1)
            local player = getPlayerFromName(playerName:gsub("#%x%x%x%x%x%x", ""))
            if player then
                triggerServerEvent("onSetCaptain1", resourceRoot, player)
                outputChatBox("Team 1 captain set: "..playerName, 0, 255, 0)
            else
                outputChatBox("Player not found! Press refresh list", 255, 0, 0)
            end
        else
            outputChatBox("Select a player from the list!", 255, 0, 0)
        end
    end, false)

    addEventHandler("onClientGUIClick", captain2Btn, function()
        local row = guiGridListGetSelectedItem(playersGrid)
        if row ~= -1 then
            local playerName = guiGridListGetItemText(playersGrid, row, 1)
            local player = getPlayerFromName(playerName:gsub("#%x%x%x%x%x%x", ""))
            if player then
                triggerServerEvent("onSetCaptain2", resourceRoot, player)
                outputChatBox("Team 2 captain set: "..playerName, 0, 255, 0)
            else
                outputChatBox("Player not found! Press refresh list", 255, 0, 0)
            end
        else
            outputChatBox("Select a player from the list!", 255, 0, 0)
        end
    end, false)

    -- Обработчик кнопки установки названий команд
    addEventHandler("onClientGUIClick", setTeamsButton, function(button, state)
        if button == "left" and state == "up" then
            local team1Name = guiGetText(team1Edit)
            local team2Name = guiGetText(team2Edit)

            if team1Name == "" or team2Name == "" then
                outputChatBox("Enter names for both teams!", 255, 0, 0)
                return
            end

            triggerServerEvent("onSetTeams", resourceRoot, team1Name, team2Name)
            outputChatBox("Team names set: "..team1Name.." и "..team2Name, 0, 255, 0)
        end
    end, false)

    -- Обработчик кнопки запуска Captain Cup
    addEventHandler("onClientGUIClick", startCupButton, function(button, state)
        if button == "left" and state == "up" then
            if teams.Team1 == "" or teams.Team2 == "" then
                outputChatBox("Enter names for both teams!", 255, 0, 0)
                return
            end
            if captains.Captain1 == "" or captains.Captain2 == "" then
                outputChatBox("Enter names for both teams!!", 255, 0, 0)
                return
            end

            triggerServerEvent("startCaptainCup", resourceRoot)
            outputChatBox("Starting Captain Cup...", 0, 255, 0)
        end
    end, false)

    -- Обработчики кнопок управления таймерами
    addEventHandler("onClientGUIClick", start1Btn, function()
        triggerServerEvent("onTimerControl", localPlayer, 1, "start")
    end, false)

    addEventHandler("onClientGUIClick", stop1Btn, function()
        triggerServerEvent("onTimerControl", localPlayer, 1, "stop")
    end, false)

    addEventHandler("onClientGUIClick", start2Btn, function()
        triggerServerEvent("onTimerControl", localPlayer, 2, "start")
    end, false)

    addEventHandler("onClientGUIClick", stop2Btn, function()
        triggerServerEvent("onTimerControl", localPlayer, 2, "stop")
    end, false)

    -- Добавим в конец onClientResourceStart
    local currentMapLabel = guiCreateLabel(700 * px, 380 * py, 500 * px, 40 * py, "Текущая карта: -", false, mainTab)
    guiSetFont(currentMapLabel, "default-bold-small")
    guiLabelSetHorizontalAlign(currentMapLabel, "center")

    -- Обработчик обновления текущей карты
    addEventHandler("onClientElementDataChange", root, function(dataName)
        if dataName == "currentMap" then
            local mapData = getElementData(root, "currentMap")
            if mapData then
                guiSetText(currentMapLabel, "Map now: "..mapData.name.." ("..mapData.index.."/"..mapData.total..")")
            else
                guiSetText(currentMapLabel, "Map now: -")
            end
        end
    end)

    -- Обновляем список игроков при старте
    updatePlayersList()

    -- Инициализация курсора
    guiSetVisible(tableGUI, isPanelVisible)
    showCursor(isPanelVisible)

    -- Функция для проверки количества выбранных карт
    local function getSelectedMapsCount()
        local count = 0
        for _, grid in pairs({City, Classic, Motorbike, Circuit, Offroad, Airplane}) do
            if guiGridListGetSelectedItem(grid) ~= -1 then
                count = count + 1
            end
        end
        return count
    end

    -- Функция для сброса всех выделений
    local function resetAllSelections()
        for _, grid in pairs({City, Classic, Motorbike, Circuit, Offroad, Airplane}) do
            guiGridListSetSelectedItem(grid, -1, 1)
        end
    end

    -- Обновленный обработчик кнопки Ban/Pick
    addEventHandler("onClientGUIClick", Button, function(button, state)
        if button == "left" and state == "up" then
            if not currentTurnData.captain then
                outputChatBox("Ban/pick process not started!", 255, 0, 0)
                return
            end

            if localPlayer ~= currentTurnData.captain then
                local captainName = currentTurnData.captain and getPlayerName(currentTurnData.captain, true) or "Неизвестно"
                outputChatBox("Not your turn! Current captain: " .. captainName, 255, 0, 0)
                return
            end

            -- Проверяем количество выбранных карт
            local selectedCount = getSelectedMapsCount()
            if selectedCount == 0 then
                outputChatBox("Select a map from the list!", 255, 0, 0)
                return
            elseif selectedCount > 1 then
                outputChatBox("Please select ONLY ONE map!", 255, 0, 0)
                resetAllSelections()  -- Сбрасываем все выделения
                return
            end

            -- Получаем выбранную карту (гарантировано одна)
            local selectedMap, gridList
            for _, grid in pairs({City, Classic, Motorbike, Circuit, Offroad, Airplane}) do
                local row = guiGridListGetSelectedItem(grid)
                if row ~= -1 then
                    selectedMap = guiGridListGetItemText(grid, row, 1)
                    gridList = grid
                    break
                end
            end

            -- Проверяем, что карта еще не была выбрана/забанена
            local isAlreadyUsed = false
            for _, ban in ipairs(banList.BanTeam1 or {}) do if ban == selectedMap then isAlreadyUsed = true break end end
            for _, ban in ipairs(banList.BanTeam2 or {}) do if ban == selectedMap then isAlreadyUsed = true break end end
            for _, pick in ipairs(pickList.PickTeam1 or {}) do if pick == selectedMap then isAlreadyUsed = true break end end
            for _, pick in ipairs(pickList.PickTeam2 or {}) do if pick == selectedMap then isAlreadyUsed = true break end end

            if isAlreadyUsed then
                outputChatBox("This map is already banned/picked!", 255, 0, 0)
                resetAllSelections()
                return
            end

            if not currentTurnData.action then
                outputChatBox("No action to perform!", 255, 0, 0)
                return
            end

            outputChatBox("Selected: " .. selectedMap .. " for " .. currentTurnData.action, 0, 255, 0)
            triggerServerEvent("onBanPick", localPlayer, currentTurnData.action, selectedMap)

            -- Удаляем карту из списка, если это бан
            if currentTurnData.action == "ban" then
                local row = guiGridListGetSelectedItem(gridList)
                if row ~= -1 then
                    guiGridListRemoveRow(gridList, row)
                end
            end

            resetAllSelections()  -- Сбрасываем выделение после успешного выбора
        end
    end, false)

    -- Обработчик клавиши H
    bindKey("h", "down", function()
        isPanelVisible = not isPanelVisible
        guiSetVisible(tableGUI, isPanelVisible)
        showCursor(isPanelVisible)

        if isPanelVisible then
            startMusic()
        else
            stopMusic()
        end
        outputChatBox(isPanelVisible and "Captain Cup panel opened!" or "Captain Cup panel hidden!", 255, 255, 0)
    end)

    -- Проверяем права при старте
    setTimer(function()
        updateTimerButtons()
    end, 1000, 1)

    startMusic()
end)

-- Обработчик получения данных от сервера
addEvent("onInitialDataReceived", true)
addEventHandler("onInitialDataReceived", resourceRoot, function(initialMaps)
    maps = initialMaps
    updateGUI()
end)


triggerServerEvent("requestInitialData", resourceRoot)

-- И добавить обработчик для повторного запроса данных при необходимости
addEventHandler("onClientResourceStart", resourceRoot, function()
    -- Ждем немного перед запросом данных
    setTimer(function()
        triggerServerEvent("requestInitialData", resourceRoot)

        -- Если у нас уже есть данные о текущей карте, обновляем label
        local currentMap = getElementData(root, "currentMap")
        if currentMap then
            guiSetText(currentMapLabel, "Map now: "..currentMap.name.." ("..currentMap.index.."/"..currentMap.total..")")
        end
    end, 1000, 1)
end)

-- Синхронизация данных с сервером
addEvent("onSyncData", true)
addEventHandler("onSyncData", resourceRoot, function(syncedTeams, syncedCaptains, syncedMaps, syncedBanList, syncedPickList, turnData, matchData)
    teams = syncedTeams or {}
    captains = syncedCaptains or {}
    banList = syncedBanList or {BanTeam1 = {}, BanTeam2 = {}}
    pickList = syncedPickList or {PickTeam1 = {}, PickTeam2 = {}}
    currentTurnData = turnData or {}

    -- Обновляем списки карт на клиенте
    maps = {}
    for category, mapNames in pairs(syncedMaps or {}) do
        maps[category] = mapNames
    end

    -- Обновляем GUI
    updateGUI()

    -- Обновляем названия команд над таймерами
    if isElement(team1NameLabel) then guiSetText(team1NameLabel, teams.Team1 or "TEAM 1") end
    if isElement(team2NameLabel) then guiSetText(team2NameLabel, teams.Team2 or "TEAM 2") end

    -- Обновляем подсветку категорий
    updateCategoryHighlights()
end)

local bansHistoryText = ""
local picksHistoryText = ""

addEvent("onDraftBansUpdate", true)
addEventHandler("onDraftBansUpdate", resourceRoot, function(text)
    bansHistoryText = text or ""
    updateHistoryLabel()
end)

-- Обработчик получения истории пиков
addEvent("onDraftPicksUpdate", true)
addEventHandler("onDraftPicksUpdate", resourceRoot, function(picksText)
    draftPicksHistory = picksText or ""
    updateHistoryLabel()
end)

-- Функция обновления текста в истории
function updateHistoryLabel()
    if isElement(draftHistoryLabel) then
        guiSetText(draftHistoryLabel, draftPicksHistory)
    end
end

-- При подключении игрока запрашиваем обе части истории
addEventHandler("onClientResourceStart", resourceRoot, function()
    -- Ждем немного перед запросом данных
    setTimer(function()
        triggerServerEvent("requestFullPicksHistory", resourceRoot)
    end, 1500, 1)
end)

-- Обновление таймеров команд
addEvent("onUpdateTeamTimers", true)
addEventHandler("onUpdateTeamTimers", resourceRoot, function(team1, team2, active)
    team1Time = team1
    team2Time = team2
    activeTeam = active
    updateTimersDisplay()
end)

-- Обновление состояния таймеров
addEvent("onUpdateTimerState", true)
addEventHandler("onUpdateTimerState", resourceRoot, function(timer1, timer2)
    isTimer1Active = timer1
    isTimer2Active = timer2
    updateTimerButtons()
end)

-- Таймер для обновления времени
setTimer(function()
    if currentTurnData and currentTurnData.captain then
        if activeTeam == 1 and isTimer1Active and team1Time > 0 then
            team1Time = team1Time - 1
            updateTimersDisplay()
        elseif activeTeam == 2 and isTimer2Active and team2Time > 0 then
            team2Time = team2Time - 1
            updateTimersDisplay()
        end
    end
end, 1000, 0)
