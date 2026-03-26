-- lua/modules/ProxyManager/proxy_behavior.lua

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

hook.Add("ENP_ProxyTimeout", "ENP_ProxyBehavior_AdvanceBone", function(proxy)
    if IsValid(proxy) then
        proxy:AdvanceToNextBone()
        proxy:ResetTimeout()
    end
end)

hook.Add("ENP_BulletHit", "ENP_ProxyBehavior_ResetTimeout", function(proxy, isVictimHit)
    if isVictimHit and IsValid(proxy) then
        proxy:ResetTimeout()
    end
end)
