-- lua/modules/LogicEntity/logic_npc.lua
-- =============================================================================
-- LogicNPC 子类
-- =============================================================================
local LogicNPC = class("LogicNPC", LogicEntity)

local npcMap = {}

function LogicNPC.GetOrCreate(npc)
    if type(npc) == "table" and npc.GetCurrentEntity then
        return npc
    end
    if not IsValid(npc) or not npc:IsNPC() then
        return nil
    end

    local ln = npcMap[npc]
    if ln then
        if not IsValid(rawget(ln, "_npc")) then
            npcMap[npc] = nil
            ln = nil
        end
    end

    if not ln then
        ln = setmetatable({
            _npc = npc,
            _ragdoll = nil,
        }, LogicNPC)
        npcMap[npc] = ln
    end

    return ln
end

function LogicNPC:GetCurrentEntity()
    local ragdoll = rawget(self, "_ragdoll")
    if IsValid(ragdoll) then
        return ragdoll
    end
    return rawget(self, "_npc") -- 可能为 nil
end

function LogicNPC:GetFallbackEntity()
    return rawget(self, "_npc")
end

function LogicNPC:GetOriginalEntity()
    return rawget(self, "_npc")
end

function LogicNPC:IsEntityMine(entity)
    local npc = rawget(self, "_npc")
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

local function onNPCRagdollCreated(owner, ragdoll)
    if not IsValid(owner) or not owner:IsNPC() then
        return
    end
    local ln = npcMap[owner]
    if not ln then
        ln = LogicNPC.GetOrCreate(owner)
    end
    if ln then
        rawset(ln, "_ragdoll", ragdoll)
    end
end

local function onEntityRemoved(entity)
    if not IsValid(entity) then
        return
    end

    if entity:IsRagdoll() then
        for npc, logicNPC in pairs(npcMap) do
            if rawget(logicNPC, "_ragdoll") == entity then
                rawset(logicNPC, "_ragdoll", nil)
                -- 只有当原始 NPC 也已无效时，才删除 map 条目
                if not IsValid(rawget(logicNPC, "_npc")) then
                    npcMap[npc] = nil
                end
                break
            end
        end
    elseif entity:IsNPC() then
        local logicNPC = npcMap[entity]
        if logicNPC then
            rawset(logicNPC, "_npc", nil)
            -- 只有当 ragdoll 也已无效时，才删除 map 条目
            if not IsValid(rawget(logicNPC, "_ragdoll")) then
                npcMap[entity] = nil
            end
        end
    end
end

function LogicNPC.Init()
    hook.Add("CreateEntityRagdoll", "LogicNPC_RagdollCreated", onNPCRagdollCreated)
    hook.Add("EntityRemoved", "LogicNPC_EntityRemoved", onEntityRemoved)
    LogicEntity.RegisterEntityType(
        function(entity) return IsValid(entity) and entity:IsNPC() end,
        LogicNPC.GetOrCreate
    )
end

LogicNPC.Init()
