local LogicEntity = include("modules/LogicEntity/logic_entity.lua")
local LogicPlayer = setmetatable({}, { __index = LogicEntity })
LogicPlayer.__index = LogicPlayer

local playerMap = {}

LogicEntity.RegisterClass("player", LogicPlayer)

function LogicPlayer.GetOrCreate(player)
	if not IsValid(player) or not player:IsPlayer() then
		return nil
	end
	local logicPlayer = playerMap[player]
	if not logicPlayer then
		logicPlayer = setmetatable({
			_player = player,
			_ragdoll = nil,
			_current = player,
		}, LogicPlayer)
		playerMap[player] = logicPlayer
	end
	return logicPlayer
end

function LogicPlayer:GetOriginalEntity()
	return rawget(self, "_player")
end

function LogicPlayer:GetCurrentEntity()
	local player = rawget(self, "_player")
	if not IsValid(player) then
		return nil
	end
	if player:Alive() then
		return player
	end
	local ragdoll = rawget(self, "_ragdoll")
	if IsValid(ragdoll) then
		return ragdoll
	end
	ragdoll = player:GetRagdollEntity()
	if IsValid(ragdoll) then
		rawset(self, "_ragdoll", ragdoll)
		return ragdoll
	end
	return player
end

function LogicPlayer:IsEntityMine(entity)
	local player = rawget(self, "_player")
	if not IsValid(player) then
		return false
	end
	if entity == player then
		return true
	end
	if entity:IsRagdoll() then
		local owner = entity:GetRagdollOwner()
		return IsValid(owner) and owner == player
	end
	return false
end

function LogicPlayer:GetFallbackEntity()
	return rawget(self, "_player")
end

local function onRagdollCreated(owner, ragdoll)
	if not IsValid(owner) or not owner:IsPlayer() then
		return
	end
	local logicPlayer = playerMap[owner]
	if logicPlayer then
		rawset(logicPlayer, "_ragdoll", ragdoll)
		rawset(logicPlayer, "_current", ragdoll)
	end
end

local function onPlayerSpawn(player)
	local logicPlayer = playerMap[player]
	if logicPlayer then
		rawset(logicPlayer, "_ragdoll", nil)
		rawset(logicPlayer, "_current", player)
	end
end

local function onPlayerDisconnected(player)
	playerMap[player] = nil
end

function LogicPlayer.Init()
	hook.Add("CreateEntityRagdoll", "LogicPlayer_RagdollCreated", onRagdollCreated)
	hook.Add("PlayerSpawn", "LogicPlayer_PlayerSpawn", onPlayerSpawn)
	hook.Add("PlayerDisconnected", "LogicPlayer_PlayerDisconnected", onPlayerDisconnected)
end

return LogicPlayer
