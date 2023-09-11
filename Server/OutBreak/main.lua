--original code: https://github.com/Olrosse/BeamMP-Outbreak
--code contributions, edits, and clarity by wreckedcarzz (https://wreckedcarzz.com)



---settings---
local varAutoStartDelay = 90 -- what the delay between autostartted rounds should be
varAutoStartEnabled = false -- if the game automatically starts every varAutoStartDelay sectonds
local varInfectedNearbyDistance = 250 -- how close the infected player(s) have to be for the screen to start turning green; in meters
local varInfectedTintIntensity = 0.5 -- max intensity of the green filter; 0.00 to 1.00
local varInfectedPulsingColor = false -- if the infected player(s) car(s) should pulse between the car's original color and green
local varInfectedTintedScreen = false -- if infected player(s) should have a green tint applied to their scrfeen
local varNotifyDuringMatch = true -- if the chat box should be used as a deterrent for car spawns or edits during a match (also see below)
local varNotifyEveryTime = 5 -- the number of seconds between the chat box notification
local varNotifySpawnEditText = "INFECTION MATCH IN PROGRESS! DO NOT SPAWN OR EDIT VEHICLES!" -- text used to deter players from making any new 'events' that will desync players and break the game, causing affected players to rejoin the server
local varNotifyRepairRespawn = "ALL players must come to a COMPLETE STOP before repairing; non-infected must NOT have a green-tinted screen to repair." -- explaining rules regarding repairing
local varRoundLength = 10*60 -- lenght of the game, in seconds (minutes*seconds, so default is 10 minutes)
local varStartingSeconds = 10 -- the number of seconds before the initial player is revealed as infected
local varWakeWord = "infected" -- customizable word for text commands ( /varWakeWord <action> ) CRITICAL NOTE: if you change this to anything but "infected" or "outbreak", you need to update the 3 instances of "local value = tonumber(string.sub(message,<THIS-NUMBER>,10000))" where THIS NUMBER is the total number of characters, including the /, until and including the % for the settings menu to be functional
---end settings area---



--[[
DONE renamed local-global variables to better names
DONE corrected spelling and grammar mistakes
DONE reworded almost all strings presented to the player
DONE moved variables around in a few places to be more logical and grouped
DONE new variables for the word to respond to for commands
DONE new variables/settings for the round duartion
DONE enabled/exposed the automatic game start mode + added variables/settings
DONE added a notification to not spawn or edit cars during a match + new variables/settings
DONE adding help for new settings, reorganized
DONE one type of toggle for settings
DONE add setting for autostart duration
DONE offer credits/info through wakeWord
DONE variables renamed within functions
DONE error with advanced settings text
DONE if < 2 players, disable autostart countdown

SOME possible error with leaving players not subtracting from game

TODO start with multiple infected
TODO tell players how to start zombie mode, for when no admin is present
TODO change in-code setting names

TODO no tabbing when not infected / all players
TODO no restore/repair if within zombie tint area
TODO if event in progress, remove newly spawned car 
]]



---variables (non-settings)---
local varAutoStartTimer = 0
local varExcludedPlayers = {} --TODO make these do something
local varFloor = math.floor
local varIncludedPlayers = {} --TODO make these do something
local varMod = math.fmod
local varNoticeSwitch = true

---variables and executables
gameState = {players = {}}

---variables (non-settings)
local varLastState = gameState
local varWeightingArray = {}



gameState.everyoneInfected = false
gameState.gameRunning = false
gameState.gameEnding = false

MP.RegisterEvent("onContactRecieve","onContact")
MP.RegisterEvent("requestGameState","requestGameState")
MP.TriggerClientEvent(-1, "resetInfected", "data")

local function secondsToDaysHoursMinutesSeconds(totalSeconds) --modified code from https://stackoverflow.com/questions/45364628/lua-4-script-to-convert-seconds-elapsed-to-days-hours-minutes-seconds
    local varDays     = varFloor(totalSeconds / 86400)
    local varHours    = varFloor(varMod(totalSeconds, 86400) / 3600)
    local varMinutes  = varFloor(varMod(totalSeconds, 3600) / 60)
    local varSeconds  = varFloor(varMod(totalSeconds, 60))

	if varDays == 0 then
		varDays = nil
	end
    if varHours == 0 then
        varHours = nil
    end
	if varMinutes == 0 then
		varMinutes = nil
	end
	if varSeconds == 0 then
		varSeconds = nil
	end
    return varDays, varHours, varMinutes, varSeconds
end

local function compareTable(gameState,varTempTable,varLastState)
	for varableName,varable in pairs(gameState) do
		if type(varable) == "table" then
			if not varLastState[varableName] then
				varLastState[varableName] = {}
			end
			if not varTempTable[varableName] then
				varTempTable[varableName] = {}
			end
			compareTable(gameState[varableName],varTempTable[varableName],varLastState[varableName])
			if type(varTempTable[varableName]) == "table" and next(varTempTable[varableName]) == nil then
				varTempTable[varableName] = nil
			end
		elseif varable == "remove" then
			varTempTable[varableName] = gameState[varableName]
			varLastState[varableName] = nil
			gameState[varableName] = nil
		elseif varLastState[varableName] ~= varable then
			varTempTable[varableName] = gameState[varableName]
			varLastState[varableName] = gameState[varableName]
		end
	end
end

local function updateClients()
	local varTempTable = {}

	compareTable(gameState,varTempTable,varLastState)

	if varTempTable and next(varTempTable) ~= nil then
		MP.TriggerClientEventJson(-1, "updateGameState", varTempTable)
	end
end

function requestGameState(varLocalPlayerID)
	MP.TriggerClientEventJson(varLocalPlayerID, "recieveGameState", gameState)
end

local function infectPlayer(varPlayerName,varForce)
	local varTempPlayer = gameState.players[varPlayerName]
	if varTempPlayer.localContact and varTempPlayer.remoteContact and not varTempPlayer.infected or varForce and not varTempPlayer.infected then
		varTempPlayer.infected = true
		if not varForce then
			local varInfectorPlayerName = varTempPlayer.infecter
			gameState.players[varInfectorPlayerName].stats.infected = gameState.players[varInfectorPlayerName].stats.infected + 1
			gameState.InfectedPlayers = gameState.InfectedPlayers + 1
			gameState.nonInfectedPlayers = gameState.nonInfectedPlayers - 1
			gameState.oneInfected = true

			MP.SendChatMessage(-1,""..varInfectorPlayerName.." has infected "..varPlayerName.."!")
		else
			MP.SendChatMessage(-1,"Server has infected "..varPlayerName.."!")
		end

		MP.TriggerClientEvent(-1, "recieveInfected", varPlayerName)

		updateClients()
		-- this is commented in the original code
		--MP.TriggerClientEventJson(-1, "recieveGameState", gameState)
	end
end

function onContact(varLocalPlayerID, varData)
	local varRemotePlayerName = MP.GetPlayerName(tonumber(varData))
	local varLocalPlayerName = MP.GetPlayerName(varLocalPlayerID)
	if gameState.gameRunning and not gameState.gameEnding then
		local varLocalPlayer = gameState.players[varLocalPlayerName]
		local varRemotePlayer = gameState.players[varRemotePlayerName]
		if varLocalPlayer and varRemotePlayer then
			if varLocalPlayer.infected and not varRemotePlayer.infected then
				gameState.players[varRemotePlayerName].remoteContact = true
				gameState.players[varRemotePlayerName].infecter = varLocalPlayerName
				infectPlayer(varRemotePlayerName)
			end
			if varRemotePlayer.infected and not varLocalPlayer.infected then
				gameState.players[varLocalPlayerName].localContact = true
				gameState.players[varLocalPlayerName].infecter = varRemotePlayerName
				infectPlayer(varLocalPlayerName)
			end
			if gameState.nonInfectedPlayers == 0 then 
				gameState.everyoneInfected = true
				updateClients()
			end
		end
	end
end

local function gameSetup() -- has the setting names to change
	gameState = {}
	gameState.players = {}
	
	-- at some point I should change these
	gameState.settings = {
		GreenFadeDistance = varInfectedNearbyDistance,
		ColorPulse = varInfectedPulsingColor,
		infectorTint = varInfectedTintedScreen,
		distancecolor = varInfectedTintIntensity
		}
	local varPlayerCount = 0
	for ID,Player in pairs(MP.GetPlayers()) do
		if MP.IsPlayerConnected(ID) and MP.GetPlayerVehicles(ID) then
			if not varWeightingArray[Player] then
				varWeightingArray[Player] = {}
				varWeightingArray[Player].games = 1
				varWeightingArray[Player].infections = 1
			else
				varWeightingArray[Player].games = varWeightingArray[Player].games + 1
			end

			local varPlayer = {}
			varPlayer.stats = {}
			varPlayer.stats.infected = 0
			varPlayer.ID = ID
			varPlayer.infected = false
			varPlayer.localContact = false
			varPlayer.remoteContact = false
			gameState.players[Player] = varPlayer
			varPlayerCount = varPlayerCount + 1
			-- commented out in original code
			--MP.TriggerClientEvent(-1, "addPlayers", tostring(k))
			MP.TriggerClientEvent(-1, "addPlayers", Player)
		end
	end

	if varPlayerCount == 0 then
		MP.SendChatMessage(-1,"Failed to start; found no vehicles in play.")
		return
	elseif varPlayerCount == 1 then
		MP.SendChatMessage(-1,"Failed to start; this game needs at least two (2) players to begin.")
		return
	end

	gameState.playerCount = varPlayerCount
	gameState.InfectedPlayers = 0
	gameState.nonInfectedPlayers = varPlayerCount
	gameState.time = -5
	gameState.varRoundLength = varRoundLength
	gameState.endtime = -1
	gameState.oneInfected = false
	gameState.everyoneInfected = false
	gameState.gameRunning = true
	gameState.gameEnding = false
	gameState.gameEnded = false
	
	MP.TriggerClientEventJson(-1, "recieveGameState", gameState)
end

local function gameEnd(varReason)
	gameState.gameEnding = true
	local varInfectedCount = 0
	local varNonInfectedCount = 0
	local varPlayers = gameState.players
	for k,player in pairs(varPlayers) do
		if player.infected then
			varInfectedCount = varInfectedCount + 1
		else
			varNonInfectedCount = varNonInfectedCount + 1
		end
	end
	if varReason == "time" then
		MP.SendChatMessage(-1,"Game over, "..varNonInfectedCount.." survived and "..varInfectedCount.." were infected.")
	elseif varReason == "infected" then
		MP.SendChatMessage(-1,"Game over, no survivors.")
	elseif varReason == "manual" then
		MP.SendChatMessage(-1,"Game manually halted; "..varNonInfectedCount.." survived, "..varInfectedCount.." were infected.")
		gameState.endtime = gameState.time + 10
	else
		MP.SendChatMessage(-1,"Game halted for unknown reason; "..varNonInfectedCount.." survived and "..varInfectedCount.." were infected.")
	end
	--print(gameState)
end

local function infectRandomPlayer()
	gameState.oneInfected = false
	local varPlayers = gameState.players
	local varWeightRatio = 0
	for playername,player in pairs(varPlayers) do

		local varInfections = varWeightingArray[playername].infections
		local varGameCount = varWeightingArray[playername].games
		local varPlayerCount = gameState.playerCount

		local weight = math.max(1,(1/((varGameCount/varInfections)/varPlayerCount))*100)
		varWeightingArray[playername].startNumber = varWeightRatio
		varWeightRatio = varWeightRatio + weight
		varWeightingArray[playername].endNumber = varWeightRatio
		varWeightingArray[playername].weightRatio = varWeightRatio
		--print(playername,varWeightingArray[playername].endNumber - varWeightingArray[playername].startNumber,varWeightingArray[playername].startNumber , varWeightingArray[playername].endNumber,varWeightingArray[playername].infections,varWeightingArray[playername].games,gameState.playerCount)
	end

	local varRandomID = math.random(1, math.floor(varWeightRatio))
	
	for playername,player in pairs(varPlayers) do
		if varRandomID >= varWeightingArray[playername].startNumber and varRandomID <= varWeightingArray[playername].endNumber then --if count == varRandomID then
			if not gameState.oneInfected then
				gameState.players[playername].remoteContact = true
				gameState.players[playername].localContact = true
				gameState.players[playername].infected = true

				if gameState.time == varStartingSeconds then
					MP.SendChatMessage(-1,""..playername.." is the first infected!")
				else
					MP.SendChatMessage(-1,"No infected players; "..playername.." has been randomly infected!")
				end
				MP.TriggerClientEvent(-1, "recieveInfected", playername)
				gameState.oneInfected = true
				gameState.InfectedPlayers = gameState.InfectedPlayers + 1
				gameState.nonInfectedPlayers = gameState.nonInfectedPlayers - 1
			end
		else
			varWeightingArray[playername].infections = varWeightingArray[playername].infections + 100
		end
	end
	--print(infectedCount , gameState.playerCount , varNonInfectedCount)
	if gameState.InfectedPlayers >= gameState.playerCount and gameState.nonInfectedPlayers == 0 then
		gameState.everyoneInfected = true
	end

	MP.TriggerClientEventJson(-1, "recieveGameState", gameState)
	--print(varRandomID,varWeightingArray)
end

local function gameStarting()
	local varDays, varHours, varMinutes, varSeconds = secondsToDaysHoursMinutesSeconds(varRoundLength)
	local varAmount = 0
	if varDays then
		varAmount = varAmount + 1
	end
	if varHours then
		varAmount = varAmount + 1
	end
	if varMinutes then
		varAmount = varAmount + 1
	end
	if varSeconds then
		varAmount = varAmount + 1
	end
	if varDays then
		varAmount = varAmount - 1
		if varDays == 1 then
			if varAmount > 1 then
				varDays = ""..varDays.." day, "
			elseif varAmount == 1 then
				varDays = ""..varDays.." day and "
			elseif varAmount == 0 then
				varDays = ""..varDays.." day "
			end
		else
			if varAmount > 1 then
				varDays = ""..varDays.." days, "
			elseif varAmount == 1 then
				varDays = ""..varDays.." days and "
			elseif varAmount == 0 then
				varDays = ""..varDays.." days "
			end
		end
	end
	if varHours then
		varAmount = varAmount - 1
		if varHours == 1 then
			if varAmount > 1 then
				varHours = ""..varHours.." hour, "
			elseif varAmount == 1 then
				varHours = ""..varHours.." hour and "
			elseif varAmount == 0 then
				varHours = ""..varHours.." hour "
			end
		else
			if varAmount > 1 then
				varHours = ""..varHours.." hours, "
			elseif varAmount == 1 then
				varHours = ""..varHours.." hours and "
			elseif varAmount == 0 then
				varHours = ""..varHours.." hours "
			end
		end
	end
	if varMinutes then
		varAmount = varAmount - 1
		if varMinutes == 1 then
			if varAmount > 1 then
				varMinutes = ""..varMinutes.." minute, "
			elseif varAmount == 1 then
				varMinutes = ""..varMinutes.." minute and "
			elseif varAmount == 0 then
				varMinutes = ""..varMinutes.." minute "
			end
		else
			if varAmount > 1 then
				varMinutes = ""..varMinutes.." minutes, "
			elseif varAmount == 1 then
				varMinutes = ""..varMinutes.." minutes and "
			elseif varAmount == 0 then
				varMinutes = ""..varMinutes.." minutes "
			end
		end
	end
	if varSeconds then
		if varSeconds == 1 then
			varSeconds = ""..varSeconds.." second "
		else
			varSeconds = ""..varSeconds.." seconds "
		end
	end

	MP.SendChatMessage(-1,"Infection game started; you have "..varStartingSeconds.." seconds before the zombie is revealed! Survive for "..(varDays or "0").."days, "..(varHours or "0").." hours, "..(varMinutes or "0").." minutes, and "..(varSeconds or "0").."seconds.")
end

local function gameRunningLoop() --code in this loop runs every 1s during an active match
	if gameState.time < 0 then
		MP.SendChatMessage(-1,"Infection game starting in "..math.abs(gameState.time).." second(s)...")
	elseif gameState.time == 0 then
		gameStarting()
	end

	if not gameState.gameEnding and gameState.playerCount == 0 then
		gameState.gameEnding = true
		gameState.endtime = gameState.time + 2
	end

	local varPlayers = gameState.players

	if not gameState.gameEnding and gameState.time > 0 then
		local varInfectedCount = 0
		local varNonInfectedCount = 0
		local varPlayerCount = 0
				
		if varNotifyDuringMatch == true and math.fmod(gameState.time, varNotifyEveryTime) == 0 then
			if varNoticeSwitch == true then
				MP.SendChatMessage(-1,varNotifySpawnEditText)
				varNoticeSwitch = false
			else
				MP.SendChatMessage(-1,varNotifyRepairRespawn)
				varNoticeSwitch = true
			end
		end
		
		for playername,player in pairs(varPlayers) do
			if player.localContact and player.remoteContact and not player.infected then
				player.infected = true
				MP.SendChatMessage(-1,""..playername.." has been infected! Run!")
				MP.TriggerClientEvent(-1, "recieveInfected", playername)
			end

			if player.infected then
				varInfectedCount = varInfectedCount + 1
			elseif not player.infected then
				varNonInfectedCount = varNonInfectedCount + 1
			end
			varPlayerCount = varPlayerCount + 1
		end
		if varInfectedCount >= gameState.playerCount and varNonInfectedCount == 0 then
			gameState.everyoneInfected = true
		end
		gameState.InfectedPlayers = varInfectedCount
		gameState.nonInfectedPlayers = varNonInfectedCount
		gameState.playerCount = varPlayerCount

		if gameState.time >= varStartingSeconds and varInfectedCount == 0 then
			infectRandomPlayer()
		end
	end

	if not gameState.gameEnding and gameState.time == gameState.varRoundLength then
		gameEnd("time")
		gameState.endtime = gameState.time + 10
	elseif not gameState.gameEnding and gameState.everyoneInfected == true then
		gameEnd("infected")
		gameState.endtime = gameState.time + 10
	elseif gameState.gameEnding and gameState.time == gameState.endtime then
		gameState.gameRunning = false
		
		-- this is commented in the original code
		--MP.TriggerClientEvent(-1, "resetInfected", "data")
		--print(gameState.gameEnding ,gameState.time ,gameState.endtime)

		gameState = {}
		gameState.players = {}
		gameState.everyoneInfected = false
		gameState.gameRunning = false
		gameState.gameEnding = false
		gameState.gameEnded = true

		-- this too
		--MP.TriggerClientEventJson(-1, "recieveGameState", gameState)
	end
	if gameState.gameRunning then
		gameState.time = gameState.time + 1
	end

	updateClients()
	--print(gameState)
end

-- MOVED varAutoStartEnabled FROM HERE
-- moved varAutoStartTimer FROM HERE

function timer() -- I think this runs every 1s
	if gameState.gameRunning then
		gameRunningLoop()
	elseif varAutoStartEnabled and MP.GetPlayerCount() > 1 then --was -1
		--print(varAutoStartTimer)
		if varAutoStartTimer < varAutoStartDelay and string.find(varAutoStartTimer, 0) then
			MP.SendChatMessage(-1,"Automatic zombie gamemode enabled; "..varAutoStartDelay - varAutoStartTimer.." seconds remaining.")
		elseif varAutoStartTimer + 5 >= varAutoStartDelay then
			varAutoStartTimer = -1
			gameSetup()
		end
		varAutoStartTimer = varAutoStartTimer + 1
	-- this needs testing
	elseif varAutoStartEnabled and MP.GetPlayerCount() < 2 then
		varAutoStartTimer = 0
		
		-- this may not be needed
		varAutoStartEnabled = false;
		MP.SendChatMessage(sender_id,"Cannot autostart the match, as it requires at least two (2) players. Autostate disabled.")
	end
end

MP.RegisterEvent("onContact", "onContact")
MP.RegisterEvent("second", "timer")

MP.CancelEventTimer("counter")
MP.CancelEventTimer("second")
MP.CreateEventTimer("second",1000)

--Chat Commands
function outbreakChatMessageHandler(sender_id, sender_name, message)
	if message == "/"..varWakeWord.." join" then -- or string.find(message,"/"..varWakeWord.." join %d+") then
		--local number = tonumber(string.sub(message,14,10000))
		--local playerid = number or sender_id
		local varTempPlayerName = MP.GetPlayerName(sender_id)
		varIncludedPlayers[sender_id] = true
		MP.SendChatMessage(sender_id,""..varTempPlayerName.." has been added to the game.")
		return 1
		
	elseif message == "/"..varWakeWord.." leave" then -- or string.find(message,"/"..varWakeWord.." leave %d+") then
		--local number = tonumber(string.sub(message,15,10000))
		--local playerid = number or sender_id
		local varTempPlayerName = MP.GetPlayerName(sender_id)
		varIncludedPlayers[sender_id] = nil
		MP.SendChatMessage(sender_id,""..varTempPlayerName.." has been removed from the game.")
		return 1
		
	elseif message == "/"..varWakeWord.." start" then -- or string.find(message,"/"..varWakeWord.." start %d+") then
		varAutoStartTimer = 0
		varAutoStartEnabled = false
		local number = tonumber(string.sub(message,16,10000))
		if not gameState.gameRunning then
			local gameLength = number or varRoundLength
			gameSetup()
		else
			MP.SendChatMessage(sender_id,"Error: gamestart failed, game already running.")
		end

		return 1
		
	elseif message == "/"..varWakeWord.." stop" then
		if varAutoStartEnabled == true then
			varAutoStartTimer = 0
			varAutoStartEnabled = false
			if gameState.gameRunning then
				gameEnd("manual")
			end
			MP.SendChatMessage(sender_id,"Succesfully turned autostart OFF.")
		elseif gameState.gameRunning then
			gameEnd("manual")
		else
			MP.SendChatMessage(sender_id,"Error: gamestop failed, game not running.")
		end

		return 1
		
	elseif message == "/"..varWakeWord.." autostart" then
		if not gameState.gameRunning then
			if MP.GetPlayerCount() > 1 then
				varAutoStartTimer = 0
				varAutoStartEnabled = true
				MP.SendChatMessage(sender_id,"Succesfully turned autostart ON.")
			else
				MP.SendChatMessage(sender_id,"Failed to enable autostart; this could be because you are by yourself (this mode requires at least two (2) players to start).")
			end
		else
			MP.SendChatMessage(sender_id,"Failed to enable autostart; existing game in progress.")
		end
		
		return 1

	elseif message == "/"..varWakeWord.." autostart delay %d+" then
		local value = tonumber(string.sub(message,27,10000))
		varAutoStartDelay = value
		MP.SendChatMessage(sender_id,"Succesfully adjusted autostart timer to:"..value..".")
		
		return 1
	
    elseif string.find(message,"/"..varWakeWord.." length %d+") then
		local value = tonumber(string.sub(message,18,10000))
		if value then
			varRoundLength = value*60
			MP.SendChatMessage(sender_id,"Successfully set game length to "..value..".")
		else
			MP.SendChatMessage(sender_id,"Error: setting varRoundLength failed, no valid value found.")
		end
		return 1

    elseif string.find(message,"/"..varWakeWord.." infectedNearbyDistance %d+") then
		local value = tonumber(string.sub(message,34,10000))
		if value then
			varInfectedNearbyDistance = value
			if gameState.settings then
				gameState.settings.GreenFadeDistance = varInfectedNearbyDistance
			end
			MP.SendChatMessage(sender_id,"Succesfully set infectedNearbyDistance to "..value..".")
		else
			MP.SendChatMessage(sender_id,"Error: setting infectedNearbyDistance failed, no valid value found.")
		end
		return 1

    elseif string.find(message,"/"..varWakeWord.." infectedPulsingColor") then
		if varInfectedPulsingColor then
			varInfectedPulsingColor = false
			MP.SendChatMessage(sender_id,"Succesfully setting infectedPulsingColor to false/off.")
		else
			varInfectedPulsingColor = true
			MP.SendChatMessage(sender_id,"Succesfully setting infectedPulsingColor to true/on. NOTE: infectedTintedScreen MUST be set to true/on, otherwise infectedPulsingColor will cause a game crash! It is FALSE/OFF by default!")
		end
		if gameState.settings then
			gameState.settings.ColorPulse = varInfectedPulsingColor
		end
		return 1

    elseif string.find(message,"/"..varWakeWord.." infectedTintedScreen") then
		if varInfectedTintedScreen then
			varInfectedTintedScreen = false
			MP.SendChatMessage(sender_id,"Succesfully set infectedTintedScreen to false/off.")
		else
			varInfectedTintedScreen = true
			MP.SendChatMessage(sender_id,"Succesfully set infectedTintedScreen to true/on.")
		end
		if gameState.settings then
			gameState.settings.infectorTint = varInfectedTintedScreen
		end
		return 1

    elseif string.find(message,"/"..varWakeWord.." infectedTintIntensity %d+") then
		local value = tonumber(string.sub(message,33,10000))
		if value then
			varInfectedTintIntensity = value
			if gameState.settings then
				gameState.settings.distancecolor = varInfectedTintIntensity
			end 
			MP.SendChatMessage(sender_id,"Succesfully set infectedTintIntensity to "..value..".")
			
		else
			MP.SendChatMessage(sender_id,"Error: setting infectedTintIntensity failed, no valid value found.")
		end
		return 1

    elseif string.find(message,"/"..varWakeWord.." reset") then
			varWeightingArray = {}
		return 1
		
	elseif string.find(message,"/"..varWakeWord.." credits") then
		MP.SendChatMessage(sender_id,"Original code by: Olrosse, Stefan750, and Saile; https://github.com/Olrosse/BeamMP-Outbreak/tree/v0.2.0")
		MP.SendChatMessage(sender_id,"Code improvements, cleanup, feature enabling and refinement by wreckedcarzz (https://wreckedcarzz.com) for the Talons of War (https://TalonsOfWar.com) BeamMP servers.")
		
		return 1
		
    elseif message == "/"..varWakeWord.." help" then
		MP.SendChatMessage(sender_id,"Basic settings:")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." start")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." stop")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." autostart")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." length [minutes]")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." reset (resets the infection randomizer)")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." credits")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." advancedSettings")
	elseif message == "/"..varWakeWord.." advancedSettings" then
		MP.SendChatMessage(sender_id,"Advanced settings:")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." infectedNearbyDistance [meters] (default: "..varInfectedNearbyDistance.."; at what distance does the screen begin to tint for non-infected players near an infected player)")
		if varInfectedPulsingColor then
			MP.SendChatMessage(sender_id,"/"..varWakeWord.." infectedPulsingColor (default: true; do infected cars 'pulse' green? NOTE: infectedTintedScreen MUST be set to true/on, otherwise infectedPulsingColor will cause a game crash! It is FALSE/OFF by default!")
		else--if
			MP.SendChatMessage(sender_id,"/"..varWakeWord.." infectedPulsingColor (default: false; do infected cars 'pulse' green? NOTE: infectedTintedScreen MUST be set to true/on, otherwise infectedPulsingColor will cause a game crash! It is FALSE/OFF by default!")
		end
		if varInfectedTintedScreen then
			MP.SendChatMessage(sender_id,"/"..varWakeWord.." infectedTintedScreen (default: true; if infected players have a green tint applied to their screen)")
		else
			MP.SendChatMessage(sender_id,"/"..varWakeWord.." infectedTintedScreen (default: false; if infected players have a green tint applied to their screen)")
		end
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." infectedTintIntensity [0.00 to 1.00] (default: "..varInfectedTintIntensity.."; sets the intensity of the green tint)")
		MP.SendChatMessage(sender_id,"Settings do NOT save, but are reset every server restart.")
	
	-- disabled, original code	
	--	varExcludedPlayers[]
		return 1
    else
        return 0
	end
end

function onPlayerDisconnect(playerID)
	local varPlayerName = MP.GetPlayerName(playerID)
	if gameState.gameRunning and gameState.players and gameState.players[varPlayerName] then
		gameState.players[varPlayerName] = "remove"
	end
end

function onVehicleDeleted(playerID,vehicleID)
	local varPlayerName = MP.GetPlayerName(playerID)
	if gameState.gameRunning and gameState.players and gameState.players[varPlayerName] then
		if not MP.GetPlayerVehicles(playerID) then
			gameState.players[varPlayerName] = "remove"
		end
	end
end

MP.TriggerClientEventJson(-1, "recieveGameState", gameState)
MP.TriggerClientEvent(-1, "resetInfected", "data")

-- I don't know why this is here
MP.RegisterEvent("onChatMessage", "outbreakChatMessageHandler")
MP.RegisterEvent("onPlayerDisconnect", "onPlayerDisconnect")
MP.RegisterEvent("onVehicleDeleted", "onVehicleDeleted")
MP.RegisterEvent("onPlayerJoin", "requestGameState")

