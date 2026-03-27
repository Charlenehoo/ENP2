-- modules/util/logic_player.lua
-- 逻辑玩家代理，统一玩家与 ragdoll 的访问，支持自动切换（懒加载）
-- 永不返回 nil：若玩家死亡且 ragdoll 未就绪，则回退到玩家实体（即使已死亡）

local LogicPlayer = {}
LogicPlayer.__index = LogicPlayer

-- 玩家实体 -> 逻辑玩家实例映射
local playerMap = {}

-- ----------------------------------------------------------------------
-- 私有函数
-- ----------------------------------------------------------------------

-- 根据玩家实体获取逻辑玩家，不存在则创建
local function _GetOrCreateForPlayer(player)
    if not IsValid(player) or not player:IsPlayer() then
        return nil
    end
    local logicPlayer = playerMap[player]
    if not logicPlayer then
        logicPlayer = setmetatable({
            _player = player,
        }, LogicPlayer)
        playerMap[player] = logicPlayer
    end
    return logicPlayer
end

-- 获取当前应使用的实体（永不返回 nil）
-- 规则：玩家存活 → 玩家；玩家死亡且有 ragdoll → ragdoll；否则回退到玩家（即使已死亡）
local function _GetCurrentEntity(self)
    local player = self._player
    if not IsValid(player) then
        return nil
    end
    -- 玩家存活则直接返回
    if player:Alive() then
        return player
    end
    -- 玩家死亡，尝试获取 ragdoll
    local ragdoll = player:GetRagdollEntity()
    if IsValid(ragdoll) then
        return ragdoll
    end
    -- 没有 ragdoll（死亡瞬间），回退到玩家（保证不返回 nil）
    return player
end

-- ----------------------------------------------------------------------
-- 公开函数（方法）
-- ----------------------------------------------------------------------

-- 根据玩家或 ragdoll 获取对应的逻辑玩家
function LogicPlayer.GetOrCreate(entity)
    if not IsValid(entity) then
        return nil
    end
    if entity:IsPlayer() then
        return _GetOrCreateForPlayer(entity)
    elseif entity:IsRagdoll() then
        local owner = entity:GetRagdollOwner()
        if IsValid(owner) and owner:IsPlayer() then
            return _GetOrCreateForPlayer(owner)
        end
    end
    return nil
end

-- 判断当前逻辑玩家是否代表指定的实体或另一个逻辑玩家
function LogicPlayer:IsEqualTo(other)
    -- 1. 如果 other 是逻辑玩家，比较其关联的玩家实体
    if type(other) == "table" and getmetatable(other) == LogicPlayer then
        local selfPlayer = self._player
        local otherPlayer = other._player
        return IsValid(selfPlayer) and IsValid(otherPlayer) and selfPlayer == otherPlayer
    end

    -- 以下为实体比较
    local player = self._player
    if not IsValid(player) then
        return false
    end

    -- 2. 直接与玩家实体比较
    if other == player then
        return true
    end

    -- 3. 与 ragdoll 实体比较（必须确保 other 是有效实体）
    if IsValid(other) and other:IsRagdoll() then
        local owner = other:GetRagdollOwner()
        return IsValid(owner) and owner == player
    end

    return false
end

-- ----------------------------------------------------------------------
-- 元方法（实现透明转发）
-- ----------------------------------------------------------------------

function LogicPlayer:__index(key)
    local current = _GetCurrentEntity(self)
    if current then
        local value = current[key]
        if type(value) == "function" then
            return function(...)
                return value(current, ...)
            end
        else
            return value
        end
    end
    return LogicPlayer[key]
end

function LogicPlayer:__newindex(key, value)
    local current = _GetCurrentEntity(self)
    if current then
        current[key] = value
    else
        error("No valid current entity to write to")
    end
end

function LogicPlayer:__call(...)
    local current = _GetCurrentEntity(self)
    if type(current) == "function" then
        return current(...)
    elseif current and current.__call then
        return current:__call(...)
    else
        error("Current entity is not callable")
    end
end

-- ----------------------------------------------------------------------
-- 可选：提供内部访问当前实体的方法（仅用于特殊场景，如缓存）
function LogicPlayer:_GetCurrent()
    return _GetCurrentEntity(self)
end

return LogicPlayer
