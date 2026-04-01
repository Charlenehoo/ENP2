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

function LogicDummy.Init()
    hook.Add("EntityRemoved", "LogicDummy_Cleanup", onEntityRemoved)
    LogicEntity.RegisterEntityType(
        function(entity) return true end,
        LogicDummy.GetOrCreate
    )
end

LogicDummy.Init()
