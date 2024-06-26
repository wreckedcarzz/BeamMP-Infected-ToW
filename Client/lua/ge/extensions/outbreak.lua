-- improvements and adjustments to work alongside the server-side changes, by wreckedcarzz (https://wreckedcarzz.com)



--- settings ---
local varWakeWord = "infected" -- customizable word for text commands ( /varWakeWord <action> ) 

local varNotifyRepairRespawn = "Repairing: ALL players must come to a COMPLETE STOP before repairing (Insert); non-infected must NOT be near a zombie (have a green-tinted screen) to repair" -- explaining rules regarding repairing
local varNotifySpawnEditText = "Spawning/editing: Do NOT spawn or edit vehicles during the match" -- text used to deter players from making any new 'events' that will desync players and break the game, causing affected players to rejoin the server

local varNotifyStop = 'You can stop a live match by typing "/'..varWakeWord..' stop"' -- message shown at the end of 
local varNotifyStopAuto = 'You can disable autostart (and stop a live match) by typing "/'..varWakeWord..' stop"' -- autostart variant of above
local varNotifyQuickStart = 'You can start a [BETA] zombie match quickly by typing "/'..varWakeWord..' autostart", or see the settings by typing "/'..varWakeWord..' help".'

local varServerOwner = "CHANGE_ME"
local varServerAdmin1 = ""
local varServerAdmin2 = ""
local varServerAdmin3 = ""
local varServerMod1 = ""
local varServerMod2 = ""
local varServerMod3 = ""
--- end settings ---



--[[
DONE reverted, redid changes to original
DONE added nametag colors for teams
TEST cleanup of variables, renaming
TEST nametags for admins
]]



--- non-setting variables ---
local M = {}
--local floor = math.floor
--local mod = math.fmod
local varDefaultGreenFadeDistance = 20
local varDistanceColor = -1
local varGameState = {players = {}, settings = {}}
--- end variables ---



--extensions.unload("outbreak")
--extensions.load("outbreak")

--local actionTemplate = core_input_actionFilter.getActionTemplates()

--core_input_actionFilter.setGroup('competitive', actionTemplate.vehicleTeleporting)

local blockedActions = core_input_actionFilter.createActionTemplate({"vehicleTeleporting", "vehicleMenues", "physicsControls", "aiControls", "vehicleSwitching", "funStuff"})

local function secondsToDaysHoursMinutesSeconds(total_seconds) --modified code from https://stackoverflow.com/questions/45364628/lua-4-script-to-convert-seconds-elapsed-to-days-hours-minutes-seconds
    local time_minutes  = math.floor(math.fmod(total_seconds, 3600) / 60)
    local time_seconds  = math.floor(math.fmod(total_seconds, 60))
    --[[
	if (time_minutes < 10) then
        time_minutes = "0" .. time_minutes
    end
	]]
    if (time_seconds < 10) and time_minutes > 0 then
        time_seconds = "0" .. time_seconds
    end
	if time_minutes > 0 then
    	return time_minutes .. ":" .. time_seconds
	else
    	return time_seconds
	end
end

local function distance(vec1, vec2)
	return math.sqrt((vec2.x-vec1.x)^2 + (vec2.y-vec1.y)^2 + (vec2.z-vec1.z)^2)
end

local function resetInfected(data)
	for k,serverVehicle in pairs(MPVehicleGE.getVehicles()) do
		local ID = serverVehicle.gameVehicleID
		local vehicle = be:getObjectByID(ID)
		if vehicle then
			if serverVehicle.originalColor then
				vehicle.color = serverVehicle.originalColor
			end
			if serverVehicle.originalcolorPalette0 then
				vehicle.colorPalette0 = serverVehicle.originalcolorPalette0
			end
			if serverVehicle.originalcolorPalette1 then
				vehicle.colorPalette1 = serverVehicle.originalcolorPalette1
			end
		end
	end

	MPVehicleGE.hideNicknames(false)
	scenetree["PostEffectCombinePassObject"]:setField("enableBlueShift", 0,0)
	scenetree["PostEffectCombinePassObject"]:setField("blueShiftColor", 0,"0 0 0")

	--[[
	core_input_actionFilter.addAction(0, 'vehicleTeleporting', false)
	core_input_actionFilter.addAction(0, 'vehicleMenues', false)
	core_input_actionFilter.addAction(0, 'freeCam', false)
	core_input_actionFilter.addAction(0, 'resetPhysics', false)
	]]
end

local function recieveGameState(data)
	local data = jsonDecode(data)

	if not varGameState.gameRunning and data.gameRunning then
		for k,vehicle in pairs(MPVehicleGE.getVehicles()) do
			local ID = vehicle.gameVehicleID
			local veh = be:getObjectByID(ID)
			if veh then
				vehicle.originalColor = be:getObjectByID(ID).color
				vehicle.originalcolorPalette0 = be:getObjectByID(ID).colorPalette0
				vehicle.originalcolorPalette1 = be:getObjectByID(ID).colorPalette1
			end
		end
	end
	varGameState = data
	be:queueAllObjectLua("if outbreak then outbreak.setGameState("..serialize(varGameState)..") end")
end

local function mergeTable(table,gamestateTable)
	for variableName,value in pairs(table) do
		if type(value) == "table" then
			mergeTable(value,gamestateTable[variableName])
		elseif value == "remove" then
			gamestateTable[variableName] = nil
		else
			gamestateTable[variableName] = value
		end
	end
end

local function updateGameState(data)
	mergeTable(jsonDecode(data),varGameState)

	-- In game messages
	local time = 0

	if varGameState.time then time = varGameState.time-1 end

	local txt1stLine = ""
	local txt2ndLine = "RULES:"
	
	if varGameState.gameRunning and time and time == 0 then
		MPVehicleGE.hideNicknames(true)

		--[[
		if varGameState.settings and varGameState.settings.mode = "competitive" then
	    	core_input_actionFilter.setGroup('vehicleTeleporting', actionTemplate.vehicleTeleporting)
			core_input_actionFilter.addAction(0, 'vehicleTeleporting', true)

	    	core_input_actionFilter.setGroup('vehicleMenues', actionTemplate.vehicleMenues)
			core_input_actionFilter.addAction(0, 'vehicleMenues', true)

	    	core_input_actionFilter.setGroup('freeCam', actionTemplate.freeCam)
			core_input_actionFilter.addAction(0, 'freeCam', true)

	    	core_input_actionFilter.setGroup('resetPhysics', actionTemplate.resetPhysics)
			core_input_actionFilter.addAction(0, 'resetPhysics', true)
		end
		]]
	end

	if time and time < 0 then
		txt1stLine = "Game starts in "..math.abs(time).." seconds..."
	elseif varGameState.gameRunning and not varGameState.gameEnding and time or varGameState.endtime and (varGameState.endtime - time) > 9 then
		local timeLeft = secondsToDaysHoursMinutesSeconds(varGameState.varRoundLength - time)
		txt1stLine = "Infected: "..varGameState.InfectedPlayers.."/"..varGameState.playerCount..", Time Left "..timeLeft..""
	elseif time and varGameState.endtime and (varGameState.endtime - time) < 7 then
		local timeLeft = varGameState.endtime - time
		txt1stLine = "Infected: "..varGameState.InfectedPlayers.."/"..varGameState.playerCount.."; colors reset in "..math.abs(timeLeft-1).." seconds"
	end
	
	if txt1stLine ~= "" then
		guihooks.message(txt1stLine, 1, "outbreak.time", poi_checkmark_rect)
		guihooks.message(txt2ndLine, 1, "outbreak.rules", poi_exclamationmark_rect)
		guihooks.message(varNotifyRepairRespawn, 1, "outbreak.rule1", poi_garage_3_rect)
		guihooks.message(varNotifySpawnEditText, 1, "outbreak.rule2", poi_dealer_1_rect)
	--[[else --if txt1stLine == "" then
		guihooks.message(varNotifyQuickStart, 1, "outbreak.teach1", poi_checkmark_rect)
		guihooks.message(varNotifyStopAuto, 1, "outbreak.teach2", poi_checkmark_rect)
	]]
	end
	
	if varGameState.gameEnded then
		resetInfected()
	end
end

local function requestGameState()
	if TriggerServerEvent then
		TriggerServerEvent("requestGameState","nil")
	end
end

local function sendContact(vehID,localVehID)
	if not MPVehicleGE or MPCoreNetwork and not MPCoreNetwork.isMPSession() then
		return
	end
	
	local LocalvehPlayerName = MPVehicleGE.getNicknameMap()[localVehID]
	local vehPlayerName = MPVehicleGE.getNicknameMap()[vehID]
	
	if varGameState.players[vehPlayerName] and varGameState.players[LocalvehPlayerName] then
		if varGameState.players[vehPlayerName].infected ~= varGameState.players[LocalvehPlayerName].infected then
    		local serverVehID = MPVehicleGE.getServerVehicleID(vehID)
			local remotePlayerID, vehicleID = string.match(serverVehID, "(%d+)-(%d+)")
			if TriggerServerEvent then
				TriggerServerEvent("onContact", remotePlayerID)
			end
		end
	end
end

local function recieveInfected(data)
	local playerName = data
	local playerServerName = MPConfig:getNickname()
	if playerName == playerServerName then
		MPVehicleGE.hideNicknames(false)
	end
end

local function onVehicleSwitched(oldID,ID)
	local curentOwnerName = MPConfig.getNickname()
	if ID and MPVehicleGE.getVehicleByGameID(ID) then
		curentOwnerName = MPVehicleGE.getVehicleByGameID(ID).ownerName
	end

	if varGameState.players and varGameState.players[curentOwnerName] and varGameState.players[curentOwnerName].infected then
		MPVehicleGE.hideNicknames(false)
	elseif varGameState.players and varGameState.players[curentOwnerName] and not varGameState.players[curentOwnerName].infected then
		MPVehicleGE.hideNicknames(true)
	end
end

local function nametags(curentOwnerName,player,vehicle)
	-- show red Survivor tag to Zombies players in Infected mode
	if varGameState.players[curentOwnerName] and varGameState.players[curentOwnerName].infected and not player.infected and curentOwnerName ~= vehicle.ownerName then
		local varVeh = be:getObjectByID(vehicle.gameVehicleID)
		if varVeh then
			local varVehPos = varVeh:getPosition()
			local varPositionOffset = vec3(0,0,2)
			debugDrawer:drawTextAdvanced(varVehPos+varPositionOffset, String(" Survivor - enemy "), ColorF(1,1,1,1), true, false, ColorI(200,50,50,255))
		end
	end
	
	-- show purple Survivor tag to Survivors during Survival mode
	if varGameState.players[curentOwnerName] and not varGameState.players[curentOwnerName].infected and not player.infected and curentOwnerName ~= vehicle.ownerName then
		local varVeh = be:getObjectByID(vehicle.gameVehicleID)
		if varVeh then
			local varVehPos = varVeh:getPosition()
			local varPositionOffset = vec3(0,0,2)
			debugDrawer:drawTextAdvanced(varVehPos+varPositionOffset, String(" Survivor - teammate "), ColorF(1,1,1,1), true, false, ColorI(200,50,200,255))
		end
	end
	
	-- show Zombie tag to Zombies
	if varGameState.players[curentOwnerName] and varGameState.players[curentOwnerName].infected and player.infected and curentOwnerName ~= vehicle.ownerName then
		local varVeh = be:getObjectByID(vehicle.gameVehicleID)
		if varVeh then
			local varVehPos = varVeh:getPosition()
			local varPositionOffset = vec3(0,0,2)
			debugDrawer:drawTextAdvanced(varVehPos+varPositionOffset, String(" Zombie - teammate "), ColorF(1,1,1,1), true, false, ColorI(0,175,0,255))
		end
	end
	
	--[[
	-- show yellow Infected tag to Survivors -- and Zombies during Survival mode
	if varGameState.players[curentOwnerName] and not varGameState.players[curentOwnerName].infected and not player.infected and curentOwnerName ~= vehicle.ownerName then
		local varVeh = be:getObjectByID(vehicle.gameVehicleID)
		if varVeh then
			local varVehPos = varVeh:getPosition()
			local varPositionOffset = vec3(0,0,2)
			debugDrawer:drawTextAdvanced(varVehPos+varPositionOffset, String(" Infected - teammate "), ColorF(1,1,1,1), true, false, ColorI(200,50,50,255))
		end
	end
	]]
end

local function nametagsAdmins(curentOwnerName,player,vehicle)
	-- show blue Server Owner / Admin / Mod tag to all players when not in match	
	if not varGameState.gameRunning then
		if curentOwnerName == varServerOwner or curentOwnerName == varServerAdmin1 or curentOwnerName == varServerAdmin2 or curentOwnerName == varServerAdmin3 or curentOwnerName == varServerMod1 or curentOwnerName == varServerMod2 or curentOwnerName == varServerMod3 then
			local tempBlueTagText = ""
			
			if curentOwnerName == varServerOwner then
				tempBlueTagText = " Server Owner "
			elseif curentOwnerName == varServerAdmin1 then
				tempBlueTagText = " Server Admin "
			elseif curentOwnerName == varServerAdmin2 then
				tempBlueTagText = " Server Admin "
			elseif curentOwnerName == varServerAdmin3 then
				tempBlueTagText = " Server Admin "
			elseif curentOwnerName == varServerMod1 then
				tempBlueTagText = " Server Mod "
			elseif curentOwnerName == varServerMod2 then
				tempBlueTagText = " Server Mod "
			elseif curentOwnerName == varServerMod3 then
				tempBlueTagText = " Server Mod "
			end
			
			local varVeh = be:getObjectByID(vehicle.gameVehicleID)
			
			if varVeh then
				local varVehPos = varVeh:getPosition()
				local varPositionOffset = vec3(0,0,2)
				debugDrawer:drawTextAdvanced(varVehPos+varPositionOffset, String(tempBlueTagText), ColorF(1,1,1,1), true, false, ColorI(72,0,255,255))
			end
		end
	end
end

local function color(player,vehicle,dt)
	if player.infected then
		if not vehicle.transition or not vehicle.colortimer then
			vehicle.transition = 1
			vehicle.colortimer = 1.6
		end
		
		local veh = be:getObjectByID(vehicle.gameVehicleID)
		
		if veh then
			if not vehicle.originalColor then
				vehicle.originalColor = veh.color
			end

			if not vehicle.originalcolorPalette0 then
				vehicle.originalcolorPalette0 = veh.colorPalette0
			end

			if not vehicle.originalcolorPalette1 then
				vehicle.originalcolorPalette1 = veh.colorPalette1
			end

			if not varGameState.gameEnding or (varGameState.endtime - varGameState.time) > 1 then
				local transition = vehicle.transition
				local colortimer = vehicle.colortimer
				local color = 0.6 - (1*((1+math.sin(colortimer))/2)*0.2)
				local colorfade = (1*((1+math.sin(colortimer))/2))*math.max(0.6,transition)
				local greenfade = 1 -((1*((1+math.sin(colortimer))/2))*(math.max(0.6,transition)))

				if varGameState.settings and not varGameState.settings.ColorPulse then
					color = 0.6
					colorfade = transition
					greenfade = 1 - transition
				end
		
				veh.color = ColorF(vehicle.originalColor.x*colorfade,(vehicle.originalColor.y*colorfade) + (color*greenfade), vehicle.originalColor.z*colorfade, vehicle.originalColor.w):asLinear4F()
				veh.colorPalette0 = ColorF(vehicle.originalcolorPalette0.x*colorfade,(vehicle.originalcolorPalette0.y*colorfade) + (color*greenfade), vehicle.originalcolorPalette0.z*colorfade, vehicle.originalcolorPalette0.w):asLinear4F()
				veh.colorPalette1 = ColorF(vehicle.originalcolorPalette1.x*colorfade,(vehicle.originalcolorPalette1.y*colorfade) + (color*greenfade), vehicle.originalcolorPalette1.z*colorfade, vehicle.originalcolorPalette1.w):asLinear4F()
			
				vehicle.colortimer = colortimer + (dt*2.6)

				if transition > 0 then
					vehicle.transition = math.max(0,transition - dt)
				end

				vehicle.color = color
				vehicle.colorfade = colorfade
				vehicle.greenfade = greenfade
			elseif (varGameState.endtime - varGameState.time) <= 1 then
				local transition = vehicle.transition
				local color = vehicle.color or 0
				local colorfade = vehicle.colorfade or 1
				local greenfade = vehicle.greenfade or 0
				veh.color = ColorF(vehicle.originalColor.x*colorfade,(vehicle.originalColor.y*colorfade) + (color*greenfade), vehicle.originalColor.z*colorfade, vehicle.originalColor.w):asLinear4F()
				veh.colorPalette0 = ColorF(vehicle.originalcolorPalette0.x*colorfade,(vehicle.originalcolorPalette0.y*colorfade) + (color*greenfade), vehicle.originalcolorPalette0.z*colorfade, vehicle.originalcolorPalette0.w):asLinear4F()
				veh.colorPalette1 = ColorF(vehicle.originalcolorPalette1.x*colorfade,(vehicle.originalcolorPalette1.y*colorfade) + (color*greenfade), vehicle.originalcolorPalette1.z*colorfade, vehicle.originalcolorPalette1.w):asLinear4F()
				vehicle.colorfade = math.min(1,colorfade + dt)
				vehicle.greenfade = math.max(0,greenfade - dt)
				vehicle.colortimer = 1.6

				if transition < 1 then
					vehicle.transition = math.min(1,transition + dt)
				end
			end
		end
	end
end

--[[ new broken version
local function onPreRender(dt)
	if MPCoreNetwork and not MPCoreNetwork.isMPSession() then -- if the player isn't online
		return
	end
	
	if not varGameState.gameRunning then -- if the zombie mode isn't active
		local currentVehID = be:getPlayerVehicleID(0)
		local curentOwnerName = MPConfig.getNickname()

		
		--if currentVehID and MPVehicleGE.getVehicleByGameID(currentVehID) then
		--	curentOwnerName = MPVehicleGE.getVehicleByGameID(currentVehID).ownerName
		--end
		

		for k,vehicle in pairs(MPVehicleGE.getVehicles()) do
			--if varGameState.players then
				local player = varGameState.players[vehicle.ownerName]
				--if player then
					--if not varGameState.gameRunning then
						nametagsAdmins(curentOwnerName,player,vehicle) -- run the nametagsAdmins function
					--end
				--end
			--end
		end
	return -- halt processing the rest of this function
	end
	
	local currentVehID = be:getPlayerVehicleID(0)
	local curentOwnerName = MPConfig.getNickname()

	if currentVehID and MPVehicleGE.getVehicleByGameID(currentVehID) then
		curentOwnerName = MPVehicleGE.getVehicleByGameID(currentVehID).ownerName
	end

	local closestInfected = 100000000
	
	for k,vehicle in pairs(MPVehicleGE.getVehicles()) do
		if varGameState.players then
			local player = varGameState.players[vehicle.ownerName]
			if player then
				nametags(curentOwnerName,player,vehicle)
				color(player,vehicle,dt)
			end
		
			if varGameState.players[curentOwnerName] and currentVehID and not varGameState.players[curentOwnerName].infected and varGameState.players[vehicle.ownerName].infected and currentVehID ~= vehicle.gameVehicleID then
				local myVeh = be:getObjectByID(currentVehID)
				local veh = be:getObjectByID(vehicle.gameVehicleID)
				if veh and myVeh then
					if varGameState.players[vehicle.ownerName].infected then
						local distance = distance(myVeh:getPosition(),veh:getPosition())
						if distance < closestInfected then
							closestInfected = distance
						end
					end
				end
			end
		end
	end

	local tempSetting = varDefaultGreenFadeDistance
	
	if varGameState.settings then
		tempSetting = varGameState.settings.GreenFadeDistance
	end
	
	varDistanceColor = math.min(0.4,1 - (closestInfected/(tempSetting or varDefaultGreenFadeDistance)))
	]]
	
	--[[ this stays commented out
	if varDistanceColor > 0 then
		core_input_actionFilter.setGroup('vehicleTeleporting', actionTemplate.vehicleTeleporting)
		core_input_actionFilter.addAction(0, 'vehicleTeleporting', true)

		core_input_actionFilter.setGroup('resetPhysics', actionTemplate.resetPhysics)
		core_input_actionFilter.addAction(0, 'resetPhysics', true)
	else
		core_input_actionFilter.addAction(0, 'vehicleTeleporting', false)
		core_input_actionFilter.addAction(0, 'resetPhysics', false)
	end
	]]
	
	--[[
	if varGameState.settings and varGameState.settings.infectorTint and varGameState.players[curentOwnerName] and varGameState.players[curentOwnerName].infected then
		varDistanceColor = varGameState.settings.varDistanceColor or 0.5
	end

	scenetree["PostEffectCombinePassObject"]:setField("enableBlueShift", 0,varDistanceColor)
	scenetree["PostEffectCombinePassObject"]:setField("blueShiftColor", 0,"0 1 0")
end
]]

local function onPreRender(dt)
	if MPCoreNetwork and not MPCoreNetwork.isMPSession() then
		return
	end
	
	if not varGameState.gameRunning then
		return
	--[[
	elseif MPVehicleGE and varGameState.players[curentOwnerName] = "wreckedcarzz" or varGameState.players[curentOwnerName] = "FredTheFeline" or varGameState.players[curentOwnerName] = "NateGT90" then
		nametags()
		return
	]]
	end

	local currentVehID = be:getPlayerVehicleID(0)
	local curentOwnerName = MPConfig.getNickname()

	if currentVehID and MPVehicleGE.getVehicleByGameID(currentVehID) then
		curentOwnerName = MPVehicleGE.getVehicleByGameID(currentVehID).ownerName
	end

	local closestInfected = 100000000
	
	for k,vehicle in pairs(MPVehicleGE.getVehicles()) do
		if varGameState.players then
			local player = varGameState.players[vehicle.ownerName]
			if player then
				nametags(curentOwnerName,player,vehicle)
				color(player,vehicle,dt)
				if varGameState.players[curentOwnerName] and currentVehID and not varGameState.players[curentOwnerName].infected and varGameState.players[vehicle.ownerName].infected and currentVehID ~= vehicle.gameVehicleID then
					local myVeh = be:getObjectByID(currentVehID)
					local veh = be:getObjectByID(vehicle.gameVehicleID)
					if veh and myVeh then
						if varGameState.players[vehicle.ownerName].infected then
							local distance = distance(myVeh:getPosition(),veh:getPosition())
							if distance < closestInfected then
								closestInfected = distance
							end
						end
					end
				end
			end
		end
	end

	local tempSetting = varDefaultGreenFadeDistance
	
	if varGameState.settings then
		tempSetting = varGameState.settings.GreenFadeDistance
	end
	
	varDistanceColor = math.min(0.4,1 - (closestInfected/(tempSetting or varDefaultGreenFadeDistance)))

	--[[if varDistanceColor > 0 then
		core_input_actionFilter.setGroup('vehicleTeleporting', actionTemplate.vehicleTeleporting)
		core_input_actionFilter.addAction(0, 'vehicleTeleporting', true)

		core_input_actionFilter.setGroup('resetPhysics', actionTemplate.resetPhysics)
		core_input_actionFilter.addAction(0, 'resetPhysics', true)
	else
		core_input_actionFilter.addAction(0, 'vehicleTeleporting', false)
		core_input_actionFilter.addAction(0, 'resetPhysics', false)
	end
	]]
	
	if varGameState.settings and varGameState.settings.infectorTint and varGameState.players[curentOwnerName] and varGameState.players[curentOwnerName].infected then
		varDistanceColor = varGameState.settings.varDistanceColor or 0.5
	end

	scenetree["PostEffectCombinePassObject"]:setField("enableBlueShift", 0,varDistanceColor)
	scenetree["PostEffectCombinePassObject"]:setField("blueShiftColor", 0,"0 1 0")
end

local function onResetGameplay(id)
	--[[dump(varDistanceColor , be:getPlayerVehicleID(0) , id )
	if varDistanceColor > 0 and id == 0 then
		guihooks.message({txt1stLine = "Infector to close, cannot Reset"}, 1, "outbreak.reset")
	end
	]]
end

local function onExtensionUnloaded()
	resetInfected()
end

local function playAudio(varSoundMessage)
	if varSoundMessage == "playerInfected" then -- section for human voice
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/midnight/infected.ogg')
	elseif varSoundMessage == "replacementInfected" then
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/midnight/replacementInfected.ogg')
	elseif varSoundMessage == "gameOverWithSurvivors" then
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/midnight/gameOver.ogg')
	elseif varSoundMessage == "gameOverNoSurvivors" then
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/midnight/gameOverNoSurvivors.ogg')
	elseif varSoundMessage == "gameHalted" then
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/midnight/gameStopped.ogg')
	elseif varSoundMessage == "gameHaltedUnknownError" then
		--Engine.Audio.playOnce('AudioGui', '/sounds/announcer/midnight/'..varSoundMessage..'.ogg')
	elseif varSoundMessage == "infectedGameStart" then
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/midnight/matchStarting.ogg')
	elseif varSoundMessage == "remaining5minutes" then
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/midnight/fiveMinutesRemaining.ogg')
	elseif varSoundMessage == "remaining1minute" then
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/midnight/oneMinuteRemaining.ogg')
	elseif varSoundMessage == "remaining30seconds" then
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/midnight/thirtySecondsRemaining.ogg')
	elseif varSoundMessage == "robotPlayerInfected" then -- section for robot voice
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/robot/infected.ogg')
	elseif varSoundMessage == "robotReplacementInfected" then
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/robot/replacementInfected.ogg')
	elseif varSoundMessage == "robotGameOverWithSurvivors" then
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/robot/gameOver.ogg')
	elseif varSoundMessage == "robotGameOverNoSurvivors" then
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/robot/gameOverNoSurvivors.ogg')
	elseif varSoundMessage == "robotGameHalted" then
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/robot/gameStopped.ogg')
	elseif varSoundMessage == "robotGameHaltedUnknownError" then
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/robot/gameStoppedUnknownReason.ogg')
	elseif varSoundMessage == "robotInfectedGameStart" then
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/robot/matchStarting.ogg')
	elseif varSoundMessage == "robotRemaining5minutes" then
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/robot/fiveMinutesRemaining.ogg')
	elseif varSoundMessage == "robotRemaining1minute" then
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/robot/oneMinuteRemaining.ogg')
	elseif varSoundMessage == "robotRemaining30seconds" then
		Engine.Audio.playOnce('AudioGui', '/sounds/announcer/robot/thirtySecondsRemaining.ogg')
	else
		-- ??? this should never happen
	end
end

if MPGameNetwork then AddEventHandler("recieveInfected", recieveInfected) end
if MPGameNetwork then AddEventHandler("resetInfected", resetInfected) end
if MPGameNetwork then AddEventHandler("recieveGameState", recieveGameState) end
if MPGameNetwork then AddEventHandler("updateGameState", updateGameState) end
if MPGameNetwork then AddEventHandler("playAudio", playAudio) end

--requestGameState()

M.requestGameState = requestGameState
M.sendContact = sendContact
M.onPreRender = onPreRender
M.onVehicleSwitched = onVehicleSwitched
M.resetInfected = resetInfected
M.onExtensionUnloaded = onExtensionUnloaded
M.onResetGameplay = onResetGameplay
--M.varGameState = varGameState

return M
