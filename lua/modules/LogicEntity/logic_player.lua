-- lua/modules/LogicEntity/logic_player.lua
-- 逻辑玩家代理，统一玩家与 ragdoll 的访问，支持自动切换（懒加载 + CreateEntityRagdoll 优先）
--
-- 契约保证：
-- 1. 通过 GetOrCreate 返回的对象，其内部引用的原始玩家在创建时一定有效。
-- 2. GetOriginalEntity 仅在原始玩家有效时返回该实体，否则返回 nil。
-- 3. GetCurrentEntity 仅在当前实体有效时返回该实体，否则返回 nil。
-- 4. 所有其他公共方法（如 IsEqualTo）均不会返回无效实体。

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

	local ragdoll = rawget(self, "_ragdoll")
	if IsValid(ragdoll) and entity == ragdoll then
		return true
	end

	-- 后备：通过 GetRagdollOwner 判断（对玩家 ragdoll 有效）
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
	end
end

local function OnPlayerSpawn(player)
	local logicPlayer = playerMap[player]
	if logicPlayer then
		rawset(logicPlayer, "_ragdoll", nil)
	end
end

local function OnPlayerDisconnected(player)
	-- 当前实现：直接删除 playerMap 条目。
	-- 潜在问题：若玩家断开时仍有 ragdoll 存在且被外部引用，该 ragdoll 移除时无法找到对应逻辑实例来清空 _ragdoll，
	-- 可能导致实例中 _ragdoll 残存无效引用（但玩家断开后通常进程退出或地图切换，实际影响很小）。
	-- 改进方向（如需支持长期运行的多人生存模式）：
	--   1. 不删除条目，仅清空 _player，并添加 EntityRemoved 钩子处理 ragdoll 清理。
	--   2. 在 EntityRemoved 中遍历 playerMap，若 ragdoll 匹配则清空 _ragdoll，当 _player 和 _ragdoll 均无效时再删除条目。
	--   3. 可通过 game.SinglePlayer() 判断是否启用完整清理，避免单机下不必要的开销。
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

_G.LogicPlayer = LogicPlayer or {}
