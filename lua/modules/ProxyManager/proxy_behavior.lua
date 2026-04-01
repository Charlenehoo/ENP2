-- lua/modules/ProxyManager/proxy_behavior.lua
local Debugger = include("modules/util/debugger.lua")

local BONE_TIMEOUT_SECONDS = 0.15 -- 骨骼未命中超时（秒）
local PROXY_TIMEOUT_SECONDS = 6.0 -- 代理整体未命中超时（秒）

hook.Add("Tick", "ENP_ProxyBehavior_Tick", function()
	for proxy in ProxyManager.ValidProxies() do
		if not IsValid(proxy) then
			continue
		end

		local curTime = CurTime()

		-- 检查代理整体超时
		if curTime - proxy:GetLastHitTime() > PROXY_TIMEOUT_SECONDS then
			Debugger.Print(
				string.format(
					"[ProxyBehavior] Removing proxy %s due to overall timeout (%.1fs without hit)",
					tostring(proxy),
					PROXY_TIMEOUT_SECONDS
				),
				Debugger.LEVEL.INFO
			)
			proxy:Remove()
			continue
		end

		-- 检查当前骨骼超时
		if curTime - proxy:GetLastBoneHitTime() > BONE_TIMEOUT_SECONDS then
			proxy:AdvanceToNextBone()
			proxy:UpdateLastBoneHitTime() -- 重置骨骼计时器
		end

		-- 更新位置到当前骨骼
		proxy:SetPos(proxy:GetIdealPos())
	end
end)

hook.Add("ENP_BulletHit", "ENP_ProxyBehavior_RecordHit", function(proxy, isVictimHit)
	if not IsValid(proxy) then
		return
	end
	if isVictimHit then
		proxy:UpdateLastHitTime()
		proxy:UpdateLastBoneHitTime()
	end
end)
