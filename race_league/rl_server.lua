--init
local playerData = {}
local teams = {}
local rounds = 10
local c_round = 0
local f_round = false
local round_started = false
local round_ended = true
local isWarEnded  = false
local isRoundActive = false
local roundScores = {team1 = 0, team2 = 0}

-------------------
-- Useful functions
-------------------

function math.round(number, decimals, method)
	decimals = decimals or 0
	local factor = 10 ^ decimals
	if (method == "ceil" or method == "floor") then return math[method](number * factor) / factor
	else return tonumber(("%."..decimals.."f"):format(number)) end
end

function removeHex (text, digits)
	assert (type (text) == "string", "Bad argument 1 @ removeHex [String expected, got "..tostring(text).."]")
	assert (digits == nil or (type (digits) == "number" and digits > 0), "Bad argument 2 @ removeHex [Number greater than zero expected, got "..tostring (digits).."]")
	return string.gsub (text, "#"..(digits and string.rep("%x", digits) or "%x+"), "")
end

-----------------
-- Call functions
-----------------
function serverCall(funcname, ...)
	local arg = { ... }
	if (arg[1]) then
		for key, value in next, arg do arg[key] = tonumber(value) or value end
	end
	loadstring("return "..funcname)()(unpack(arg))
end

addEvent("onClientCallsServerFunction", true)
addEventHandler("onClientCallsServerFunction", resourceRoot , serverCall)

function clientCall(client, funcname, ...)
	local arg = { ... }
	if (arg[1]) then
		for key, value in next, arg do
			if (type(value) == "number") then arg[key] = tostring(value) end
		end
	end
	triggerClientEvent(client, "onServerCallsClientFunction", resourceRoot, funcname, unpack(arg or {}))
end

--------------
function preStart(player, command, t1_name, t2_name)
	if isAdmin(player) then
		destroyTeams()
		if t1_name ~= nil and t2_name ~= nil then
			teams[1] = createTeam(t1_name, 255, 0, 0)
			teams[2] = createTeam(t2_name, 0, 0, 255)
		else
			teams[1] = createTeam('Team 1', 255, 0, 0)
			teams[2] = createTeam('Team 2', 0, 0, 255)
			outputInfo('no team names')
			outputInfo('using default team names')
		end
		teams[3] = createTeam('Spectators', 255, 255, 255)
		for i,player in ipairs(getElementsByType('player')) do
			setPlayerTeam(player, teams[3])
			setElementData(player, 'Score', 0)
			setElementData(player, 'Pts per map', 0)
			setElementData(player, 'Maps played', 0)
			setElementData(player, 'Maps won', 0)
			setElementData(player, 'roundScore', 0)
			-- Initialize position stats
			for pos = 1, 10 do
				setElementData(player, 'race_pos_'..pos, 0)
			end
			setElementData(player, 'race_dnf', 0)
		end
		setElementData(teams[1], 'Score', 0)
		setElementData(teams[2], 'Score', 0)
		setElementData(teams[1], 'Pts per map', "")
		setElementData(teams[2], 'Pts per map', "")
		setElementData(teams[3], 'Pts per map', "")
		setElementData(teams[1], 'Maps played', "")
		setElementData(teams[2], 'Maps played', "")
		setElementData(teams[3], 'Maps played', "")
		setElementData(teams[1], 'Maps won', "")
		setElementData(teams[2], 'Maps won', "")
		setElementData(teams[3], 'Maps won', "")
		round_ended = true
		c_round = 0
		call(getResourceFromName("scoreboard"), "scoreboardAddColumn", "Score")
		call(getResourceFromName("scoreboard"), "scoreboardAddColumn", "Pts per map")
		call(getResourceFromName("scoreboard"), "scoreboardAddColumn", "Maps played")
		call(getResourceFromName("scoreboard"), "scoreboardAddColumn", "Maps won")
		for i, player in ipairs(getElementsByType('player')) do
			clientCall(player, 'updateTeamData', teams[1], teams[2], teams[3])
			clientCall(player, 'updateRoundData', c_round, rounds, f_round, round_ended)
			clientCall(player, 'createGUI', getTeamName(teams[1]), getTeamName(teams[2]))
		end
	else
		outputChatBox("***You aren't admin", player, 255, 100, 100, true)
	end
end

function destroyTeams(player)
	if isAdmin(player) then
		for i,team in ipairs(teams) do
			if isElement(team) then
				destroyElement(team)
			end
		end
		teams = {} -- Очищаем таблицу команд

		-- Сбрасываем счетчики раундов
		c_round = 0
		rounds = 10
		f_round = false
		round_ended = true

		for i,player in ipairs(getElementsByType('player')) do
			clientCall(player, 'updateTeamData', nil, nil, nil)
			clientCall(player, 'updateRoundData', c_round, rounds, f_round, round_ended)
		end
	else
		outputChatBox("***You aren't admin", player, 255, 100, 100, true)
	end
end

function funRound(player)
	if isAdmin(player) then
		f_round = true
		for i,player in ipairs(getElementsByType('player')) do
			clientCall(player, 'updateRoundData', c_round, rounds, f_round, round_ended)
		end
		outputInfo('Fun Round')
	else
		outputChatBox("***You aren't admin", player, 255, 100, 100, true)
	end
end

function readyFunc(player)
	if captain1 and captain2 then
		if captain1 == removeHex(getPlayerName(player),6) or captain2 == removeHex(getPlayerName(player),6) then
			outputChatBox(removeHex(getPlayerName(player),6).." says his team is ready!", root,  0, 255, 0, true)
		end
	end
end

function stopFunc(player)
	if captain1 and captain2 then
		if captain1 == removeHex(getPlayerName(player),6) or captain2 == removeHex(getPlayerName(player),6) then
			outputChatBox(removeHex(getPlayerName(player),6).." requests a FUN ROUND!", root, 255, 0, 0, true)
		end
	end
end

function hahaFunc(player)
	if captain1 and captain2 then
		if captain1 == removeHex(getPlayerName(player),6) or captain2 == removeHex(getPlayerName(player),6) then
			outputChatBox(removeHex(getPlayerName(player),6).." laughs at all the n00bs in enemy team!", root, 255, 215, 0, true)
		end
	end
end

function ggFunc(player)
	if captain1 and captain2 then
		if captain1 == removeHex(getPlayerName(player),6) or captain2 == removeHex(getPlayerName(player),6) then
			outputChatBox(removeHex(getPlayerName(player),6).." thanks enemy team for a great game!", root, 127, 255, 212, true)
		end
	end
end

function calculateRoundScores()
	roundScores.team1 = 0
	roundScores.team2 = 0

	-- Собираем очки всех игроков за текущий раунд
	for _, player in ipairs(getElementsByType("player")) do
		local team = getPlayerTeam(player)
		if team == teams[1] or team == teams[2] then
			local score = getElementData(player, "roundScore") or 0
			if team == teams[1] then
				roundScores.team1 = roundScores.team1 + score
			else
				roundScores.team2 = roundScores.team2 + score
			end
			-- Сбрасываем счет раунда для игрока
			setElementData(player, "roundScore", 0)
		end
	end

	return roundScores.team1, roundScores.team2
end

--------- { COMMANDS } ----------
addCommandHandler('newtr', preStart)
addCommandHandler('endtr', destroyTeams)
addCommandHandler('fun', funRound)
addCommandHandler('r', readyFunc)
addCommandHandler('f', stopFunc)
addCommandHandler('haha', hahaFunc)
addCommandHandler('gg', ggFunc)

function outputInfo(info)
	for i, player in ipairs(getElementsByType('player')) do
		outputChatBox('[Race League]: ' ..info, player, 155, 255, 255, true)
	end
end

function startRound()
	f_round = false
	if c_round < rounds  then
		if round_ended then
			c_round = c_round + 1
			-- Сбрасываем счет раунда для всех игроков
			for _, player in ipairs(getElementsByType("player")) do
				setElementData(player, "roundScore", 0)
			end
		end
		round_started = true
		isRoundActive = true
		round_ended = false
	end
	for i,player in ipairs(getElementsByType('player')) do
		clientCall(player, 'updateRoundData', c_round, rounds, f_round, round_ended)
	end
	if isWarEnded then
		destroyTeams(false)
		isWarEnded = false
	end
end

function isRoundEnded()
	local c_ActivePlayers = 0
	for i,player in ipairs(getPlayersInTeam(teams[1])) do
		if not getElementData(player, 'race.finished') then
			c_ActivePlayers = c_ActivePlayers + 1
		end
	end
	for i,player in ipairs(getPlayersInTeam(teams[2])) do
		if not getElementData(player, 'race.finished') then
			c_ActivePlayers = c_ActivePlayers + 1
		end
	end
	if c_ActivePlayers == 0 then return true else return false end
end

function playerFinished(rank)
	if isElement(teams[1]) and isElement(teams[2]) and isElement(teams[3]) then
		if getPlayerTeam(source) ~= teams[3] and not f_round and c_round > 0 then
			local p_score = 0
			local mw = 0
			if rank == 1 then
				p_score = 15
				mw = 1
			elseif rank == 2 then
				p_score = 13
			elseif rank == 3 then
				p_score = 11
			elseif rank == 4 then
				p_score = 9
			elseif rank == 5 then
				p_score = 7
			elseif rank == 6 then
				p_score = 5
			elseif rank == 7 then
				p_score = 4
			elseif rank == 8 then
				p_score = 3
			elseif rank == 9 then
				p_score = 2
			elseif rank == 10 then
				p_score = 1
			end

			-- Записываем очки за раунд
			local currentRoundScore = getElementData(source, "roundScore") or 0
			setElementData(source, "roundScore", currentRoundScore + p_score)

			-- Update position stats
			if rank >= 1 and rank <= 10 then
				local posData = 'race_pos_'..rank
				local current = getElementData(source, posData) or 0
				setElementData(source, posData, current + 1)
			end

			local old_score = getElementData(getPlayerTeam(source), 'Score')
			local new_score = old_score + p_score
			local old_p_score = getElementData(source, 'Score')
			local new_p_score = old_p_score + p_score
			local old_mw = getElementData(source, 'Maps won')
			local new_mw = old_mw + mw

			setElementData(source, 'Score', new_p_score)
			setElementData(getPlayerTeam(source), 'Score', new_score)
			setElementData(source, 'Maps won', new_mw)
			outputInfo(getPlayerName(source).. ' got ' ..p_score.. ' points')
		end
		if isRoundEnded() then
			endRound()
		end
	end
end

function endRound()
	if isElement(teams[1]) and isElement(teams[2]) and not f_round then
		if c_round > 0 then
			if not round_ended then
				-- Подсчитываем очки за раунд
				local t1Score, t2Score = calculateRoundScores()

				-- Выводим результат раунда
				if t1Score > t2Score then
					outputInfo(getTeamName(teams[1]).. " won round #"..c_round.." with score "..t1Score.."-"..t2Score)
				elseif t1Score < t2Score then
					outputInfo(getTeamName(teams[2]).. " won round #"..c_round.." with score "..t2Score.."-"..t1Score)
				else
					outputInfo("Round #"..c_round.." ended in a draw with score "..t1Score.."-"..t2Score)
				end

				round_ended = true
				isRoundActive = false

				-- Обновляем всех клиентов
				for i, player in ipairs(getElementsByType('player')) do
					clientCall(player, 'updateRoundData', c_round, rounds, f_round, round_ended)
				end

				outputInfo('Round has been ended')
				triggerEvent("onRaceRoundFinished", root)

				-- Проверяем, был ли это последний раунд
				if c_round == rounds then
					-- Добавляем небольшую задержку перед выводом итогов матча
					setTimer(function()
						endThisWar()
					end, 1000, 1)
				end
			end
		end
	end
end

function endThisWar()
	-- Защита от повторного выполнения
	if isWarEnded then return end
	isWarEnded = true

	local t1score = tonumber(getElementData(teams[1], 'Score'))
	local t2score = tonumber(getElementData(teams[2], 'Score'))

	-- Определяем победителя
	local winnerMessage
	if t1score > t2score then
		winnerMessage = getTeamName(teams[1]).. ' won the match against ' ..getTeamName(teams[2]).. ' with score ' ..t1score.. ' : ' ..t2score
	elseif t1score < t2score then
		winnerMessage = getTeamName(teams[2]).. ' won the match against ' ..getTeamName(teams[1]).. ' with score ' ..t2score.. ' : ' ..t1score
	else
		winnerMessage = 'Match ended in draw between '..getTeamName(teams[1]).. ' and ' ..getTeamName(teams[2]).. ' with score ' ..t1score.. ' : ' ..t2score
	end

	-- Выводим сообщение один раз
	outputInfo(winnerMessage)

	-- Сохраняем результаты в файл
	local time = getRealTime()
	local dateStr = string.format("%02d.%02d.%d at %02d:%02d",
			time.monthday, time.month+1, time.year+1900, time.hour, time.minute)

	local fileExists = fileExists("results.csv")
	local file = fileExists and fileOpen("results.csv") or fileCreate("results.csv")
	local content = fileExists and fileRead(file, 99999) or ""
	fileClose(file)

	local newContent = "\239\187\191" -- UTF-8 BOM

	if not fileExists then
		newContent = newContent.."SEP=,\n"
		newContent = newContent.."MATCH RESULTS\n\n"
		newContent = newContent.."NOTE: For correct number formatting in Excel:\n"
		newContent = newContent.."1. Use 'Data -> Text to Columns'\n"
		newContent = newContent.."2. Select 'Delimited' -> Next\n"
		newContent = newContent.."3. Check 'Comma' -> Next\n"
		newContent = newContent.."4. For 'Points Per Map' column select 'Text' format\n"
		newContent = newContent.."5. Click 'Finish'\n\n"
	end

	newContent = newContent.."\nMatch Date:,,"..dateStr
	newContent = newContent.."\nTeams:,,"..getTeamName(teams[1]).." vs "..getTeamName(teams[2])
	newContent = newContent.."\nScore:,,"..t1score.." - "..t2score
	newContent = newContent.."\nResult:,,"..(t1score > t2score and getTeamName(teams[1]).." won" or t1score < t2score and getTeamName(teams[2]).." won" or "Draw").."\n"

	newContent = newContent.."\nNickname,Rounds Played,Points,Maps Won,\"Points Per Map\",1st,2nd,3rd,4th,5th,6th,7th,8th,9th,10th,DNF"

	for k, v in ipairs(getElementsByType("player")) do
		if getElementData(v, 'Score') > 0 then
			local nickname = removeHex(getPlayerName(v),6)
			local points = getElementData(v, 'Score')
			local mapsPlayed = getElementData(v, 'Maps played')
			local mapsWon = getElementData(v, 'Maps won')
			local pointsPerMap = mapsPlayed > 0 and string.format("%.1f", points/mapsPlayed) or "0.0"

			local pos1 = getElementData(v, 'race_pos_1') or 0
			local pos2 = getElementData(v, 'race_pos_2') or 0
			local pos3 = getElementData(v, 'race_pos_3') or 0
			local pos4 = getElementData(v, 'race_pos_4') or 0
			local pos5 = getElementData(v, 'race_pos_5') or 0
			local pos6 = getElementData(v, 'race_pos_6') or 0
			local pos7 = getElementData(v, 'race_pos_7') or 0
			local pos8 = getElementData(v, 'race_pos_8') or 0
			local pos9 = getElementData(v, 'race_pos_9') or 0
			local pos10 = getElementData(v, 'race_pos_10') or 0
			local dnf = getElementData(v, 'race_dnf') or 0

			newContent = newContent.."\n"..nickname..","..mapsPlayed..","..points..","..mapsWon..",\""..pointsPerMap.."\","..
					pos1..","..pos2..","..pos3..","..pos4..","..pos5..","..
					pos6..","..pos7..","..pos8..","..pos9..","..pos10..","..dnf
		end
	end

	newContent = newContent.."\n\n"..string.rep(",", 15).."End of match record\n"

	local outputFile = fileCreate("results.csv")
	fileWrite(outputFile, content..newContent)
	fileFlush(outputFile)
	fileClose(outputFile)

	outputInfo("Match results with detailed position stats saved to results.csv")
end

function isAdmin(thePlayer)
	if not thePlayer then return true end
	if isObjectInACLGroup("user."..getAccountName(getPlayerAccount(thePlayer)), aclGetGroup("Admin")) then
		return true
	else
		return false
	end
end

function isClientAdmin(client)
	local accName = getAccountName(getPlayerAccount(client))
	if isObjectInACLGroup("user."..accName, aclGetGroup("Admin")) then
		clientCall(client, 'updateAdminInfo', true)
	else
		clientCall(client, 'updateAdminInfo', false)
	end
end

function playerJoin(source)
	if isElement(teams[1]) then
		clientCall(source, 'updateTeamData', teams[1], teams[2], teams[3])
		clientCall(source, 'updateRoundData', c_round, rounds, f_round, round_ended)
		setPlayerTeam(source, teams[3])
	end
	local serial = getPlayerSerial(source)
	if playerData[serial] ~= nil then
		setElementData(source, 'Score', playerData[serial]["score"])
		setElementData(source, 'Pts per map', playerData[serial]["ppm"])
		setElementData(source, 'Maps played', playerData[serial]["mp"])
		setElementData(source, 'Maps won', playerData[serial]["mw"])
		setElementData(source, 'roundScore', 0)
		-- Initialize position stats
		for pos = 1, 10 do
			setElementData(source, 'race_pos_'..pos, playerData[serial]["pos_"..pos] or 0)
		end
		setElementData(source, 'race_dnf', playerData[serial]["dnf"] or 0)
	else
		setElementData(source, 'Score', 0)
		setElementData(source, 'Pts per map', 0)
		setElementData(source, 'Maps played', 0)
		setElementData(source, 'Maps won', 0)
		setElementData(source, 'roundScore', 0)
		-- Initialize position stats
		for pos = 1, 10 do
			setElementData(source, 'race_pos_'..pos, 0)
		end
		setElementData(source, 'race_dnf', 0)
	end
end

function playerLogin(p_a, c_a)
	local accName = getAccountName(c_a)
	if isObjectInACLGroup("user."..accName, aclGetGroup("Admin")) then
		clientCall(source, 'updateAdminInfo', true)
	else
		clientCall(source, 'updateAdminInfo', false)
	end
end

-------------------
-- FROM ADMIN PANEL
-------------------
function startWar(team1name, team2name, r1, g1, b1, r2, g2, b2)
	destroyTeams()
	teams[1] = createTeam(team1name, r1, g1, b1)
	teams[2] = createTeam(team2name, r2, g2, b2)
	teams[3] = createTeam('Spectators', 255, 255, 255)
	for i,player in ipairs(getElementsByType('player')) do
		setPlayerTeam(player, teams[3])
		setElementData(player, 'Score', 0)
		setElementData(player, 'Pts per map', 0)
		setElementData(player, 'Maps played', 0)
		setElementData(player, 'Maps won', 0)
		setElementData(player, 'roundScore', 0)
		-- Initialize position stats
		for pos = 1, 10 do
			setElementData(player, 'race_pos_'..pos, 0)
		end
		setElementData(player, 'race_dnf', 0)
	end
	setElementData(teams[1], 'Score', 0)
	setElementData(teams[2], 'Score', 0)
	setElementData(teams[1], 'Pts per map', "")
	setElementData(teams[2], 'Pts per map', "")
	setElementData(teams[3], 'Pts per map', "")
	setElementData(teams[1], 'Maps played', "")
	setElementData(teams[2], 'Maps played', "")
	setElementData(teams[3], 'Maps played', "")
	setElementData(teams[1], 'Maps won', "")
	setElementData(teams[2], 'Maps won', "")
	setElementData(teams[3], 'Maps won', "")
	round_ended = true
	c_round = 0
	call(getResourceFromName("scoreboard"), "scoreboardAddColumn", "Score")
	call(getResourceFromName("scoreboard"), "scoreboardAddColumn", "Pts per map")
	call(getResourceFromName("scoreboard"), "scoreboardAddColumn", "Maps played")
	call(getResourceFromName("scoreboard"), "scoreboardAddColumn", "Maps won")
	for i, player in ipairs(getElementsByType('player')) do
		clientCall(player, 'updateTeamData', teams[1], teams[2], teams[3])
		clientCall(player, 'updateRoundData', c_round, rounds, f_round, round_ended)
		clientCall(player, 'createGUI', getTeamName(teams[1]), getTeamName(teams[2]))
	end
end

function updateRounds(cur_round, ma_round)
	c_round = cur_round
	rounds = ma_round
	for i, player in ipairs(getElementsByType('player')) do
		clientCall(player, 'updateRoundData', c_round, rounds, f_round, round_ended)
	end
end

function sincAP()
	for i,player in ipairs(getElementsByType('player')) do
		clientCall(player, 'updateAdminPanelText')
	end
end

--------------------
-- CAR & BLIP COLORS
--------------------
function setColors()
	local s_team = getPlayerTeam(source)
	local p_veh = getPedOccupiedVehicle(source)
	if s_team then
		local r, g, b = getTeamColor(s_team)
		setVehicleColor(p_veh, r, g, b, 255, 255, 255)
	end
end

function getBlipAttachedTo(thePlayer)
	local blips = getElementsByType("blip")
	for k, theBlip in ipairs(blips) do
		if getElementAttachedTo(theBlip) == thePlayer then
			return theBlip
		end
	end
	return false
end

------------
-- EVENTS
------------
addEvent('onMapStarting', true)
addEventHandler('onMapStarting', getRootElement(), startRound)

addEvent('onPlayerFinish', true)
addEventHandler('onPlayerFinish', getRootElement(), playerFinished)

addEvent('onPostFinish', true)
addEventHandler('onPostFinish', getRootElement(), endRound)

addEventHandler('onPlayerLogin', getRootElement(), playerLogin)

addEventHandler('onPlayerVehicleEnter', getRootElement(), setColors)

addEvent('onPlayerReachCheckpoint', true)
addEventHandler('onPlayerReachCheckpoint', getRootElement(), setColors)

addEvent("onRaceStateChanging")
addEventHandler("onRaceStateChanging",getRootElement(),
		function(old, new)
			local players = getElementsByType("player")
			for k,v in ipairs(players) do
				local thePlayer = v
				local playerTeam = getPlayerTeam (thePlayer)
				local theBlip = getBlipAttachedTo(thePlayer)
				local r,g,b
				if ( playerTeam ) then
					if old == "Running" and new == "GridCountdown" then
						r, g, b = getTeamColor (playerTeam)
						setBlipColor(theBlip, tostring(r), tostring(g), tostring(b), 255)
						if playerTeam == teams[3] then
							triggerClientEvent(thePlayer, 'onSpectateRequest', getRootElement())
						end
					end
				end
			end
		end
)

--------------------
-- ADDITIONAL EVENTS
--------------------

addEventHandler("onPlayerQuit", getRootElement(),
		function()
			if isElement(teams[1]) and isElement(teams[2]) and isElement(teams[3]) then
				if getElementData(source, 'Score') > 0 and isWarEnded == false then
					local serial = getPlayerSerial(source)
					playerData[serial] = {}
					playerData[serial]["score"] = getElementData(source, 'Score')
					playerData[serial]["ppm"] = getElementData(source, 'Pts per map')
					playerData[serial]["mp"] = getElementData(source, 'Maps played')
					playerData[serial]["mw"] = getElementData(source, 'Maps won')
					playerData[serial]["roundScore"] = getElementData(source, 'roundScore') or 0
					-- Save position stats
					for pos = 1, 10 do
						playerData[serial]["pos_"..pos] = getElementData(source, 'race_pos_'..pos) or 0
					end
					playerData[serial]["dnf"] = getElementData(source, 'race_dnf') or 0
				end
			end
		end
)

addEventHandler("onRaceStateChanging",getRootElement(),
		function(state)
			local players = getElementsByType("player")
			for k,v in ipairs(players) do
				local thePlayer = v
				local playerTeam = getPlayerTeam (thePlayer)
				if isElement(teams[1]) and isElement(teams[2]) and isElement(teams[3]) then
					if playerTeam ~= teams[3] and not f_round and c_round > 0 then
						if state == "SomeoneWon" then
							local mp = 1
							local old_mp = getElementData(thePlayer, 'Maps played')
							new_mp = old_mp + mp
							setElementData(thePlayer, 'Maps played', new_mp)
						end
					end
				end
			end
		end
)

addEvent ('onCaptainsChosen', true )
addEventHandler ('onCaptainsChosen', root, function (t1_text, t2_text)
	if t1_text == "" or t2_text == "" then
		outputInfo("None or one captain were chosen. Get your things straight, manager.", root , 155, 155, 255, true)
	else
		outputInfo(t1_text.." and "..t2_text.." were selected as teams' captains", root , 155, 155, 255, true)
		outputInfo("They can use the following commands: #00FF00/r #FF0000/f")
	end
	captain1 = t1_text
	captain2 = t2_text
end )

function getRoundStatus()
	return isRoundActive
end
