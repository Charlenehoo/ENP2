-- lua/modules/LogicEntity/logic_player.lua
-- =============================================================================
-- LogicPlayer 子类
-- =============================================================================
local LogicPlayer = class("LogicPlayer", LogicEntity)

local playerMap = {}

function LogicPlayer.GetOrCreate(player)
    if type(player) == "table" and player.GetCurrentEntity then
        return player
    end
    if not IsValid(player) or not player:IsPlayer() then
        return nil
    end

    local lp = playerMap[player]
    if lp then
        -- 验证内部 _player 是否仍然有效
        if not IsValid(rawget(lp, "_player")) then
            playerMap[player] = nil
            lp = nil
        end
    end

    if not lp then
        lp = setmetatable({
            _player = player,
            _ragdoll = nil,
        }, LogicPlayer)
        playerMap[player] = lp
    end

    return lp
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
    return self:GetFallbackEntity()
end

function LogicPlayer:GetFallbackEntity()
    return rawget(self, "_player")
end

function LogicPlayer:GetOriginalEntity()
    return rawget(self, "_player")
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
    if IsValid(entity) and entity:IsRagdoll() then
        return entity:GetRagdollOwner() == player
    end
    return false
end

-- 钩子：更新 ragdoll
local function onPlayerRagdollCreated(owner, ragdoll)
    if not IsValid(owner) or not owner:IsPlayer() then
        return
    end
    local lp = playerMap[owner]
    if not lp then
        lp = LogicPlayer.GetOrCreate(owner)
    end
    if lp then
        rawset(lp, "_ragdoll", ragdoll)
    end
end

local function onPlayerSpawn(player)
    local lp = playerMap[player]
    if lp then
        rawset(lp, "_ragdoll", nil)
    end
end

local function onPlayerDisconnected(player)
    -- 当前实现：直接删除 playerMap 条目。
    -- 潜在问题：若玩家断开时仍有 ragdoll 存在且被外部引用，该 ragdoll 移除时无法找到对应逻辑实例来清空 _ragdoll，
    -- 可能导致实例中 _ragdoll 残存无效引用（但玩家断开后通常进程退出或地图切换，实际影响很小）。
    -- 改进方向（如需支持长期运行的多人生存模式）：
    --   1. 不删除条目，仅清空 _player，并添加 EntityRemoved 钩子处理 ragdoll 清理。
    --   2. 在 EntityRemoved 中遍历 playerMap，若 ragdoll 匹配则清空 _ragdoll，当 _player 和 _ragdoll 均无效时再删除条目。
    --   3. 可通过 game.SinglePlayer() 判断是否启用完整清理，避免单机下不必要的开销。
    playerMap[player] = nil
end

function LogicPlayer.Init()
    hook.Add("CreateEntityRagdoll", "LogicPlayer_RagdollCreated", onPlayerRagdollCreated)
    hook.Add("PlayerSpawn", "LogicPlayer_PlayerSpawn", onPlayerSpawn)
    hook.Add("PlayerDisconnected", "LogicPlayer_PlayerDisconnected", onPlayerDisconnected)
    LogicEntity.RegisterEntityType(
        function(entity) return IsValid(entity) and entity:IsPlayer() end,
        LogicPlayer.GetOrCreate
    )
end

LogicPlayer.Init()
