-- lua/modules/LogicEntity/logic_npc.lua
-- 逻辑 NPC 代理，统一 NPC 与 ragdoll 的访问，支持自动切换（钩子优先）
--
-- 契约保证：
-- 1. 通过 GetOrCreate 返回的对象，其内部引用的原始 NPC 在创建时一定有效。
-- 2. GetOriginalEntity 仅在原始 NPC 有效时返回该实体，否则返回 nil。
-- 3. GetCurrentEntity 仅在当前实体有效时返回该实体，否则返回 nil。
-- 4. 当 ragdoll 被移除时，通过遍历 npcMap 清理对应的条目，避免无效引用残留。

local LogicEntity = include("modules/LogicEntity/logic_entity.lua")
local LogicNPC = setmetatable({}, { __index = LogicEntity })
LogicNPC.__index = LogicNPC

local npcMap = {}

LogicEntity.RegisterClass("npc", LogicNPC)

-- ----------------------------------------------------------------------
-- 公开工厂方法（契约保证）
-- ----------------------------------------------------------------------

function LogicNPC.GetOrCreate(entity)
	if not IsValid(entity) or not entity:IsNPC() then
		return nil
	end

	local logicNPC = npcMap[entity]
	if logicNPC then
		local storedNPC = rawget(logicNPC, "_NPC")
		if not IsValid(storedNPC) then
			npcMap[entity] = nil
			logicNPC = nil
		end
	end

	if not logicNPC then
		logicNPC = setmetatable({
			_NPC = entity,
			_ragdoll = nil,
		}, LogicNPC)
		npcMap[entity] = logicNPC
	end

	return logicNPC
end

-- ----------------------------------------------------------------------
-- 抽象方法实现
-- ----------------------------------------------------------------------

function LogicNPC:GetOriginalEntity()
	local npc = rawget(self, "_NPC")
	if IsValid(npc) then
		return npc
	end
	return nil
end

function LogicNPC:GetCurrentEntity()
	local ragdoll = rawget(self, "_ragdoll")
	if IsValid(ragdoll) then
		return ragdoll
	end

	local npc = rawget(self, "_NPC")
	if not IsValid(npc) then
		return nil
	end

	return npc
end

function LogicNPC:IsEntityMine(entity)
	local npc = rawget(self, "_NPC")
	if not IsValid(npc) then
		return false
	end

	if entity == npc then
		return true
	end

	local ragdoll = rawget(self, "_ragdoll")
	if IsValid(ragdoll) and entity == ragdoll then
		return true
	end

	return false
end

-- ----------------------------------------------------------------------
-- 自动切换钩子
-- ----------------------------------------------------------------------

local function OnRagdollCreated(owner, ragdoll)
	if not IsValid(owner) or not owner:IsNPC() then
		return
	end

	local logicNPC = npcMap[owner]
	if not logicNPC then
		logicNPC = LogicNPC.GetOrCreate(owner)
	end

	if logicNPC then
		rawset(logicNPC, "_ragdoll", ragdoll)
	end
end

local function OnEntityRemoved(entity)
	if not IsValid(entity) then
		return
	end

	if entity:IsRagdoll() then
		for npc, logicNPC in pairs(npcMap) do
			if rawget(logicNPC, "_ragdoll") == entity then
				rawset(logicNPC, "_ragdoll", nil)
				-- 只有当原始 NPC 也已无效时，才删除 map 条目
				if not IsValid(rawget(logicNPC, "_NPC")) then
					npcMap[npc] = nil
				end
				break
			end
		end
	elseif entity:IsNPC() then
		local logicNPC = npcMap[entity]
		if logicNPC then
			rawset(logicNPC, "_NPC", nil)
			-- 只有当 ragdoll 也已无效时，才删除 map 条目
			if not IsValid(rawget(logicNPC, "_ragdoll")) then
				npcMap[entity] = nil
			end
		end
	end
end

-- ----------------------------------------------------------------------
-- 模块初始化
-- ----------------------------------------------------------------------

function LogicNPC.Init()
	hook.Add("CreateEntityRagdoll", "LogicNPC_RagdollCreated", OnRagdollCreated)
	hook.Add("EntityRemoved", "LogicNPC_EntityRemoved", OnEntityRemoved)
end

return LogicNPC
