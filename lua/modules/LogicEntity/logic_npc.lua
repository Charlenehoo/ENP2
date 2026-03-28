local LogicEntity = include("modules/LogicEntity/logic_entity.lua")
local LogicNPC = setmetatable({}, { __index = LogicEntity })
LogicNPC.__index = LogicNPC

local nonPlayerCharacterMap = {}

LogicEntity.RegisterClass("npc", LogicNPC)

function LogicNPC.GetOrCreate(entity)
	if not IsValid(entity) or not entity:IsNPC() then
		return nil
	end
	local logicNonPlayerCharacter = nonPlayerCharacterMap[entity]
	if not logicNonPlayerCharacter then
		logicNonPlayerCharacter = setmetatable({
			_nonPlayerCharacter = entity,
			_ragdoll = nil,
			_current = entity,
		}, LogicNPC)
		nonPlayerCharacterMap[entity] = logicNonPlayerCharacter
	end
	return logicNonPlayerCharacter
end

function LogicNPC:GetOriginalEntity()
	return rawget(self, "_nonPlayerCharacter")
end

function LogicNPC:GetCurrentEntity()
	local nonPlayerCharacter = rawget(self, "_nonPlayerCharacter")
	if not IsValid(nonPlayerCharacter) then
		return nil
	end
	local ragdoll = rawget(self, "_ragdoll")
	if IsValid(ragdoll) then
		return ragdoll
	end
	return nonPlayerCharacter
end

function LogicNPC:IsEntityMine(entity)
	local nonPlayerCharacter = rawget(self, "_nonPlayerCharacter")
	if not IsValid(nonPlayerCharacter) then
		return false
	end
	if entity == nonPlayerCharacter then
		return true
	end
	local ragdoll = rawget(self, "_ragdoll")
	if IsValid(ragdoll) and entity == ragdoll then
		return true
	end
	return false
end

local function onRagdollCreated(owner, ragdoll)
	if not IsValid(owner) or not owner:IsNPC() then
		return
	end
	local logicNonPlayerCharacter = nonPlayerCharacterMap[owner]
	if not logicNonPlayerCharacter then
		logicNonPlayerCharacter = LogicNPC.GetOrCreate(owner)
	end
	if logicNonPlayerCharacter then
		rawset(logicNonPlayerCharacter, "_ragdoll", ragdoll)
		rawset(logicNonPlayerCharacter, "_current", ragdoll)
	end
end

local function onEntityRemoved(entity)
	if entity:IsNPC() then
		nonPlayerCharacterMap[entity] = nil
	end
end

function LogicNPC.Init()
	hook.Add("CreateEntityRagdoll", "LogicNPC_RagdollCreated", onRagdollCreated)
	hook.Add("EntityRemoved", "LogicNPC_EntityRemoved", onEntityRemoved)
end

return LogicNPC
