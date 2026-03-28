local LogicEntity = include("modules/LogicEntity/logic_entity.lua")
local LogicNPC = setmetatable({}, { __index = LogicEntity })
LogicNPC.__index = LogicNPC

local npcMap = {}

LogicEntity.RegisterClass("npc", LogicNPC)

function LogicNPC.GetOrCreate(entity)
	if not IsValid(entity) or not entity:IsNPC() then
		return nil
	end
	local logicNPC = npcMap[entity]
	if not logicNPC then
		logicNPC = setmetatable({
			_NPC = entity,
			_ragdoll = nil,
			_current = entity,
		}, LogicNPC)
		npcMap[entity] = logicNPC
	end
	return logicNPC
end

function LogicNPC:GetOriginalEntity()
	return rawget(self, "_NPC")
end

function LogicNPC:GetCurrentEntity()
	local NPC = rawget(self, "_NPC")
	if not IsValid(NPC) then
		return nil
	end
	local ragdoll = rawget(self, "_ragdoll")
	if IsValid(ragdoll) then
		return ragdoll
	end
	return NPC
end

function LogicNPC:IsEntityMine(entity)
	local NPC = rawget(self, "_NPC")
	if not IsValid(NPC) then
		return false
	end
	if entity == NPC then
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
	local logicNPC = npcMap[owner]
	if not logicNPC then
		logicNPC = LogicNPC.GetOrCreate(owner)
	end
	if logicNPC then
		rawset(logicNPC, "_ragdoll", ragdoll)
		rawset(logicNPC, "_current", ragdoll)
	end
end

local function onEntityRemoved(entity)
	if entity:IsNPC() then
		npcMap[entity] = nil
	end
end

function LogicNPC.Init()
	hook.Add("CreateEntityRagdoll", "LogicNPC_RagdollCreated", onRagdollCreated)
	hook.Add("EntityRemoved", "LogicNPC_EntityRemoved", onEntityRemoved)
end

return LogicNPC
