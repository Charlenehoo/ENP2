-- lua/modules/ProxyManager/proxy_behavior.lua
local Wall = include("modules/util/wall.lua")
local Predict = include("modules/util/predict.lua")

local TIMEOUT_SECONDS = 0.15

hook.Add("Tick", "ENP_ProxyBehavior_Tick", function()
    for proxy in ProxyManager.ValidProxies() do
        if proxy:CheckTimeout(TIMEOUT_SECONDS) then
            hook.Run("ENP_ProxyTimeout", proxy)
        end
        if IsValid(proxy) then
            proxy:SetPos(proxy:GetIdealPos())
        end
    end
end)

hook.Add("ENP_BulletHit", "ENP_ProxyBehavior_ResetTimeout", function(proxy, isVictimHit)
    if isVictimHit and IsValid(proxy) then
        proxy:ResetTimeout()
    end
end)

hook.Add("ENP_ProxyTimeout", "ENP_ProxyBehavior_AdvanceBone", function(proxy)
    if not IsValid(proxy) then
        return
    end

    -- 前进到下一个骨骼
    proxy:AdvanceToNextBone()
    proxy:ResetTimeout()

    -- 获取攻击者和受害者
    local attacker = proxy.attacker
    local victim = proxy.victim
    if not IsValid(attacker) or not IsValid(victim) then
        return
    end

    -- 获取武器及穿透参数
    local weapon = attacker:GetActiveWeapon()
    if not IsValid(weapon) or not weapon.ARC9 then
        return
    end

    local pen = weapon:GetProcessedValue("Penetration")
    local maxLayers = weapon.MaxPenetrationLayers or 3

    if not pen or pen <= 0 then
        return
    end

    -- 获取墙体信息
    local attackerPos = attacker:GetShootPos()
    local victimPos = victim:GetPos()
    local walls = Wall.GetWallInfoAlongLine(attacker, victim, attackerPos, victimPos)

    if #walls == 0 then
        return
    end

    -- 预测穿透结果
    local result = Predict.PredictPenetration(walls, pen, maxLayers)

    if result == Predict.PenetrationResult.CANNOT_PENETRATE then
        proxy:Remove()
    end
end)
