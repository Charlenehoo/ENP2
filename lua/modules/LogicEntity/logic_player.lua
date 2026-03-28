-- lua/modules/LogicEntity/logic_player.lua
-- 逻辑玩家代理，统一玩家与 ragdoll 的访问，支持自动切换（懒加载 + CreateEntityRagdoll 优先）
-- 契约保证：通过 GetOrCreate 返回的对象，其内部引用的原始实体一定有效

local LogicEntity = include("modules/LogicEntity/logic_entity.lua")
local LogicPlayer = setmetatable({}, { __index = LogicEntity })
LogicPlayer.__index = LogicPlayer

local playerMap = {}

LogicEntity.RegisterClass("player", LogicPlayer)

-- ----------------------------------------------------------------------
-- 公开工厂方法（契约保证）
-- ----------------------------------------------------------------------

function LogicPlayer.GetOrCreate(player)
	-- 输入实体无效或不是玩家，返回 nil
	if not IsValid(player) or not player:IsPlayer() then
		return nil
	end

	local logicPlayer = playerMap[player]
	if logicPlayer then
		-- 检查存储的原始玩家是否仍然有效（契约保证）
		local storedPlayer = rawget(logicPlayer, "_player")
		if not IsValid(storedPlayer) then
			-- 无效，从映射中移除并重新创建
			playerMap[player] = nil
			logicPlayer = nil
		end
	end

	if not logicPlayer then
		logicPlayer = setmetatable({
			_player = player, -- 原始玩家实体
			_ragdoll = nil, -- 死亡后的 ragdoll（由钩子填充）
			_current = player, -- 当前激活实体（玩家或 ragdoll）
		}, LogicPlayer)
		playerMap[player] = logicPlayer
	end

	return logicPlayer
end

-- ----------------------------------------------------------------------
-- 抽象方法实现
-- ----------------------------------------------------------------------

function LogicPlayer:GetOriginalEntity()
	return rawget(self, "_player")
end

function LogicPlayer:GetCurrentEntity()
	local player = rawget(self, "_player")
	if not IsValid(player) then
		return nil
	end

	-- 玩家存活则返回玩家
	if player:Alive() then
		return player
	end

	-- 玩家死亡，优先使用已存储的 ragdoll
	local ragdoll = rawget(self, "_ragdoll")
	if IsValid(ragdoll) then
		return ragdoll
	end

	-- 若未存储，尝试懒加载（兼容没有钩子的情况）
	ragdoll = player:GetRagdollEntity()
	if IsValid(ragdoll) then
		rawset(self, "_ragdoll", ragdoll)
		return ragdoll
	end

	-- 都没有，回退到玩家（保证不返回 nil）
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

-- ----------------------------------------------------------------------
-- 自动切换钩子
-- ----------------------------------------------------------------------

local function OnRagdollCreated(owner, ragdoll)
	if not IsValid(owner) or not owner:IsPlayer() then
		return
	end

	-- 确保逻辑实例存在（若不存在则创建）
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
