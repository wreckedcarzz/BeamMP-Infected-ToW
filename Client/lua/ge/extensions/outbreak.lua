--slight adjustments to work with the server-side changes, plus variable name changes for more code readability, by wreckedcarzz (https://wreckedcarzz.com)

local M = {}

local varFloor = math.floor
local varMod = math.fmod
local varGameState = {players = {}, settings = {}}
local varDefaultGreenFadeDistance = 20
local varDistancecolor = -1


--[[extensions.unload("outbreak") extensions.load("outbreak")

local actionTemplate = core_input_actionFilter.getActionTemplates()

core_input_actionFilter.setGroup('competitive', actionTemplate.vehicleTeleporting)

local blockedActions = core_input_actionFilter.createActionTemplate({"vehicleTeleporting", "vehicleMenues", "physicsControls", "aiControls", "vehicleSwitching", "funStuff"})

dump(blockedActions,"teste")]]

local function secondsToDaysHoursMinutesSeconds(totalSeconds) --modified code from https://stackoverflow.com/questions/45364628/lua-4-script-to-convert-seconds-elapsed-to-days-hours-minutes-seconds
    local varMinutes  = varFloor(varMod(total_seconds, 3600) / 60)
    local varSeconds  = varFloor(varMod(total_seconds, 60))
    --if (varMinutes < 10) then
    --    varMinutes = "0" .. varMinutes
    --end
    if (varSeconds < 10) and varMinutes > 0 then
        varSeconds = "0" .. varSeconds
    end
	if varMinutes > 0 then
    	return varMinutes .. ":" .. varSeconds
	else
    	return varSeconds
	end
end

local function distance(vec1, vec2)
	return math.sqrt((vec2.x-vec1.x)^2 + (vec2.y-vec1.y)^2 + (vec2.z-vec1.z)^2)
end

local function resetInfected(data)
	for k,serverVehicle in pairs(MPVehicleGE.getVehicles()) do
		local varID = serverVehicle.gameVehicleID
		local varVehicle = be:getObjectByID(varID)
		if varVehicle then
			if serverVehicle.originalColor then
				varVehicle.color = serverVehicle.originalColor
			end
			if serverVehicle.originalcolorPalette0 then
				varVehicle.colorPalette0 = serverVehicle.originalcolorPalette0
			end
			if serverVehicle.originalcolorPalette1 then
				varVehicle.colorPalette1 = serverVehicle.originalcolorPalette1
			end
		end
	end

	MPVehicleGE.hideNicknames(false)
	scenetree["PostEffectCombinePassObject"]:setField("enableBlueShift", 0,0)
	scenetree["PostEffectCombinePassObject"]:setField("blueShiftColor", 0,"0 0 0")

	--core_input_actionFilter.addAction(0, 'vehicleTeleporting', false)
	--core_input_actionFilter.addAction(0, 'vehicleMenues', false)
	--core_input_actionFilter.addAction(0, 'freeCam', false)
	--core_input_actionFilter.addAction(0, 'resetPhysics', false)
end

local function recieveGameState(data)
	local varData = jsonDecode(data)

	if not varGameState.gameRunning and varData.gameRunning then
		for k,vehicle in pairs(MPVehicleGE.getVehicles()) do
			local varID = vehicle.gameVehicleID
			local varVeh = be:getObjectByID(ID)
			if varVeh then
				vehicle.originalColor = be:getObjectByID(varID).color
				vehicle.originalcolorPalette0 = be:getObjectByID(varID).colorPalette0
				vehicle.originalcolorPalette1 = be:getObjectByID(varID).colorPalette1
			end
		end
	end
	varGameState = varData
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
	local varTime = 0

	if varGameState.time then varTime = varGameState.time-1 end

	local varTxt = ""

	if varGameState.gameRunning and varTime and varTime == 0 then
		MPVehicleGE.hideNicknames(true)

		-- this was disabled in original code
		--[[if varGameState.settings and varGameState.settings.mode = "competitive" then
	    	core_input_actionFilter.setGroup('vehicleTeleporting', actionTemplate.vehicleTeleporting)
			core_input_actionFilter.addAction(0, 'vehicleTeleporting', true)

	    	core_input_actionFilter.setGroup('vehicleMenues', actionTemplate.vehicleMenues)
			core_input_actionFilter.addAction(0, 'vehicleMenues', true)

	    	core_input_actionFilter.setGroup('freeCam', actionTemplate.freeCam)
			core_input_actionFilter.addAction(0, 'freeCam', true)

	    	core_input_actionFilter.setGroup('resetPhysics', actionTemplate.resetPhysics)
			core_input_actionFilter.addAction(0, 'resetPhysics', true)
		end]]
	end

	if varTime and varTime < 0 then
		varTxt = "Game starts in "..math.abs(varTime).." seconds..."
	elseif varGameState.gameRunning and not varGameState.gameEnding and varTime or varGameState.endtime and (varGameState.endtime - varTime) > 9 then
		
		-- disabled in original code
		--local InfectedPlayers = varGameState.InfectedPlayers
		--local nonInfectedPlayers = varGameState.nonInfectedPlayers

		local varTimeLeft = secondsToDaysHoursMinutesSeconds(varGameState.varRoundLength - varTime)
		varTxt = "Infected: "..varGameState.InfectedPlayers.."/"..varGameState.playerCount..", Time Left "..varTimeLeft..""
	elseif varTime and varGameState.endtime and (varGameState.endtime - varTime) < 7 then

		-- disabled in original code
		--local InfectedPlayers = varGameState.InfectedPlayers
		--local nonInfectedPlayers = varGameState.nonInfectedPlayers

		local varTimeLeft = varGameState.endtime - varTime
		varTxt = "Infected: "..varGameState.InfectedPlayers.."/"..varGameState.playerCount..", Colors reset in "..math.abs(varTimeLeft-1).." seconds..."

	end
	if varTxt ~= "" then
		guihooks.message({varTxt = varTxt}, 1, "outbreak.time")
	end
	--\n
	if varGameState.gameEnded then
		resetInfected()
	end
end

local function requestGameState()
	if TriggerServerEvent then TriggerServerEvent("requestGameState","nil") end
end

local function sendContact(vehID,localVehID)
	if not MPVehicleGE or MPCoreNetwork and not MPCoreNetwork.isMPSession() then return end
	local varLocalVehPlayerName = MPVehicleGE.getNicknameMap()[localVehID]
	local varVehPlayerName = MPVehicleGE.getNicknameMap()[vehID]
	if varGameState.players[varVehPlayerName] and varGameState.players[varLocalVehPlayerName] then -- if both clients agree that they are both in contact with each other
		if varGameState.players[varVehPlayerName].infected ~= varGameState.players[varLocalVehPlayerName].infected then -- if the remote player is not equal to the local player
    		local varServerVehID = MPVehicleGE.getServerVehicleID(vehID)
			local varRemotePlayerID, vehicleID = string.match(varServerVehID, "(%d+)-(%d+)")
			if TriggerServerEvent then TriggerServerEvent("onContact", varRemotePlayerID) end
		end
	end
end

local function recieveInfected(data)
	local varPlayerName = data
	local varPlayerServerName = MPConfig:getNickname()
	if varPlayerName == varPlayerServerName then
		MPVehicleGE.hideNicknames(false)
	end
end

local function onVehicleSwitched(oldID,ID)
	local varCurentOwnerName = MPConfig.getNickname()
	if ID and MPVehicleGE.getVehicleByGameID(ID) then
		varCurentOwnerName = MPVehicleGE.getVehicleByGameID(ID).ownerName
	end

	if varGameState.players and varGameState.players[varCurentOwnerName] and varGameState.players[varCurentOwnerName].infected then
		MPVehicleGE.hideNicknames(false)
	elseif varGameState.players and varGameState.players[varCurentOwnerName] and not varGameState.players[varCurentOwnerName].infected then
		MPVehicleGE.hideNicknames(true)
	end
end

local function nametags(curentOwnerName,player,vehicle)
	-- show red Survivor tag to Infected players in Infected mode
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
	
	-- show yellow Infected tag to Survivors -- and Zombies during Survival mode
	if varGameState.players[curentOwnerName] and not varGameState.players[curentOwnerName].infected and not player.infected and curentOwnerName ~= vehicle.ownerName then
		local varVeh = be:getObjectByID(vehicle.gameVehicleID)
		if varVeh then
			local varVehPos = varVeh:getPosition()
			local varPositionOffset = vec3(0,0,2)
			debugDrawer:drawTextAdvanced(varVehPos+varPositionOffset, String(" Infected - teammate "), ColorF(1,1,1,1), true, false, ColorI(200,50,50,255))
			
			
		end
	end
end

local function color(player,vehicle,dt)
	if player.infected then
		if not vehicle.transition or not vehicle.colortimer then
			vehicle.transition = 1
			vehicle.colortimer = 1.6
		end
		local varVeh = be:getObjectByID(vehicle.gameVehicleID)
		if varVeh then
			if not vehicle.originalColor then
				vehicle.originalColor = varVeh.color
			end
			if not vehicle.originalcolorPalette0 then
				vehicle.originalcolorPalette0 = varVeh.colorPalette0
			end
			if not vehicle.originalcolorPalette1 then
				vehicle.originalcolorPalette1 = varVeh.colorPalette1
			end

			if not varGameState.gameEnding or (varGameState.endtime - varGameState.time) > 1 then
				local varTransition = vehicle.transition
				local varColortimer = vehicle.colortimer
				local varColor = 0.6 - (1*((1+math.sin(varColortimer))/2)*0.2)
				local varColorFade = (1*((1+math.sin(varColortimer))/2))*math.max(0.6,varTransition)
				local varGreenFade = 1 -((1*((1+math.sin(varColortimer))/2))*(math.max(0.6,varTransition)))
				if varGameState.settings and not varGameState.settings.ColorPulse then
					varColor = 0.6
					varColorFade = varTransition
					varGreenFade = 1 - varTransition
				end
				--dump(k,varColorFade,varGreenFade,varTransition,varColortimer,varGameState.settings)

		
				varVeh.color = ColorF(vehicle.originalColor.x*varColorFade,(vehicle.originalColor.y*varColorFade) + (varColor*varGreenFade), vehicle.originalColor.z*varColorFade, vehicle.originalColor.w):asLinear4F()
				varVeh.colorPalette0 = ColorF(vehicle.originalcolorPalette0.x*varColorFade,(vehicle.originalcolorPalette0.y*varColorFade) + (varColor*varGreenFade), vehicle.originalcolorPalette0.z*varColorFade, vehicle.originalcolorPalette0.w):asLinear4F()
				varVeh.colorPalette1 = ColorF(vehicle.originalcolorPalette1.x*varColorFade,(vehicle.originalcolorPalette1.y*varColorFade) + (varColor*varGreenFade), vehicle.originalcolorPalette1.z*varColorFade, vehicle.originalcolorPalette1.w):asLinear4F()
			
				vehicle.colortimer = varColortimer + (dt*2.6)
				if varTransition > 0 then
					vehicle.transition = math.max(0,varTransition - dt)
				end

				vehicle.color = varColor
				vehicle.colorfade = varColorFade
				vehicle.greenfade = varGreenFade
			elseif (varGameState.endtime - varGameState.time) <= 1 then
				local varTransition = vehicle.transition
				local varColor = vehicle.color or 0
				local varColorFade = vehicle.colorfade or 1
				local varGreenFade = vehicle.greenfade or 0
				--dump(k,varColorFade,varGreenFade,varTransition,vehicle.colortimer)
			
				varVeh.color = ColorF(vehicle.originalColor.x*varColorFade,(vehicle.originalColor.y*varColorFade) + (varColor*varGreenFade), vehicle.originalColor.z*varColorFade, vehicle.originalColor.w):asLinear4F()
				varVeh.colorPalette0 = ColorF(vehicle.originalcolorPalette0.x*varColorFade,(vehicle.originalcolorPalette0.y*varColorFade) + (varColor*varGreenFade), vehicle.originalcolorPalette0.z*varColorFade, vehicle.originalcolorPalette0.w):asLinear4F()
				varVeh.colorPalette1 = ColorF(vehicle.originalcolorPalette1.x*varColorFade,(vehicle.originalcolorPalette1.y*varColorFade) + (varColor*varGreenFade), vehicle.originalcolorPalette1.z*varColorFade, vehicle.originalcolorPalette1.w):asLinear4F()
			
				vehicle.colorfade = math.min(1,varColorFade + dt)
				vehicle.greenfade = math.max(0,varGreenFade - dt)
				vehicle.colortimer = 1.6
				if varTransition < 1 then
					vehicle.transition = math.min(1,varTransition + dt)
				end
			end
		end
	end
end

local function onPreRender(dt)

	if MPCoreNetwork and not MPCoreNetwork.isMPSession() then return end
	if not varGameState.gameRunning then return end

	local varCurrentVehID = be:getPlayerVehicleID(0)
	local varCurentOwnerName = MPConfig.getNickname()

	if varCurrentVehID and MPVehicleGE.getVehicleByGameID(varCurrentVehID) then
		varCurentOwnerName = MPVehicleGE.getVehicleByGameID(varCurrentVehID).ownerName
	end

	local varClosestInfected = 100000000
	--local infectedClose = false

	for k,vehicle in pairs(MPVehicleGE.getVehicles()) do
		if varGameState.players then
			local varPlayer = varGameState.players[vehicle.ownerName]
			if varPlayer then
				nametags(varCurentOwnerName,varPlayer,vehicle)
				color(varPlayer,vehicle,dt)
				if varGameState.players[varCurentOwnerName] and varCurrentVehID and not varGameState.players[varCurentOwnerName].infected and varGameState.players[vehicle.ownerName].infected and varCurrentVehID ~= vehicle.gameVehicleID then
					local varMyVehicle = be:getObjectByID(varCurrentVehID)
					local varVehicle = be:getObjectByID(vehicle.gameVehicleID)
					if varVehicle and varMyVehicle then
						if varGameState.players[vehicle.ownerName].infected then
							local distance = distance(varMyVehicle:getPosition(),varVehicle:getPosition())
							if distance < varClosestInfected then
								varClosestInfected = distance
							end
						end
					end
				end
			end
		end
	end

	local varTempSetting = varDefaultGreenFadeDistance
	if varGameState.settings then
		varTempSetting = varGameState.settings.GreenFadeDistance
	end
	varDistancecolor = math.min(0.4,1 -(varClosestInfected/(varTempSetting or varDefaultGreenFadeDistance)))

	--[[if varDistancecolor > 0 then
		core_input_actionFilter.setGroup('vehicleTeleporting', actionTemplate.vehicleTeleporting)
		core_input_actionFilter.addAction(0, 'vehicleTeleporting', true)

		core_input_actionFilter.setGroup('resetPhysics', actionTemplate.resetPhysics)
		core_input_actionFilter.addAction(0, 'resetPhysics', true)
	else
		core_input_actionFilter.addAction(0, 'vehicleTeleporting', false)
		core_input_actionFilter.addAction(0, 'resetPhysics', false)
	end
	
	dump(varDistancecolor)]]
	
	if varGameState.settings and varGameState.settings.infectorTint and varGameState.players[varCurentOwnerName] and varGameState.players[curentOwnerName].infected then
		varDistancecolor = varGameState.settings.distancecolor or 0.5
	end
	--dump(varDistancecolor)
	scenetree["PostEffectCombinePassObject"]:setField("enableBlueShift", 0,distancecolor)
	scenetree["PostEffectCombinePassObject"]:setField("blueShiftColor", 0,"0 1 0")
end

local function onResetGameplay(id)
	--[[dump(varDistancecolor , be:getPlayerVehicleID(0) , id )
	if varDistancecolor > 0 and id == 0 then
		guihooks.message({txt = "Infector to close, cannot Reset"}, 1, "outbreak.reset")
	end]]
end

local function onExtensionUnloaded()
	resetInfected()
end

if MPGameNetwork then AddEventHandler("recieveInfected", recieveInfected) end
if MPGameNetwork then AddEventHandler("resetInfected", resetInfected) end
if MPGameNetwork then AddEventHandler("recieveGameState", recieveGameState) end
if MPGameNetwork then AddEventHandler("updateGameState", updateGameState) end

requestGameState()

M.requestGameState = requestGameState
M.sendContact = sendContact
M.onPreRender = onPreRender
M.onVehicleSwitched = onVehicleSwitched
M.resetInfected = resetInfected
M.onExtensionUnloaded = onExtensionUnloaded
M.onResetGameplay = onResetGameplay
--M.gamestate = gamestate

return M
