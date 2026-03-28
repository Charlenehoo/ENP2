-- lua/modules/LogicEntity/logic_player.lua
-- 逻辑玩家代理，统一玩家与 ragdoll 的访问，支持自动切换（懒加载 + CreateEntityRagdoll 优先）
--
-- 契约保证：
-- 1. 通过 GetOrCreate 返回的对象，其内部引用的原始玩家在创建时一定有效。
-- 2. GetOriginalEntity 仅在原始玩家有效时返回该实体，否则返回 nil。
-- 3. GetCurrentEntity 仅在当前实体有效时返回该实体，否则返回 nil。
-- 4. 所有其他公共方法（如 IsEqualTo）均不会返回无效实体。

local LogicEntity = include("modules/LogicEntity/logic_entity.lua")
local LogicPlayer = setmetatable({}, { __index = LogicEntity })
LogicPlayer.__index = LogicPlayer

local playerMap = {}

LogicEntity.RegisterClass("player", LogicPlayer)

-- ----------------------------------------------------------------------
-- 公开工厂方法（契约保证）
-- ----------------------------------------------------------------------

function LogicPlayer.GetOrCreate(player)
	if not IsValid(player) or not player:IsPlayer() then
		return nil
	end

	local logicPlayer = playerMap[player]
	if logicPlayer then
		local storedPlayer = rawget(logicPlayer, "_player")
		if not IsValid(storedPlayer) then
			playerMap[player] = nil
			logicPlayer = nil
		end
	end

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

-- ----------------------------------------------------------------------
-- 抽象方法实现
-- ----------------------------------------------------------------------

function LogicPlayer:GetOriginalEntity()
	local player = rawget(self, "_player")
	if IsValid(player) then
		return player
	end
	return nil
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

	-- 回退到玩家（但玩家此时已死亡，且可能有效，仍返回玩家）
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

	if IsValid(entity) and entity:IsRagdoll() then
		local owner = entity:GetRagdollOwner()
		return IsValid(owner) and owner == player
	end

	return false
end

function LogicPlayer:GetFallbackEntity()
	return self:GetOriginalEntity() -- 回退到原始玩家（可能为 nil）
end

-- ----------------------------------------------------------------------
-- 自动切换钩子
-- ----------------------------------------------------------------------

local function OnRagdollCreated(owner, ragdoll)
	if not IsValid(owner) or not owner:IsPlayer() then
		return
	end

	local logicPlayer = playerMap[owner]
	if not logicPlayer then
		logicPlayer = LogicPlayer.GetOrCreate(owner)
	end

	if logicPlayer then
		rawset(logicPlayer, "_ragdoll", ragdoll)
		rawset(logicPlayer, "_current", ragdoll)
	end
end

local function OnPlayerSpawn(player)
	local logicPlayer = playerMap[player]
	if logicPlayer then
		rawset(logicPlayer, "_ragdoll", nil)
		rawset(logicPlayer, "_current", player)
	end
end

local function OnPlayerDisconnected(player)
	playerMap[player] = nil
end

-- ----------------------------------------------------------------------
-- 模块初始化
-- ----------------------------------------------------------------------

function LogicPlayer.Init()
	hook.Add("CreateEntityRagdoll", "LogicPlayer_RagdollCreated", OnRagdollCreated)
	hook.Add("PlayerSpawn", "LogicPlayer_PlayerSpawn", OnPlayerSpawn)
	hook.Add("PlayerDisconnected", "LogicPlayer_PlayerDisconnected", OnPlayerDisconnected)
end

return LogicPlayer
