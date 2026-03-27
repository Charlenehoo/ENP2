-- modules/util/logic_player.lua
-- 逻辑玩家代理，统一玩家与 ragdoll 的访问，支持自动切换（懒加载 + CreateEntityRagdoll 优先）
-- 永不返回 nil：若玩家死亡且 ragdoll 未就绪，则回退到玩家实体（即使已死亡）

local LogicPlayer = {}
LogicPlayer.__index = LogicPlayer

-- 玩家实体 -> 逻辑玩家实例映射
local playerMap = {}

-- ----------------------------------------------------------------------
-- 私有函数
-- ----------------------------------------------------------------------

-- 根据玩家实体获取逻辑玩家，不存在则创建
local function getOrCreateForPlayer(player)
    if not IsValid(player) or not player:IsPlayer() then
        return nil
    end
    local logicPlayer = playerMap[player]
    if not logicPlayer then
        logicPlayer = setmetatable({
            _player = player,
            _ragdoll = nil, -- 由 CreateEntityRagdoll 钩子填充
        }, LogicPlayer)
        playerMap[player] = logicPlayer
    end
    return logicPlayer
end

-- 获取当前应使用的实体（永不返回 nil）
-- 规则：玩家存活 → 玩家；玩家死亡且 _ragdoll 有效 → ragdoll；否则回退到玩家（即使已死亡）
local function getCurrentEntity(self)
    -- 使用 rawget 直接获取字段，避免触发 __index 元方法
    local player = rawget(self, "_player")
    if not IsValid(player) then
        return nil
    end
    -- 玩家存活则直接返回
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
        rawset(self, "_ragdoll", ragdoll) -- 直接设置，不触发 __newindex
        return ragdoll
    end
    -- 都没有，回退到玩家（保证不返回 nil）
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
        return getOrCreateForPlayer(entity)
    elseif entity:IsRagdoll() then
        local owner = entity:GetRagdollOwner()
        if IsValid(owner) and owner:IsPlayer() then
            local logicPlayer = getOrCreateForPlayer(owner)
            -- 如果这个 ragdoll 尚未缓存，则更新缓存
            if logicPlayer and not IsValid(rawget(logicPlayer, "_ragdoll")) then
                rawset(logicPlayer, "_ragdoll", entity)
            end
            return logicPlayer
        end
    end
    return nil
end

-- 判断当前逻辑玩家是否代表指定的实体或另一个逻辑玩家
function LogicPlayer:IsEqualTo(other)
    -- 1. 如果 other 是逻辑玩家，比较其关联的玩家实体
    if type(other) == "table" and getmetatable(other) == LogicPlayer then
        local selfPlayer = rawget(self, "_player")
        local otherPlayer = rawget(other, "_player")
        return IsValid(selfPlayer) and IsValid(otherPlayer) and selfPlayer == otherPlayer
    end

    -- 以下为实体比较
    local player = rawget(self, "_player")
    if not IsValid(player) then
        return false
    end

    -- 2. 直接与玩家实体比较
    if other == player then
        return true
    end

    -- 3. 与 ragdoll 实体比较（优先使用存储的 _ragdoll，再通过 GetRagdollOwner 判断）
    local ragdoll = rawget(self, "_ragdoll")
    if IsValid(ragdoll) and other == ragdoll then
        return true
    end
    if IsValid(other) and other.GetRagdollOwner then
        local owner = other:GetRagdollOwner()
        if IsValid(owner) and owner == player then
            -- 如果当前存储的 ragdoll 不是这个，更新缓存
            if not IsValid(ragdoll) then
                rawset(self, "_ragdoll", other)
            end
            return true
        end
    end

    return false
end

-- ----------------------------------------------------------------------
-- 元方法（实现透明转发）
-- ----------------------------------------------------------------------

function LogicPlayer:__index(key)
    local current = getCurrentEntity(self)
    if current then
        local value = current[key]
        if value ~= nil then
            if type(value) == "function" then
                return function(_, ...)
                    return value(current, ...)
                end
            else
                return value
            end
        end
    end
    -- 当前实体没有该方法，尝试从玩家实体获取
    local player = rawget(self, "_player")
    if IsValid(player) then
        local value = player[key]
        if value ~= nil then
            if type(value) == "function" then
                return function(_, ...)
                    return value(player, ...)
                end
            else
                return value
            end
        end
    end
    return LogicPlayer[key]
end

function LogicPlayer:__newindex(key, value)
    local current = getCurrentEntity(self)
    if current then
        current[key] = value
    else
        error("No valid current entity to write to")
    end
end

function LogicPlayer:__call(...)
    local current = getCurrentEntity(self)
    if type(current) == "function" then
        return current(...)
    elseif current and current.__call then
        return current:__call(...)
    else
        error("Current entity is not callable")
    end
end

-- 可选：提供内部访问当前实体的方法（仅用于特殊场景）
function LogicPlayer:_GetCurrent()
    return getCurrentEntity(self)
end

-- ----------------------------------------------------------------------
-- 自动切换钩子（监听 CreateEntityRagdoll）
-- ----------------------------------------------------------------------

-- 当 ragdoll 创建时，立即更新对应逻辑玩家的 _ragdoll 字段
local function onRagdollCreated(owner, ragdoll)
    if not IsValid(owner) or not owner:IsPlayer() then
        return
    end
    local logicPlayer = playerMap[owner]
    if logicPlayer then
        rawset(logicPlayer, "_ragdoll", ragdoll)
    end
end

-- 玩家重生时，清除 ragdoll 引用（因为 ragdoll 将被移除或不再属于该玩家）
local function onPlayerSpawn(player)
    local logicPlayer = playerMap[player]
    if logicPlayer then
        rawset(logicPlayer, "_ragdoll", nil)
    end
end

-- 玩家断开时，清理映射
local function onPlayerDisconnected(player)
    playerMap[player] = nil
end

-- 模块初始化：注册钩子
function LogicPlayer.Init()
    hook.Add("CreateEntityRagdoll", "LogicPlayer_RagdollCreated", onRagdollCreated)
    hook.Add("PlayerSpawn", "LogicPlayer_PlayerSpawn", onPlayerSpawn)
    hook.Add("PlayerDisconnected", "LogicPlayer_PlayerDisconnected", onPlayerDisconnected)
end

return LogicPlayer
