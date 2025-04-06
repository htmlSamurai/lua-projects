--init
local s_x, s_y = guiGetScreenSize()
local text_offset = 20
local teams = {}
local c_round = 0
local m_round = 0
local f_round = false
local team_choosen = false
local isAdmin = false

local teamColorcodes = {
	["AF"] = "65, 215, 249",
	["AFE"] = "128, 0, 128",
	["ALW"] = "254, 254, 34",
	["AQ"] = "255, 0, 25",
	["BOR"] = "195, 12, 57",
	["CRF"] = "255, 204, 0",
	["FOX"] = "255, 0, 0",
	["LFSAN"] = "63, 0, 0",
	["LSR"] = "3, 145, 253",
	["MW"] = "68, 68, 34",
	["NKC"] = "0, 69, 135",
	["NKC-A"] = "0, 69, 135",
	["NKC-B"] = "0, 69, 135",
	["NET"] = "25, 25, 25",
	["RTF"] = "35, 43, 43",
	["SIK"] = "0, 255, 0",
	["SKC"] = "255, 128, 0",
	["SKC-A"] = "255, 128, 0",
	["SKC-B"] = "255, 128, 0",
	["UDKA"] = "236, 24, 0",

	["ARG"] = "170, 255, 255",
	["ARG-1"] = "170, 255, 255",
	["ARG-2"] = "170, 255, 255",
	["BR"] = "0, 156, 59",
	["BR-1"] = "0, 156, 59",
	["BR-2"] = "0, 39, 118",
	["BR-3"] = "255, 223, 0",
	["CL"] = "128, 5, 23",
	["CZ"] = "0, 0, 255",
	["GER"] = "255, 215, 0",
	["HUN"] = "189, 0, 0",
	["LT"] = "12, 98, 59",
	["NBS"] = "255, 255, 255",
	["PL"] = "255, 0, 0",
	["PL-1"] = "255, 0, 0",
	["PL-2"] = "255, 0, 0",
	["PL-3"] = "255, 0, 0",
	["TR"] = "255, 255, 255",
	["TR-1"] = "255, 255, 255",
	["TR-2"] = "255, 0, 0",
	["YUGO"] = "255, 20, 147"
}

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
        for key, value in next, arg do
            if (type(value) == "number") then arg[key] = tostring(value) end
        end
    end
    triggerServerEvent("onClientCallsServerFunction", resourceRoot , funcname, unpack(arg))
end

function clientCall(funcname, ...)
    local arg = { ... }
    if (arg[1]) then
        for key, value in next, arg do arg[key] = tonumber(value) or value end
    end
    loadstring("return "..funcname)()(unpack(arg))
end
addEvent("onServerCallsClientFunction", true)
addEventHandler("onServerCallsClientFunction", resourceRoot, clientCall)


------------------------
-- DISPLAY
------------------------

function dxDrawRoundedRectangle(x, y, rx, ry, color, radius)
    rx = rx - radius * 2
    ry = ry - radius * 2
    x = x + radius
    y = y + radius

    if (rx >= 0) and (ry >= 0) then
        dxDrawRectangle(x, y, rx, ry, color)
        dxDrawRectangle(x, y - radius, rx, radius, color)
        dxDrawRectangle(x, y + ry, rx, radius, color)
        dxDrawRectangle(x - radius, y, radius, ry, color)
        dxDrawRectangle(x + rx, y, radius, ry, color)	
        dxDrawCircle(x, y, radius, 180, 270, color, color, 7)
        dxDrawCircle(x + rx, y, radius, 270, 360, color, color, 7)
        dxDrawCircle(x + rx, y + ry, radius, 0, 90, color, color, 7)
        dxDrawCircle(x, y + ry, radius, 90, 180, color, color, 7)
    end
end

function updateDisplay()
	--score
	if isElement(teams[1]) and isElement(teams[2]) then
		if not f_round then
			local r1, g1, b1 = getTeamColor(teams[1])
			local r2, g2, b2 = getTeamColor(teams[2])			
           dxDrawRoundedRectangle(s_x-200.5, 66, 143.5, 135, tocolor(0, 0, 0, 180), 20)
           dxDrawRoundedRectangle(s_x-215.5, 110, 173.5, 50, tocolor(208, 54, 54, 255), 20)
			dxDrawText('Round ' ..c_round.. ' of ' ..m_round, s_x-127.5, 135, s_x-127.5, 135, tocolor ( 255, 255, 255, 255 ), 1.9, "default-bold", 'center', 'center')			
			if tonumber(getElementData(teams[1], 'Score')) > tonumber(getElementData(teams[2], 'Score')) then
				dxDrawText(getTeamName(teams[1]).. ' - ' ..getElementData(teams[1], 'Score'), s_x-127.5, 0+text_offset, s_x-127.5, 140+text_offset, tocolor ( r1, g1, b1, 255 ), 1.4, "default-bold", 'center', 'center')
				dxDrawText(getTeamName(teams[2]).. ' - ' ..getElementData(teams[2], 'Score'), s_x-127.5, 0+text_offset*9, s_x-127.5, 140+text_offset*2, tocolor ( r2, g2, b2, 255 ), 1.4, "default-bold", 'center', 'center')			
			elseif tonumber(getElementData(teams[1], 'Score')) < tonumber(getElementData(teams[2], 'Score')) then
				dxDrawText(getTeamName(teams[1]).. ' - ' ..getElementData(teams[1], 'Score'), s_x-127.5, 0+text_offset, s_x-127.5, 140+text_offset, tocolor ( r1, g1, b1, 255 ), 1.4, "default-bold", 'center', 'center')
				dxDrawText(getTeamName(teams[2]).. ' - ' ..getElementData(teams[2], 'Score'), s_x-127.5, 0+text_offset*9, s_x-127.5, 140+text_offset*2, tocolor ( r2, g2, b2, 255 ), 1.4, "default-bold", 'center', 'center')			
			elseif tonumber(getElementData(teams[1], 'Score')) == tonumber(getElementData(teams[2], 'Score')) then
				dxDrawText(getTeamName(teams[1]).. ' - ' ..getElementData(teams[1], 'Score'), s_x-127.5, 0+text_offset, s_x-127.5, 140+text_offset, tocolor ( r1, g1, b1, 255 ), 1.4, "default-bold", 'center', 'center')
				dxDrawText(getTeamName(teams[2]).. ' - ' ..getElementData(teams[2], 'Score'), s_x-127.5, 0+text_offset*9, s_x-127.5, 140+text_offset*2, tocolor ( r2, g2, b2, 255 ), 1.4, "default-bold", 'center', 'center')
			end
		else
			dxDrawRoundedRectangle(s_x-220.5, 100, 182.5, 75, tocolor(0, 0, 0, 180), 20)
			dxDrawText('Fun Round', s_x-125, 140, s_x-127.5, 140, tocolor ( 255, 255, 255, 255 ), 2.6, "default-bold", 'center', 'center')
		end
	end
end


------------------------
--GUI
------------------------

local c_window

function createGUI(team1, team2) -- choose GUI
	if isElement(c_window) then
		destroyElement(c_window)
	end
	c_window = guiCreateWindow(s_x/2-150, s_y/2-75, 300, 140, 'Team Select', false)
	guiWindowSetMovable(c_window, false)
	guiWindowSetSizable(c_window, false)
	local t1_button = guiCreateButton(40, 35, 100, 30, team1, false, c_window)
	addEventHandler("onClientGUIClick", t1_button, team1Choosen, false)
	local t2_button = guiCreateButton(160, 35, 100, 30, team2, false, c_window)
	addEventHandler("onClientGUIClick", t2_button, team2Choosen, false)
	local t3_button = guiCreateButton(40, 85, 220, 30, 'Spectators', false, c_window)
	addEventHandler("onClientGUIClick", t3_button, team3Choosen, false)
	showCursor(true)
end

--admin GUI
local a_window

function createAdminGUI()
	if isElement(a_window) then
		destroyElement(a_window)
	end
	a_window = guiCreateWindow(s_x/2-150, s_y/2-75, 400, 250, 'Race League Admin Panel - v1.5', false)
	guiWindowSetSizable(a_window, false)
	close_button = guiCreateButton(10, 220, 380, 30, 'C L O S E', false, a_window)
	addEventHandler("onClientGUIClick", close_button, function() guiSetVisible(a_window, false) showCursor(false) end, false)
	tab_panel = guiCreateTabPanel(0, 0.09, 1, 0.75, true, a_window)
	guiCreateLabel(270, 25, 150, 20, "Admin Panel by Vally", false, a_window)
		-- tab 1
		tab_general = guiCreateTab('General', tab_panel)
		guiCreateLabel(20, 20, 150, 20, "Team Names:", false, tab_general)
		guiCreateLabel(20, 25, 150, 20, "______________", false, tab_general)
		if isElement(teams[1]) then
			t1name = getTeamName(teams[1])
		else
			t1name = 'Team 1'
		end
		t1_field = guiCreateEdit(20, 45, 80, 20, t1name, false, tab_general)
		if isElement(teams[2]) then
			t2name = getTeamName(teams[1])
		else
			t2name = 'Team 2'
		end
		t2_field = guiCreateEdit(20, 70, 80, 20, t2name, false, tab_general)
		guiCreateLabel(150, 20, 150, 20, "Team Colors:", false, tab_general)
		guiCreateLabel(150, 25, 110, 20, "______________________", false, tab_general)
		if isElement(teams[1]) then
			t1color = getTeamColor(teams[1])
		else
			t1color = '0, 0, 0'
		end
		t1c_field = guiCreateEdit(150, 45, 110, 20, t1color, false, tab_general)
		if isElement(teams[2]) then
			t2color = getTeamColor(teams[2])
		else
			t2color = '0, 0, 0'
		end
		t2c_field = guiCreateEdit(150, 70, 110, 20, t2color, false, tab_general)
		zadat_button = guiCreateButton(280, 45, 80, 45, 'Apply', false, tab_general)
		addEventHandler("onClientGUIClick", zadat_button, zadatTeams, false)
		--another placement: colorcode_button = guiCreateButton(280, 10, 80, 30, 'Get Colorcodes', false, tab_general)
		colorcode_button = guiCreateButton(110, 45, 30, 45, 'Get RGB', false, tab_general)
		addEventHandler("onClientGUIClick", colorcode_button, getColorcodes, false)
		start_button = guiCreateButton(20, 120, 100, 25, 'Start CW', false, tab_general)
		addEventHandler("onClientGUIClick", start_button, startWar, false)
		stop_button = guiCreateButton(140, 120, 100, 25, 'Stop CW', false, tab_general)
		addEventHandler("onClientGUIClick", stop_button, function() serverCall('destroyTeams', localPlayer) end, false)
		fun_button = guiCreateButton(260, 120, 100, 25, 'Fun Round', false, tab_general)
		addEventHandler("onClientGUIClick", fun_button, function() serverCall('funRound', localPlayer) end, false)

		-- tab 2
		tab_rounds = guiCreateTab('Rounds & Score', tab_panel)
		guiCreateLabel(20, 20, 150, 20, "Score:", false, tab_rounds)
		guiCreateLabel(20, 25, 150, 20, "________________", false, tab_rounds)
		tt1_name = guiCreateLabel(20, 47, 150, 20, "Team 1:", false, tab_rounds)
		tt2_name = guiCreateLabel(20, 72, 150, 20, "Team 2:", false, tab_rounds)
		local t1_score
		local t2_score
		if isElement(teams[1]) then t1_score = getElementData(teams[1], 'Score') else t1_score = '0' end
		if isElement(teams[2]) then t2_score = getElementData(teams[2], 'Score') else t2_score = '0' end
		t1cur_field = guiCreateEdit(85, 45, 50, 20, tostring(t1_score), false, tab_rounds)
		t2cur_field = guiCreateEdit(85, 70, 50, 20, tostring(t2_score), false, tab_rounds)
		guiCreateLabel(155, 20, 150, 20, "Rounds:", false, tab_rounds)
		guiCreateLabel(155, 25, 150, 20, "_______________", false, tab_rounds)
		guiCreateLabel(155, 47, 150, 20, "Current:", false, tab_rounds)
		guiCreateLabel(155, 72, 150, 20, "Total:", false, tab_rounds)
		cr_field = guiCreateEdit(220, 45, 40, 20, tostring(c_round), false, tab_rounds)
		ct_field = guiCreateEdit(220, 70, 40, 20, tostring(m_round), false, tab_rounds)
		zadat_button2 = guiCreateButton(280, 45, 80, 45, 'Apply', false, tab_rounds)
		addEventHandler("onClientGUIClick", zadat_button2, zadatScoreRounds, false)

		-- tab3
		tab_caps = guiCreateTab('Captains', tab_panel)
		tt1_name = guiCreateLabel(20, 20, 150, 20, "Team 1 Captain:", false, tab_caps)
		guiCreateLabel(20, 25, 150, 20, "________________", false, tab_caps)
		t1_playersList = guiCreateComboBox (20, 41, 113, 123, "", false, tab_caps)
		tt2_name = guiCreateLabel(155, 20, 150, 20, "Team 2 Captain:", false, tab_caps)
		guiCreateLabel(155, 25, 150, 20, "_______________", false, tab_caps)
		t2_playersList = guiCreateComboBox (155, 41, 113, 123, "", false, tab_caps)
		for key,player in ipairs(getElementsByType('player')) do 
			guiComboBoxAddItem(t1_playersList, removeHex(getPlayerName(player), 6))
			guiComboBoxAddItem(t2_playersList, removeHex(getPlayerName(player), 6))
		end
		zadat_button3 = guiCreateButton(280, 45, 80, 45, 'Apply', false, tab_caps)
		addEventHandler("onClientGUIClick", zadat_button3, zadatCaptains, false)
	guiSetVisible(a_window, false)
end

function toogleGUI() -- choose GUI
	if isElement(c_window) then
		if guiGetVisible(c_window) then
			guiSetVisible(c_window, false)
			if not guiGetVisible(a_window) then
				showCursor(false)
			end
		elseif not guiGetVisible(c_window) then
			guiSetVisible(c_window, true)
			showCursor(true)
		end
	end
end

function toogleAdminGUI()
	if isAdmin then
		if isElement(a_window) then
			if guiGetVisible(a_window) then
				guiSetVisible(a_window, false)
				if isElement(c_window) then
					if not guiGetVisible(c_window) then
						showCursor(false)
					end
				else
					showCursor(false)
				end
			elseif not guiGetVisible(a_window) then
				updateAdminPanelText()
				guiSetVisible(a_window, true)
				showCursor(true)
			end
		end
	end
end

function updateAdminPanelText()
	if isElement(teams[1]) then
		local team1name = getTeamName(teams[1])
		local team2name = getTeamName(teams[2])
		guiSetText(t1_field, team1name)
		guiSetText(t2_field, team2name)
		local r1, g1, b1 = getTeamColor(teams[1])
		local r2, g2, b2 = getTeamColor(teams[2])
		guiSetText(t1c_field, r1.. ', ' ..g1.. ', ' ..b1)
		guiSetText(t2c_field, r2.. ', ' ..g2.. ', ' ..b2)
		local t1score = getElementData(teams[1], 'Score')
		local t2score = getElementData(teams[2], 'Score')
		guiSetText(tt1_name, team1name.. ':')
		guiSetText(tt2_name, team2name.. ':')
		guiSetText(t1cur_field, t1score)
		guiSetText(t2cur_field, t2score)
		guiSetText(cr_field, c_round)
		guiSetText(ct_field, m_round)
	end
end


------------------------
-- BUTTON FUNCTIONS
------------------------

function team1Choosen()
	serverCall('setPlayerTeam', localPlayer, teams[1])
	if not guiGetVisible(a_window) then
		showCursor(false)
	end
	guiSetVisible(c_window, false)
	outputChatBox('[Race League]: Press F3 to select team again', 155, 155, 255, true)
end

function team2Choosen()
	serverCall('setPlayerTeam', localPlayer, teams[2])
	if not guiGetVisible(a_window) then
		showCursor(false)
	end
	guiSetVisible(c_window, false)
	outputChatBox('[Race League]: Press F3 to select team again', 155, 155, 255, true)
end

function team3Choosen()
	serverCall('setPlayerTeam', localPlayer, teams[3])
	if not guiGetVisible(a_window) then
		showCursor(false)
	end
	guiSetVisible(c_window, false)
	outputChatBox('[Race League]: Press F3 to select team again', 155, 155, 255, true)
end

function zadatCaptains()
	local t1_item = guiComboBoxGetSelected(t1_playersList)
 	t1_text = tostring(guiComboBoxGetItemText(t1_playersList, t1_item))
	local t2_item = guiComboBoxGetSelected(t2_playersList)
	t2_text = tostring(guiComboBoxGetItemText(t2_playersList, t2_item))
	triggerServerEvent ('onCaptainsChosen', localPlayer, t1_text, t2_text)
end

function zadatScoreRounds()
	local t1score = guiGetText(t1cur_field)
	local t2score = guiGetText(t2cur_field)
	local cur_round = guiGetText(cr_field)
	local ma_round = guiGetText(ct_field)
	if isElement(teams[1]) and isElement(teams[2]) then
		setElementData(teams[1], 'Score', t1score)
		setElementData(teams[2], 'Score', t2score)
	end
	serverCall('updateRounds', cur_round, ma_round)
end

function zadatTeams()
	local t1name = guiGetText(t1_field)
	local t2name = guiGetText(t2_field)
	local t1color = guiGetText(t1c_field)
	local t2color = guiGetText(t2c_field)
	if isElement(teams[1]) and isElement(teams[2]) then
		local r1,g1,b1 = stringToNumber(t1color)
		local r2,g2,b2 = stringToNumber(t2color)
		serverCall('setTeamName', teams[1], t1name)
		serverCall('setTeamColor', teams[1], r1, g1, b1)
		serverCall('setTeamName', teams[2], t2name)
		serverCall('setTeamColor', teams[2], r2, g2, b2)
		serverCall('sincAP')
	end
end

function getColorcodes()
	local t1name = string.upper(guiGetText(t1_field))
	local t2name = string.upper(guiGetText(t2_field))
	if teamColorcodes[t1name] then
		local colorcode1 = teamColorcodes[t1name]
		guiSetText(t1c_field, colorcode1)
	else
		guiSetText(t1c_field, "Wrong clantag!")
	end
	if teamColorcodes[t2name] then
		local colorcode2 = teamColorcodes[t2name]
		guiSetText(t2c_field, colorcode2)
	else
		guiSetText(t2c_field, "Wrong clantag!")
	end
end

function startWar()
	local t1name = guiGetText(t1_field)
	local t2name = guiGetText(t2_field)
	local t1color = guiGetText(t1c_field)
	local t2color = guiGetText(t2c_field)
	local r1,g1,b1 = stringToNumber(t1color)
	local r2,g2,b2 = stringToNumber(t2color)
	serverCall('startWar', t1name, t2name, r1, g1, b1, r2, g2, b2)
end


----------------------------
-- OTHER FUNCTIONS
----------------------------

function updateTeamData(team1, team2, team3)
	teams[1] = team1
	teams[2] = team2
	teams[3] = team3
	updateAdminPanelText()
end

function updateRoundData(c_r, max_r, f_r)
	if c_r == 0 then
		f_round = true
	else
		f_round = f_r
	end
	c_round = c_r
	m_round = max_r
	updateAdminPanelText()
end

function updateAdminInfo(obj)
	isAdmin = obj
	if isAdmin then
		createAdminGUI()
		outputChatBox('[Race League]: Press F2 to open admin panel', 155, 155, 255, true)
	end
end

function onResStart()
	serverCall('isClientAdmin', localPlayer)
	createAdminGUI()
end

function stringToNumber(colorsString)
	local r = gettok(colorsString, 1, string.byte(','))
	local g = gettok(colorsString, 2, string.byte(','))
	local b = gettok(colorsString, 3, string.byte(','))
	if r == false or g == false or b == false then
		outputChatBox('[Race League]: Use - [0-255], [0-255], [0-255]', 255, 155, 155, true)
		return 0, 255, 0
	else
		return r, g, b
	end
end


----------------------------
-- BINDS
----------------------------

createAdminGUI()
setTimer(function() if isElement(teams[1]) then createGUI(getTeamName(teams[1]), getTeamName(teams[2])) end end, 1000, 1)
bindKey('F3', 'down', toogleGUI)
bindKey('F2', 'down', toogleAdminGUI)
serverCall('playerJoin', localPlayer)


----------------------------
-- EVENT HANDLERS
----------------------------

addEvent('onCaptainsChosen', true)
addEventHandler('onCaptainsChosen', getRootElement(), zadatCaptains)
addEventHandler('onClientRender', getRootElement(), updateDisplay)
addEventHandler('onClientResourceStart', getResourceRootElement(), onResStart)
--guiCreateLabel(30, 3, 200, 200, '*Race League script by [CsB]Vally', false)


--------------------
-- ADDITIONAL EVENTS
--------------------

addEventHandler('onClientRender', getRootElement(), 
function()
	if isElement(teams[1]) and isElement(teams[2]) and isElement(teams[3]) then
		if not f_round and c_round > 0 and getElementData(getPlayerTeam(localPlayer), 'Score') ~= 0 and getElementData(localPlayer, 'Maps played') ~= 0 then
			local score_ppm = getElementData(localPlayer, 'Score')
			local maps_ppm = getElementData(localPlayer, 'Maps played')
			setElementData(localPlayer, 'Pts per map', tostring(math.round((score_ppm/maps_ppm), 1, "ceil")))
		elseif getPlayerTeam(localPlayer) == teams[3] then
			setElementData(getPlayerTeam(localPlayer), 'Pts per map', "")
		else
			setElementData(localPlayer, 'Pts per map', 0)
			setElementData(getPlayerTeam(localPlayer), 'Pts per map', "")
		end
	end
end
)

addEventHandler('onClientPlayerJoin', getRootElement(),
function()
	guiComboBoxAddItem(t1_playersList, removeHex(getPlayerName(source), 6))
	guiComboBoxAddItem(t2_playersList, removeHex(getPlayerName(source), 6))
end)

addEventHandler('onClientPlayerQuit', getRootElement(),
function()
	for row = 0, guiComboBoxGetItemCount(t1_playersList) - 1 do 
		if (guiComboBoxGetItemText(t1_playersList, row) == removeHex(getPlayerName(source),6)) then 
			guiComboBoxRemoveItem(t1_playersList, row)
		end 
	end 
	for row = 0, guiComboBoxGetItemCount(t2_playersList) - 1 do 
		if (guiComboBoxGetItemText(t2_playersList, row) == removeHex(getPlayerName(source),6)) then 
			guiComboBoxRemoveItem(t2_playersList, row)
		end 
	end 
end)

addEventHandler('onClientPlayerChangeNick', getRootElement(),
function(old_nick, new_nick)
	for row = 0, guiComboBoxGetItemCount(t1_playersList) - 1 do 
		if (guiComboBoxGetItemText(t1_playersList, row) == removeHex(old_nick,6)) then 
			guiComboBoxSetItemText(t1_playersList, row, removeHex(new_nick,6))
		end 
	end 
	for row = 0, guiComboBoxGetItemCount(t2_playersList) - 1 do 
		if (guiComboBoxGetItemText(t2_playersList, row) == removeHex(old_nick,6)) then 
			guiComboBoxSetItemText(t2_playersList, row, removeHex(new_nick,6))
		end 
	end 
end)
