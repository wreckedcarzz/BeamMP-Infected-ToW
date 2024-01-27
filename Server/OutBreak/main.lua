-- original code: https://github.com/Olrosse/BeamMP-Outbreak
-- code contributions, edits, and clarity by wreckedcarzz (https://wreckedcarzz.com) for the Talons of War clan (https://TalonsOfWar.com)
-- if you change/edit/use/share any of my altered code, I simply ask that you retain this notice - and any other notices in any other files - as credit to my hard work



---settings---
local varAnnouncerEnabled = true -- turn on/off voiceovers
local varAnnouncerEnabledDefault = true -- this is what the default will be, when users use the 'reset' command; since varAnnouncerEnabled is a setting that can be manipulated, this value is necessary. in most cases, you want varAnnouncerEnabledDefault to be the same as varAnnouncerEnabled
local varAnnouncerType = "midnight" -- if you want to use a human voice (midnight) or an artificial one (robot)
local varAnnouncerTypeDefault = "midnight" -- this is what the default will be, when users use the 'reset' command; since varAnnouncerType is a setting that can be manipulated, this value is necessary. in most cases, you want varAnnouncerTypeDefault to be the same as varAnnouncerType
local varAutoStartDelay = 90 -- what the delay between autostartted rounds should be
local varAutoStartEnabled = false -- if the game automatically starts every varAutoStartDelay sectonds
local varAutoStartReminderInterval = 180 -- how many seconds (with at least 2 players) without a zombie match starting to remind the players how to play
local varDiscordURL = "https://discord.gg/qF8yy2r9sr" -- the permanent Discord invite URL, used for /support
-- qF8yy2r9sr for rules, y8zPEQ6yVy for modded, du7PctMC3K for vanilla
local varInfectedNearbyDistance = 250 -- how close the infected player(s) have to be for the screen to start turning green; in meters
local varInfectedTintIntensity = 0.5 -- max intensity of the green filter; 0.00 to 1.00
local varInfectedPulsingColor = false -- if the infected player(s) car(s) should pulse between the car's original color and green
local varInfectedTintedScreen = false -- if infected player(s) should have a green tint applied to their scrfeen
--local varMaxNumberOfStartingZombies = 1 -- set the max number of infected at the beginning of each round
local varNotifyDuringMatch = true -- if the chat box should be used as a deterrent for car spawns or edits during a match (also see below)
local varNotifyEveryTime = 5 -- the number of seconds between the chat box notification
local varNotifySpawnEditText = "INFECTION MATCH IN PROGRESS! DO NOT SPAWN OR EDIT VEHICLES!" -- text used to deter players from making any new 'events' that will desync players and break the game, causing affected players to rejoin the server
local varNotifyRepairRespawn = "ALL players must come to a COMPLETE STOP before repairing; non-infected must NOT have a green-tinted screen to repair." -- explaining rules regarding repairing
local varRoundLength = 10*60 -- lenght of the game, in seconds (minutes*seconds, so default is 10 minutes)
local varServerOwner = "wreckedcarzz" -- name of the server owner
local varStartingSeconds = 10 -- the number of seconds before the initial player is revealed as infected
local varSupportMessage = "Hello! If you are being harassed or bothered, or if a player is ruining your activity, you can first 'vote kick' them via the blue Cobalt Essentials Interface, and if enough players also vote to remove them, they will be kicked. If the situation is more serious, or if they return and continue to bother players, reach out to the server owner ("..varServerOwner..") or an admin or mod (orange or yellow nametag in Cobalt), or use our Discord server to reach us: "..varDiscordURL.." under #help. We are here for you!"
local varWakeWord = "infected" -- customizable word for text commands ( /varWakeWord <action> ) CRITICAL NOTE: if you change this to anything but "infected" or "outbreak", you need to update the 3 instances of "local value = tonumber(string.sub(message,<THIS-NUMBER>,10000))" where THIS NUMBER is the total number of characters, including the /, until and including the % for the settings menu to be functional
local varStopMsg = "You can stop a live match by typing '/"..varWakeWord.." stop'" -- message shown at the end of 
local varStopAutoMsg = "You can disable autostart (and stop a live match) by typing '/"..varWakeWord.." stop'" -- autostart variant of above
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
DONE spelling/more grammer issues fixed
DONE comment cleanupDONE messages for demeting a car and leaving during a match
DONE appears to be no possible error with leaving players not being subtracted from the game
DONE added /support and supporting variables
DONE show names with succesful setting change / game start, stop, etc events
DONE temporarily disable reminder 
DONE reset settings
DONE made support text a variable
DONE added error numbers to make troubleshooting easier

TEST colored nametags for teams
TEST credits 5s after a match
TEST onPlayerConnecting ending matches

BROKE start with multiple infected
-- while/do loop broken

TODO add 'spectator' tag to list for new joins that are not in match
TODO > 1 player autostart (with vehicle)
TODO change in-code setting names
TODO check if player starting match has a vehicle
TODO afk kick

TODO no tabbing when not infected / all players
TODO no restore/repair if within zombie tint area

TODO if event in progress, remove newly spawned car --this may not be necessary
TODO have teams and healing
]]



---variables (non-settings)---
gameState = {players = {}}
gameState.everyoneInfected = false
gameState.gameEnding = false
gameState.gameRunning = false
--varAutoStartDelay = varAutoStartDelay + 5 -- for end of match credits
local varAutoStartReminder = 0
local varAutoStartTimer = 0
local varDateEdited = "2024.01.26"
local varExcludedPlayers = {} --TODO make these do something
local varFloor = math.floor
local varLastState = gameState
local varIncludedPlayers = {} --TODO make these do something
local varMod = math.fmod
local varNoticeSwitch = true
local varNotifyCreditsAfter = 5
local varNotifyCreditsAfterCount = 0
--local varNotifyDisable = false
local varWeightingArray = {}

MP.RegisterEvent("onContact", "onContact")
MP.RegisterEvent("onContactRecieve","onContact")
MP.RegisterEvent("requestGameState","requestGameState")
MP.RegisterEvent("second", "timer")
MP.TriggerClientEvent(-1, "resetInfected", "data")

MP.CancelEventTimer("counter")
MP.CancelEventTimer("second")
MP.CreateEventTimer("second",1000)

-- game logic
function onPlayerConnecting(ID)
	if gameState.gameRunning == true then
		gameEnd("playerConnecting")
	end
end

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
	
	if varDays == 0 and varHours == 0 and varMinutes == 0 and varSeconds == 0 then
		MP.SendChatMessage(-1, "Error: time added up to zero/nil, this should never happen! (Error 1.)")
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
			
			if varAnnouncerEnabled then
				if varAnnouncerType == "midnight" then
					MP.TriggerClientEvent(-1, "playAudio", "playerInfected")
				else
					MP.TriggerClientEvent(-1, "playAudio", "robotPlayerInfected")
				end
			end
		else
			MP.SendChatMessage(-1,"Zombie has left! Server has infected "..varPlayerName.." as a replacement.")
			
			if varAnnouncerEnabled then
				if varAnnouncerType == "midnight" then
					MP.TriggerClientEvent(-1, "playAudio", "replacementInfected")
				else
					MP.TriggerClientEvent(-1, "playAudio", "robotReplacementInfected")
				end
			end
		end

		MP.TriggerClientEvent(-1, "recieveInfected", varPlayerName)

		updateClients()
	end
end

function onContact(varLocalPlayerID, varData)
	local varRemotePlayerName = MP.GetPlayerName(tonumber(varData))
	local varLocalPlayerName = MP.GetPlayerName(varLocalPlayerID)
	if gameState.gameRunning and not gameState.gameEnding then  -- game is running and not ending
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

	if varPlayerCount == 0 and varAutoStartEnabled then -- if there are no players/spawned cars
		varAutoStartTimer = 0
		varAutoStartEnabled = false
		MP.SendChatMessage(-1,"Failed to start; found no vehicles in play. Disabling autostart. (Error 2a.)")
		return
	elseif varPlayerCount == 0 then -- if there are no players/spawned cars
		MP.SendChatMessage(-1,"Failed to start; found no vehicles in play. (Error 2b.)")
		return
	elseif varPlayerCount == 1 and varAutoStartEnabled then -- if there is only one player/spawned car
		varAutoStartTimer = 0
		varAutoStartEnabled = false
		MP.SendChatMessage(-1,"Failed to start; this game needs at least two (2) players to begin. Disabling autostart. (Error 3a.)")
		return
	elseif varPlayerCount == 1 then -- if there is only one player/spawned car
		MP.SendChatMessage(-1,"Failed to start; this game needs at least two (2) players to begin. (Error 3b.)")
		return
	end

	gameState.playerCount = varPlayerCount
	gameState.InfectedPlayers = 0 -- counting number of zombies
	gameState.nonInfectedPlayers = varPlayerCount
	gameState.time = -5
	gameState.varRoundLength = varRoundLength
	gameState.endtime = -1
	gameState.oneInfected = false
	gameState.everyoneInfected = false
	gameState.gameRunning = true
	gameState.gameEnding = false
	gameState.gameEnded = false
	
	varAutoStartReminder = 0
	
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
		MP.SendChatMessage(-1,"GAME OVER! "..varNonInfectedCount.." survived, "..varInfectedCount.." were infected.")
		
		if varAutoStartEnabled == true then
			MP.SendChatMessage(-1,varStopAutoMsg)
		end
		
		if varAnnouncerEnabled then
			if varAnnouncerType == "midnight" then
				MP.TriggerClientEvent(-1, "playAudio", "gameOverWithSurvivors")
			else
				MP.TriggerClientEvent(-1, "playAudio", "robotGameOverWithSurvivors")
			end
		end
		
	elseif varReason == "playerConnecting" then
		MP.SendChatMessage(-1,"GAME OVER, autostart disabled as a new player is connecting! "..varNonInfectedCount.." survived, "..varInfectedCount.." were infected.")
		
		if varAutoStartEnabled == true then
			varAutoStartEnabled = false
		end
		
		if varAnnouncerEnabled then
			if varAnnouncerType == "midnight" then
				MP.TriggerClientEvent(-1, "playAudio", "gameOverWithSurvivors")
			else
				MP.TriggerClientEvent(-1, "playAudio", "robotGameOverWithSurvivors")
			end
		end
		
	elseif varReason == "infected" then
		if varAnnouncerEnabled then
			os.execute("sleep "..tonumber(2)) -- sleep for 2 seconds to allow the announcer to state "infected!"
		end
		
		MP.SendChatMessage(-1,"GAME OVER! No survivors!")
		
		if varAutoStartEnabled == true then
			MP.SendChatMessage(-1,varStopAutoMsg)
		end
		
		if varAnnouncerEnabled then
			if varAnnouncerType == "midnight" then
				MP.TriggerClientEvent(-1, "playAudio", "gameOverNoSurvivors")
			else
				MP.TriggerClientEvent(-1, "playAudio", "robotGameOverNoSurvivors")
			end
		end
	elseif varReason == "manual" then
		MP.SendChatMessage(-1,"Game manually halted; "..varNonInfectedCount.." survived, "..varInfectedCount.." were infected.")
		gameState.endtime = gameState.time + 10
		
		if varAnnouncerEnabled then
			if varAnnouncerType == "midnight" then
				MP.TriggerClientEvent(-1, "playAudio", "gameHalted")
			else
				MP.TriggerClientEvent(-1, "playAudio", "robotGameHalted")
			end
		end
	else
		MP.SendChatMessage(-1,"Game halted for unknown reason; "..varNonInfectedCount.." survived and "..varInfectedCount.." were infected.")
		
		if varAnnouncerEnabled then
			if varAnnouncerType == "midnight" then
				MP.TriggerClientEvent(-1, "playAudio", "gameHaltedUnknownError")
			else
				MP.TriggerClientEvent(-1, "playAudio", "robotGameHaltedUnknownError")
			end
		end
	end
end

local function infectRandomPlayer() -- this still needs editing to achieve multiple starter zombies
	gameState.oneInfected = false -- no one is infected
	local varPlayers = gameState.players -- grab details about the players
	local varWeightRatio = 0
	for playername,player in pairs(varPlayers) do -- for each entry in varPlayers do

		local varInfections = varWeightingArray[playername].infections
		local varGameCount = varWeightingArray[playername].games
		local varPlayerCount = gameState.playerCount

		local weight = math.max(1,(1/((varGameCount/varInfections)/varPlayerCount))*100)
		varWeightingArray[playername].startNumber = varWeightRatio
		varWeightRatio = varWeightRatio + weight
		varWeightingArray[playername].endNumber = varWeightRatio
		varWeightingArray[playername].weightRatio = varWeightRatio
	end

	local varRandomID = math.random(1, math.floor(varWeightRatio))
	-- this generate a random int that is greater than or equal to 1, but also less than or equal to the largest int returned by math.floor(varWeightRatio); then
	-- itself is set by 'weight', which in turn is set by math.max given 'varGameCount' divided by 'varInfections' (# of times infected), divddid by 'varPlayerCount'; then
	-- this is used to devide 1 by the result, multiplied by 100
	
	local varNumberOfAssignedZombies = 0
	
	--while varNumberOfAssignedZombies < varMaxNumberOfStartingZombies and varNumberOfAssignedZombies < gameState.playerCount do
		for playername,player in pairs(varPlayers) do
			if varRandomID >= varWeightingArray[playername].startNumber and varRandomID <= varWeightingArray[playername].endNumber then --if count == varRandomID then
				if not gameState.players[playername].infected then -- removed 'if not gameState.oneInfected then'
					gameState.players[playername].remoteContact = true
					gameState.players[playername].localContact = true
					gameState.players[playername].infected = true

					if gameState.time == varStartingSeconds then
						MP.SendChatMessage(-1,""..playername.." is the first zombie!")
						
					else
						MP.SendChatMessage(-1,"No zombie players; "..playername.." has been randomly infected!")
					end
					
					if varAnnouncerEnabled then
						if varAnnouncerType == "midnight" then
							MP.TriggerClientEvent(-1, "playAudio", "playerInfected")
						else
							MP.TriggerClientEvent(-1, "playAudio", "robotPlayerInfected")
						end
					end
					
					MP.TriggerClientEvent(-1, "recieveInfected", playername)
					--gameState.oneInfected = true
					gameState.InfectedPlayers = gameState.InfectedPlayers + 1
					gameState.nonInfectedPlayers = gameState.nonInfectedPlayers - 1
					varNumberOfAssignedZombies = varNumberOfAssignedZombies + 1
				end
			else
				varWeightingArray[playername].infections = varWeightingArray[playername].infections + 100
			end
		end
	--end
	
	gameState.oneInfected = true
	
	if gameState.InfectedPlayers >= gameState.playerCount and gameState.nonInfectedPlayers == 0 then
		gameState.everyoneInfected = true
	end

	MP.TriggerClientEventJson(-1, "recieveGameState", gameState)
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
				varDays = ""..varDays.." day"
			end
		else
			if varAmount > 1 then
				varDays = ""..varDays.." days, "
			elseif varAmount == 1 then
				varDays = ""..varDays.." days and "
			elseif varAmount == 0 then
				varDays = ""..varDays.." days"
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
				varHours = ""..varHours.." hour"
			end
		else
			if varAmount > 1 then
				varHours = ""..varHours.." hours, "
			elseif varAmount == 1 then
				varHours = ""..varHours.." hours and "
			elseif varAmount == 0 then
				varHours = ""..varHours.." hours"
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
				varMinutes = ""..varMinutes.." minute"
			end
		else
			if varAmount > 1 then
				varMinutes = ""..varMinutes.." minutes, "
			elseif varAmount == 1 then
				varMinutes = ""..varMinutes.." minutes and "
			elseif varAmount == 0 then
				varMinutes = ""..varMinutes.." minutes"
			end
		end
	end
	if varSeconds then
		if varSeconds == 1 then
			varSeconds = ""..varSeconds.." second"
		else
			varSeconds = ""..varSeconds.." seconds"
		end
	end
	
	if varDays == 0 and varHours == 0 and varMinutes == 0 and varSeconds == 0 then
		MP.SendChatMessage(-1, "Error: time added up to zero/nil, this should never happen! (Error 4.)")
	end

	--MP.SendChatMessage(-1,"Infection game started; you have "..varStartingSeconds.." seconds before the zombie is revealed! Survive for "..(varDays or "0").." days, "..(varHours or "0").." hours, "..(varMinutes or "0").." minutes, and "..(varSeconds or "0").." seconds.")
	--MP.SendChatMessage(-1,"Infection game started; you have "..varStartingSeconds.." seconds before the zombie is revealed!")
	MP.SendChatMessage(-1,"Infection game started! Survive for "..(varDays or "")..""..(varHours or "")..""..(varMinutes or "")..""..(varSeconds or "")..".")
	
	if varAnnouncerEnabled then
		if varAnnouncerType == "midnight" then
			MP.TriggerClientEvent(-1, "playAudio", "infectedGameStart")
		else
			MP.TriggerClientEvent(-1, "playAudio", "robotInfectedGameStart")
		end
	end
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
		
		if varAnnouncerEnabled then
			if varRoundLength - gameState.time == 300 then -- 5 minutes remaining
				if varAnnouncerType == "midnight" then
					MP.TriggerClientEvent(-1, "playAudio", "remaining5minutes")
				else
					MP.TriggerClientEvent(-1, "playAudio", "robotRemaining5minutes")
				end
			elseif varRoundLength - gameState.time == 60 then
				if varAnnouncerType == "midnight" then
					MP.TriggerClientEvent(-1, "playAudio", "remaining1minute")
				else
					MP.TriggerClientEvent(-1, "playAudio", "robotRemaining1minute")
				end
			elseif varRoundLength - gameState.time == 30 then
				if varAnnouncerType == "midnight" then
					MP.TriggerClientEvent(-1, "playAudio", "remaining30seconds")
				else
					MP.TriggerClientEvent(-1, "playAudio", "robotRemaining30seconds")
				end
			end	
		end
				
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
			if player.localContact and player.remoteContact and not player.infected then -- players being made zombies
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
		
		gameState = {}
		gameState.players = {}
		gameState.everyoneInfected = false
		gameState.gameRunning = false
		gameState.gameEnding = false
		gameState.gameEnded = true
	end
	
	if gameState.gameRunning then
		gameState.time = gameState.time + 1
	end

	updateClients()
end

function timer() -- I think this runs every 1s
	if gameState.gameRunning then -- game is running
		gameRunningLoop()
	elseif varAutoStartEnabled and MP.GetPlayerCount() > 1 then -- autostart count down
		if varAutoStartTimer < varAutoStartDelay and string.find(varAutoStartTimer, 0) then
			MP.SendChatMessage(-1,"Automatic zombie gamemode enabled; "..varAutoStartDelay - varAutoStartTimer.." seconds remaining!") -- removed text: before the match begins.")
			MP.SendChatMessage(-1,"Chat with other players: "..varDiscordURL)
			MP.SendChatMessage(-1,varStopMsg)
		elseif varAutoStartTimer + 5 >= varAutoStartDelay then
			varAutoStartTimer = -1
			gameSetup()
		end
		varAutoStartTimer = varAutoStartTimer + 1
	elseif varAutoStartEnabled and MP.GetPlayerCount() < 2 then -- when there are less than 2 players
		varAutoStartTimer = 0
		varAutoStartEnabled = false
		MP.SendChatMessage(sender_id,"Cannot autostart the match, as it requires at least two (2) players. Autostate disabled. (Error 5.)")
	elseif not gameState.gameRunning and not gameState.gameEnding and not varAutoStartEnabled and MP.GetPlayerCount() > 1 then -- explaining how to start a match, edit settings
		varAutoStartReminder = varAutoStartReminder + 1
		if varAutoStartReminder >= varAutoStartReminderInterval then
			varAutoStartReminder = 0
			MP.SendChatMessage(-1,"You can start a zombie match quickly by typing '/"..varWakeWord.." autostart', or see the settings by typing /"..varWakeWord.." help'.")
		end
	elseif gameState.gameEnded and varNotifyCreditsAfter < varNotifyCreditsAfterCount then -- game has ended but has not reached point where credits show
		varNotifyCreditsAfterCount = varNotifyCreditsAfterCount + 1
	--elseif gameState.gameEnded and varNotifyCreditsAfter == varNotifyCreditsAfterCount then -- game has ended and credits now show
		gameState.gameEnded = false
		os.execute("sleep "..tonumber(3))
		MP.SendChatMessage(-1,"BeamMP Infected (ToW), version "..varDateEdited..".")
		MP.SendChatMessage(-1,"Original code by: Olrosse, Stefan750, and Saile; https://github.com/Olrosse/BeamMP-Outbreak")
		MP.SendChatMessage(-1,"Code improvements, clarity, cleanup, and additional features by: wreckedcarzz (https://wreckedcarzz.com) for the Talons of War clan (https://TalonsOfWar.com) BeamMP servers.")
		varNotifyCreditsAfterCount = 0
		os.execute("sleep "..tonumber(3))
	end
end

--- chat commands ---

function count(base, pattern)
    return select(2, string.gsub(base, pattern, ""))
end

function outbreakChatMessageHandler(sender_id, sender_name, message)
	--[[if message == "/"..varWakeWord.." join" then -- this doesn't work yet
		--local number = tonumber(string.sub(message,14,10000))
		--local playerid = number or sender_id
		local varTempPlayerName = MP.GetPlayerName(sender_id)
		varIncludedPlayers[sender_id] = true
		MP.SendChatMessage(sender_id,""..varTempPlayerName.." has been added to the game.")
		return 1
		
	elseif message == "/"..varWakeWord.." leave" then -- or this
		--local number = tonumber(string.sub(message,15,10000))
		--local playerid = number or sender_id
		local varTempPlayerName = MP.GetPlayerName(sender_id)
		varIncludedPlayers[sender_id] = nil
		MP.SendChatMessage(sender_id,""..varTempPlayerName.." has been removed from the game.")
		return 1
		
	else]]
	--MP.SendChatMessage(sender_id,string.find(message,"/"..varWakeWord.." maxStartingZombies %d+")
	
	if message == "/"..varWakeWord.." start" then
		varAutoStartTimer = 0
		varAutoStartEnabled = false
		local number = tonumber(string.sub(message,16,10000))
		
		if not gameState.gameRunning then
			local gameLength = number or varRoundLength
			MP.SendChatMessage(-1,sender_name.." has initiated an infected match.")
			gameSetup()
		elseif gameState.gameRunning then
			MP.SendChatMessage(sender_id,"Error: gamestart failed, game already running. (Error 6a.)")
		else
			MP.SendChatMessage(sender_id,"Error: something else has occured, and it is very bad; perhaps a variable naming issue. (Error 6b.)")
		end

		return 1
		
	elseif message == "/"..varWakeWord.." autostart" then
		if not gameState.gameRunning then
			if MP.GetPlayerCount() > 1 then
				varAutoStartTimer = 0
				varAutoStartEnabled = true
				MP.SendChatMessage(-1,sender_name.." successfully turned autostart ON. It is currently set to "..varAutoStartDelay.." seconds.")
			else
				MP.SendChatMessage(sender_id,"Failed to enable autostart; this could be because you are by yourself (this mode requires at least two (2) players to start). (Error 7a.)")
			end
		else
			MP.SendChatMessage(sender_id,"Failed to enable autostart; existing game in progress. (Error 7b.)")
		end
		
		return 1

	elseif string.find(message,"/"..varWakeWord.." autostart delay %d+") then
		local value = tonumber(string.sub(message,1 + string.len(varWakeWord) + 18,10000))

		if value then
			varAutoStartDelay = value
			MP.SendChatMessage(-1,sender_name.." successfully adjusted autostart timer to: "..value.." seconds.")
		else --for debuging
			MP.SendChatMessage(sender_id,"Error, recieved: "..value..". (Error 8.)")
		end 
		
		return 1
	
	elseif string.find(message,"/"..varWakeWord.." quiet %d+") then
		local valueToText = tonumber(string.sub(message,1 + string.len(varWakeWord) + 8,10000))
		local value = valueToText
		value = value*60
		--varNotifyDisable = true
		varAutoStartReminder = -value
		--varAutoStartReminder = varAutoStartReminder - varAutoStartReminder - varAutoStartReminder
		MP.SendChatMessage(-1,sender_name.." successfully silenced the reminder for "..valueToText.." minutes. You can still start and control matches while it is silenced.")
		
		return 1
	
    --[[elseif string.find(message,"/"..varWakeWord.." maxStartingZombies %d+") then
		local value = tonumber(string.sub(message,30,10000))
		
		if value then
			varMaxNumberOfStartingZombies = value
			MP.SendChatMessage(-1,sender_name.." successfully adjusted the maximum number of initial zombies to: "..value..".")
		else
			MP.SendChatMessage(sender_id,"Error: setting maxStartingZombies failed; recieved: "..value..". (Error 9.)")
		end
		
		return 1
	]]
	elseif message == "/"..varWakeWord.." stop" then
		if varAutoStartEnabled == true then -- if autostart ON
			varAutoStartEnabled = false
			varAutoStartTimer = 0
			MP.SendChatMessage(-1,sender_name.." successfully turned autostart OFF.")
			if gameState.gameRunning then -- and if game also running
				gameEnd("manual")
				MP.SendChatMessage(-1,sender_name.." successfully STOPPED THE MATCH; if this player is abusing this ability, contact an admin or moderator. Type /support for assistance!")
			end
		elseif gameState.gameRunning then -- if autostart OFF and game is running
			gameEnd("manual")
			MP.SendChatMessage(-1,sender_name.." successfully STOPPED THE MATCH; if this player is abusing this ability, contact an admin or moderator. Type /support for assistance!")
		elseif not gameState.gameRunning then -- if autostart OFF and game is NOT running
			MP.SendChatMessage(sender_id,"Error: stop failed, game not running and autostart is OFF. (Error 10a.)")
		else -- ?????
			MP.SendChatMessage(sender_id,"Error: unknown error. (Error 10b.)")
		end

		return 1
		
	elseif string.find(message,"/"..varWakeWord.." length %d+") then
		local value = tonumber(string.sub(message,1 + string.len(varWakeWord) + 9,10000))
		
		if value then
			varRoundLength = value*60
			MP.SendChatMessage(-1,sender_name.." successfully set game length to "..value.." minutes.")
		else
			MP.SendChatMessage(sender_id,"Error: setting varRoundLength failed, no valid value found. (Error 11.)")
		end
		
		return 1

	elseif string.find(message,"/"..varWakeWord.." announcer") then
		local value = string.sub(message,1 + string.len(varWakeWord) + 12,10000)
		
		if value == "midnight" then
			varAnnouncerEnabled = true
			varAnnouncerType = value
			MP.SendChatMessage(-1,sender_name.." successfully set the announcer to '"..value.."' and set the announcer to ON.")
		elseif value == "robot" then
			varAnnouncerEnabled = true
			varAnnouncerType = value
			MP.SendChatMessage(-1,sender_name.." successfully set the announcer to '"..value.."' and set the announcer to ON.")
		elseif value == "off" then
			varAnnouncerEnabled = false
			varAnnouncerType = value
			MP.SendChatMessage(-1,sender_name.." successfully set the announcer to OFF.")
		else
			MP.SendChatMessage(sender_id,"Error: invalid entry, please try again. (Error 12; entry was: '"..value.."'. Valid entries are: midnight, robot, off.)")
		end
				
		return

    elseif string.find(message,"/"..varWakeWord.." infectedNearbyDistance %d+") then
		local value = tonumber(string.sub(message,1 + string.len(varWakeWord) + 25,10000))
		
		if value then
			varInfectedNearbyDistance = value
			if gameState.settings then
				gameState.settings.GreenFadeDistance = varInfectedNearbyDistance
			end
			MP.SendChatMessage(-1,sender_name.." successfully set infectedNearbyDistance to "..value..".")
		else
			MP.SendChatMessage(sender_id,"Error: setting infectedNearbyDistance failed, no valid value found. (Error 13.)")
		end
		
		return 1

    elseif message == "/"..varWakeWord.." infectedPulsingColor" then
		if varInfectedPulsingColor then
			varInfectedPulsingColor = false
			MP.SendChatMessage(-1,sender_name.." successfully setting infectedPulsingColor to false/off.")
		else
			varInfectedPulsingColor = true
			MP.SendChatMessage(-1,sender_name.." successfully setting infectedPulsingColor to true/on. NOTE: infectedTintedScreen MUST be set to true/on, otherwise infectedPulsingColor will cause a game crash! It is FALSE/OFF by default!")
		end
		
		if gameState.settings then
			gameState.settings.ColorPulse = varInfectedPulsingColor
		end
		
		return 1

    elseif message == "/"..varWakeWord.." infectedTintedScreen" then
		if varInfectedTintedScreen then
			varInfectedTintedScreen = false
			MP.SendChatMessage(-1,sender_name.." successfully set infectedTintedScreen to false/off.")
		else
			varInfectedTintedScreen = true
			MP.SendChatMessage(-1,sender_name.." successfully set infectedTintedScreen to true/on.")
		end
		
		if gameState.settings then
			gameState.settings.infectorTint = varInfectedTintedScreen
		end
		
		return 1

    elseif string.find(message,"/"..varWakeWord.." infectedTintIntensity %d+") then
		local value = tonumber(string.sub(message,1 + string.len(varWakeWord) + 25,10000))
		
		if value then
			varInfectedTintIntensity = value
			if gameState.settings then
				gameState.settings.distancecolor = varInfectedTintIntensity
			end
			MP.SendChatMessage(-1,sender_name.." successfully set infectedTintIntensity to "..value..".")	
		else
			MP.SendChatMessage(sender_id,"Error: setting infectedTintIntensity failed, no valid value found. (Error 14. Entry was: '"..value.."'.")
		end
		
		return 1

    elseif message == "/"..varWakeWord.." reset" then
		varWeightingArray = {}
		MP.SendChatMessage(-1,sender_name.." reset the weighted random system.")
		
		varAnnouncerEnabled = true
		varAnnouncerType = varAnnouncerTypeDefault
		MP.SendChatMessage(-1,sender_name.." reset the announcer to 'midnight' and set the announcer to ON.")
		
		varAutoStartDelay = 90 -- what the delay between autostartted rounds should be
		varAutoStartEnabled = false -- if the game automatically starts every varAutoStartDelay sectonds
		varInfectedNearbyDistance = 250 -- how close the infected player(s) have to be for the screen to start turning green; in meters
		varInfectedTintIntensity = 0.5 -- max intensity of the green filter; 0.00 to 1.00
		varInfectedPulsingColor = false -- if the infected player(s) car(s) should pulse between the car's original color and green
		varInfectedTintedScreen = false -- if infected player(s) should have a green tint applied to their scrfeen
		-- varMaxNumberOfStartingZombies = 1 -- set the max number of infected at the beginning of each round
		varNotifyDuringMatch = true -- if the chat box should be used as a deterrent for car spawns or edits during a match (also see below)
		varRoundLength = 10*60 -- lenght of the game, in seconds (minutes*seconds, so default is 10 minutes)
		varStartingSeconds = 10 -- the number of seconds before the initial player is revealed as infected
		
		MP.SendChatMessage(-1,sender_name.." reset all other configurable in-game settings.")

		return 1
	
	elseif message == "/support" then -- show the support text
		MP.SendChatMessage(sender_id,varSupportMessage)
		return 1
	
	elseif message == "/"..varWakeWord.." credits" then
		MP.SendChatMessage(sender_id,"BeamMP Infected (ToW), version "..varDateEdited..".")
		MP.SendChatMessage(sender_id,"Original code by: Olrosse, Stefan750, and Saile; https://github.com/Olrosse/BeamMP-Outbreak")
		MP.SendChatMessage(sender_id,"Code improvements, clarity, cleanup, and additional features by wreckedcarzz (https://wreckedcarzz.com) for the Talons of War clan (https://TalonsOfWar.com) BeamMP servers.")
		
		return 1
		
    elseif message == "/"..varWakeWord.." help" then
		MP.SendChatMessage(sender_id,"Basic settings:")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." start")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." stop")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." autostart")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." autostart delay [seconds]")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." length [minutes]")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." announcer [options are: 'midnight' (default), 'robot', and 'off']")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." quiet [minutes] (how many minutes to quiet the reminder about how to play)")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." reset (resets the infection randomizer, and any adjusted settings)")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." credits")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." advancedSettings")
	elseif message == "/"..varWakeWord.." advancedSettings" then
		MP.SendChatMessage(sender_id,"Advanced settings:")
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." infectedNearbyDistance [meters] (default: "..varInfectedNearbyDistance.."; at what distance does the screen begin to tint for non-infected players near an infected player)")
		if varInfectedPulsingColor then
			MP.SendChatMessage(sender_id,"/"..varWakeWord.." infectedPulsingColor (default: true; do infected cars 'pulse' green? NOTE: infectedTintedScreen MUST be set to true/on, otherwise infectedPulsingColor will cause a game crash! It is FALSE/OFF by default!")
		elseif not varInfectedPulsingColor then
			MP.SendChatMessage(sender_id,"/"..varWakeWord.." infectedPulsingColor (default: false; do infected cars 'pulse' green? NOTE: infectedTintedScreen MUST be set to true/on, otherwise infectedPulsingColor will cause a game crash! It is FALSE/OFF by default!")
		end
		
		if varInfectedTintedScreen then
			MP.SendChatMessage(sender_id,"/"..varWakeWord.." infectedTintedScreen (default: true; if infected players have a green tint applied to their screen)")
		elseif not varInfectedTintedScreen then
			MP.SendChatMessage(sender_id,"/"..varWakeWord.." infectedTintedScreen (default: false; if infected players have a green tint applied to their screen)")
		end
		
		MP.SendChatMessage(sender_id,"/"..varWakeWord.." infectedTintIntensity [0.00 to 1.00] (default: "..varInfectedTintIntensity.."; sets the intensity of the green tint)")
		--MP.SendChatMessage(sender_id,"/"..varWakeWord.." maxStartingZombies [maximum]")
		MP.SendChatMessage(sender_id,"Settings do NOT save, but are reset every server restart. To have settings kept, edit the setting in /resources/server/outbreak/main.lua")
	
		return 1
    else
        return 0
	end
end

function onPlayerDisconnect(playerID)
	local varPlayerName = MP.GetPlayerName(playerID)
	if gameState.gameRunning then
		MP.SendChatMessage(-1, varPlayerName.." quit during a match.")
	end
	if gameState.gameRunning and gameState.players and gameState.players[varPlayerName] then
		gameState.players[varPlayerName] = "remove"
	end
end

--[[
function onVehicleSpawn(ID, vehID, data)
	local varPlayerName = MP.GetPlayerName(playerID)
	if gameState.gameRunning then
		--MP.TriggerGlobalEvent("onVehicleDeleted", ID, vehID)
		RemoveVehicle(ID, vehID)		
		--MP.SendChatMessage(sender_id,"You cannot spawn a car during a zombie infection match!")
		MP.SendChatMessage(-1,varPlayerName.." tried to spawn a vehicle during a zombie infection match!")
	end
end

function onVehicleEdited(ID, vehID, data)
	local varPlayerName = MP.GetPlayerName(playerID)
	if gameState.gameRunning then
		MP.TriggerGlobalEvent("onVehicleDeleted", ID, vehID)
		--MP.SendChatMessage(sender_id,"You cannot spawn a car during a zombie infection match!")
		MP.SendChatMessage(-1,varPlayerName.." tried to edit their vehicle during a zombie infection match!")
	end
end
]]

function onVehicleDeleted(playerID,vehicleID)
	local varPlayerName = MP.GetPlayerName(playerID)
	if gameState.gameRunning then
		MP.SendChatMessage(-1, varPlayerName.." deleted a vehicle.")
		
	end
	if gameState.gameRunning and gameState.players and gameState.players[varPlayerName] then
		if not MP.GetPlayerVehicles(playerID) then
			gameState.players[varPlayerName] = "remove"
		end
	end
end

MP.TriggerClientEventJson(-1, "recieveGameState", gameState)
MP.TriggerClientEvent(-1, "resetInfected", "data")

MP.RegisterEvent("onChatMessage", "outbreakChatMessageHandler")
MP.RegisterEvent("onPlayerDisconnect", "onPlayerDisconnect")
--MP.RegisterEvent("onVehicleSpawn","onVehicleSpawn")
--MP.RegisterEvent("onVehicleEdited","onVehicleEdited")
MP.RegisterEvent("onVehicleDeleted", "onVehicleDeleted")
MP.RegisterEvent("onPlayerJoin", "requestGameState")
MP.RegisterEvent("onPlayerConnecting", "onPlayerConnecting")
