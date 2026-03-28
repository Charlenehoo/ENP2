-- lua/modules/LogicEntity/logic_npc.lua
-- 逻辑 NPC 代理，统一 NPC 与 ragdoll 的访问，支持自动切换（钩子优先）
-- 契约保证：通过 GetOrCreate 返回的对象，其内部引用的原始实体一定有效

local LogicEntity = include("modules/LogicEntity/logic_entity.lua")
local LogicNPC = setmetatable({}, { __index = LogicEntity })
LogicNPC.__index = LogicNPC

local npcMap = {}

LogicEntity.RegisterClass("npc", LogicNPC)

-- ----------------------------------------------------------------------
-- 公开工厂方法（契约保证）
-- ----------------------------------------------------------------------

function LogicNPC.GetOrCreate(entity)
	-- 输入实体无效或不是 NPC，返回 nil
	if not IsValid(entity) or not entity:IsNPC() then
		return nil
	end

	local logicNPC = npcMap[entity]
	if logicNPC then
		-- 检查存储的原始 NPC 是否仍然有效（契约保证）
		local storedNPC = rawget(logicNPC, "_NPC")
		if not IsValid(storedNPC) then
			-- 无效，从映射中移除并重新创建
			npcMap[entity] = nil
			logicNPC = nil
		end
	end

	if not logicNPC then
		logicNPC = setmetatable({
			_NPC = entity, -- 原始 NPC 实体
			_ragdoll = nil, -- 死亡后的 ragdoll（由钩子填充）
			_current = entity, -- 当前激活实体（NPC 或 ragdoll）
		}, LogicNPC)
		npcMap[entity] = logicNPC
	end

	return logicNPC
end

-- ----------------------------------------------------------------------
-- 抽象方法实现
-- ----------------------------------------------------------------------

function LogicNPC:GetOriginalEntity()
	return rawget(self, "_NPC")
end

function LogicNPC:GetCurrentEntity()
	local npc = rawget(self, "_NPC")
	if not IsValid(npc) then
		return nil
	end

	-- 死亡后，如果有 ragdoll 则返回 ragdoll
	local ragdoll = rawget(self, "_ragdoll")
	if IsValid(ragdoll) then
		return ragdoll
	end

	-- 否则返回 NPC（存活状态）
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
-- 自动切换钩子（必须监听 CreateEntityRagdoll）
-- ----------------------------------------------------------------------

local function OnRagdollCreated(owner, ragdoll)
	if not IsValid(owner) or not owner:IsNPC() then
		return
	end

	-- 确保逻辑实例存在（若不存在则创建）
	local logicNPC = npcMap[owner]
	if not logicNPC then
		logicNPC = LogicNPC.GetOrCreate(owner)
	end

	if logicNPC then
		-- 立即存储 ragdoll，防止被 GC
		rawset(logicNPC, "_ragdoll", ragdoll)
		rawset(logicNPC, "_current", ragdoll)
	end
end

local function OnEntityRemoved(entity)
	if entity:IsNPC() then
		npcMap[entity] = nil
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
