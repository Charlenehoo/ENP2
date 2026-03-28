-- lua/modules/LogicEntity/logic_entity.lua
-- =============================================================================
-- 通用 class 工厂函数
-- =============================================================================
local function class(name, base)
    local cls = {}
    cls.name = name
    cls.base = base

    -- 类继承（静态方法）
    if base then
        setmetatable(cls, { __index = base })
    end

    -- 实例的 __index 方法：处理方法查找与透明转发
    cls.__index = function(self, key)
        -- 1. 优先返回子类自身定义的方法
        local method = cls[key]
        if method ~= nil then
            return method
        end

        -- 2. 递归查找父类的方法
        if base then
            return base.__index(self, key)
        end

        -- 3. 透明转发：将调用转发给当前实体
        local current = self:GetCurrentEntity()
        if current then
            local value = current[key]
            if value ~= nil then
                if type(value) == "function" then
                    -- 返回一个闭包，自动解包参数中的逻辑实例
                    return function(_, ...)
                        local args = { ... }
                        for i, arg in ipairs(args) do
                            if type(arg) == "table" and arg.GetCurrentEntity then
                                args[i] = arg:GetCurrentEntity()
                            end
                        end
                        local result = value(current, unpack(args))
                        -- 如果返回值是实体，自动包装为逻辑实例
                        -- if IsValid(result) then
                        --     return LogicEntity.GetOrCreate(result)
                        -- end
                        return result
                    end
                else
                    return value
                end
            end
        end

        -- 4. 可选备用实体
        local fallback = self:GetFallbackEntity()
        if fallback then
            local value = fallback[key]
            if value ~= nil then
                if type(value) == "function" then
                    return function(_, ...)
                        local args = { ... }
                        for i, arg in ipairs(args) do
                            if type(arg) == "table" and arg.GetCurrentEntity then
                                args[i] = arg:GetCurrentEntity()
                            end
                        end
                        local result = value(fallback, unpack(args))
                        -- if IsValid(result) then
                        --     return LogicEntity.GetOrCreate(result)
                        -- end
                        return result
                    end
                else
                    return value
                end
            end
        end

        return nil
    end

    -- 实例的 __newindex：将赋值转发给当前实体
    cls.__newindex = function(self, key, value)
        local current = self:GetCurrentEntity()
        if current then
            current[key] = value
        else
            error("No valid current entity to write to")
        end
    end

    return cls
end

-- =============================================================================
-- LogicEntity 基类
-- =============================================================================
local LogicEntity = class("LogicEntity")
LogicEntity._routers = {} -- 路由表：{ predicate, factory }

--- 注册实体类型
function LogicEntity.RegisterEntityType(predicate, factory)
    table.insert(LogicEntity._routers, { predicate = predicate, factory = factory })
end

-- 抽象方法（子类必须实现）
function LogicEntity:GetCurrentEntity()
    error("GetCurrentEntity must be overridden by subclass")
end

function LogicEntity:GetFallbackEntity()
    return nil
end

function LogicEntity:GetOriginalEntity()
    error("GetOriginalEntity must be overridden by subclass")
end

function LogicEntity:IsEntityMine(entity)
    error("IsEntityMine must be overridden by subclass")
end

-- 通用方法
function LogicEntity:IsValid()
    return IsValid(self:GetCurrentEntity())
end

function LogicEntity:IsEqualTo(other)
    if type(other) == "table" and other.GetCurrentEntity then
        local selfOrig = self:GetOriginalEntity()
        local otherOrig = other:GetOriginalEntity()
        return IsValid(selfOrig) and IsValid(otherOrig) and selfOrig == otherOrig
    end
    if IsValid(other) then
        return self:IsEntityMine(other)
    end
    return false
end

-- 统一工厂方法（幂等）
function LogicEntity.GetOrCreate(entity)
    -- 幂等：已经是逻辑实例则直接返回
    if type(entity) == "table" and entity.GetCurrentEntity then
        return entity
    end

    if not IsValid(entity) then
        return nil
    end

    -- 遍历路由表，找到第一个匹配的注册项
    for _, router in ipairs(LogicEntity._routers) do
        if router.predicate(entity) then
            return router.factory(entity)
        end
    end

    return LogicDummy.GetOrCreate(entity)
end

-- =============================================================================
-- LogicDummy 子类（用于其他实体）
-- =============================================================================
local LogicDummy = class("LogicDummy", LogicEntity)

local dummyMap = {}

function LogicDummy.GetOrCreate(entity)
    if type(entity) == "table" and entity.GetCurrentEntity then
        return entity
    end
    if not IsValid(entity) then
        return nil
    end

    local dummy = dummyMap[entity]
    if dummy then
        if not IsValid(rawget(dummy, "_entity")) then
            dummyMap[entity] = nil
            dummy = nil
        end
    end

    if not dummy then
        dummy = setmetatable({ _entity = entity }, LogicDummy)
        dummyMap[entity] = dummy
    end
    return dummy
end

function LogicDummy:GetCurrentEntity()
    return rawget(self, "_entity")
end

function LogicDummy:GetFallbackEntity()
    return nil
end

function LogicDummy:GetOriginalEntity()
    return rawget(self, "_entity")
end

function LogicDummy:IsEntityMine(entity)
    return entity == rawget(self, "_entity")
end

-- 可选：清理已删除实体的缓存
local function onEntityRemoved(entity)
    if dummyMap[entity] then
        dummyMap[entity] = nil
    end
end
hook.Add("EntityRemoved", "LogicDummy_Cleanup", onEntityRemoved)

-- =============================================================================
-- 导出到全局（可选）
-- =============================================================================
_G.class = class
_G.LogicEntity = LogicEntity
