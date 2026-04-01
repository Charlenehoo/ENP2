-- lua/modules/ProxyManager/proxy_behavior.lua
local Debugger = include("modules/util/debugger.lua")

local BONE_TIMEOUT_SECONDS = 0.3 -- 骨骼未命中超时（秒）
local PROXY_TIMEOUT_SECONDS = 3.0 -- 代理整体未命中超时（秒）
local SHOOTING_ACTIVE_WINDOW = 0.15 -- 射击活跃窗口（秒）

hook.Add("ENP_BulletFired", "ENP_ProxyBehavior_UpdateShotTime", function(proxy)
	if not IsValid(proxy) then
		return
	end
	proxy:UpdateLastShotTime()
	Debugger.Print(
		string.format("[ProxyBehavior] Proxy %s fired, shot time updated", tostring(proxy)),
		Debugger.LEVEL.TRACE
	)
end)

hook.Add("ENP_BulletHit", "ENP_ProxyBehavior_RecordHit", function(proxy, isVictimHit)
	if not IsValid(proxy) then
		return
	end
	if isVictimHit then
		local curTime = CurTime()
		local oldHitTime = proxy:GetLastHitTime()
		local oldBoneHitTime = proxy:GetLastBoneHitTime()
		proxy:UpdateLastHitTime()
		proxy:UpdateLastBoneHitTime()
		Debugger.Print(
			string.format(
				"[ProxyBehavior] Proxy %s hit victim, extending life. Time since last hit: %.2fs, since last bone hit: %.2fs, accumulated miss reset (active=%s)",
				tostring(proxy),
				curTime - oldHitTime,
				curTime - oldBoneHitTime,
				tostring(proxy:IsActive())
			),
			Debugger.LEVEL.TRACE
		)
	end
end)

hook.Add("Tick", "ENP_ProxyBehavior_Tick", function()
	for proxy in ProxyManager.ValidProxies() do
		if not IsValid(proxy) then
			continue
		end

		local curTime = CurTime()
		local lastShot = proxy:GetLastShotTime()
		local isActiveByShot = (curTime - lastShot) <= SHOOTING_ACTIVE_WINDOW

		-- 状态同步：根据射击窗口更新 active 状态（仅状态变化时打印）
		if isActiveByShot and not proxy:IsActive() then
			proxy:SetActive(true)
			Debugger.Print(
				string.format("[ProxyBehavior] Proxy %s became active", tostring(proxy)),
				Debugger.LEVEL.INFO
			)
		elseif not isActiveByShot and proxy:IsActive() then
			proxy:SetActive(false)
			Debugger.Print(
				string.format("[ProxyBehavior] Proxy %s became inactive", tostring(proxy)),
				Debugger.LEVEL.INFO
			)
		end

		-- 后续逻辑统一使用 proxy:IsActive()
		if proxy:IsActive() then
			-- 累积未命中时间
			local lastUpdate = proxy.lastActiveUpdate
			local delta = curTime - lastUpdate
			if delta > 0 then
				proxy:UpdateActiveMissTime(delta)
			end

			-- 检查整体超时
			if proxy:GetActiveMissTime() >= PROXY_TIMEOUT_SECONDS then
				Debugger.Print(
					string.format(
						"[ProxyBehavior] Removing proxy %s, active miss time %.2f",
						tostring(proxy),
						proxy:GetActiveMissTime()
					),
					Debugger.LEVEL.INFO
				)
				proxy:Remove()
				continue
			end

			-- 检查骨骼超时
			if curTime - proxy:GetLastBoneHitTime() > BONE_TIMEOUT_SECONDS then
				proxy:AdvanceToNextBone()
				proxy:UpdateLastBoneHitTime()
				Debugger.Print(
					string.format("[ProxyBehavior] Proxy %s bone advanced", tostring(proxy)),
					Debugger.LEVEL.TRACE
				)
			end
		end

		-- 始终更新位置
		proxy:SetPos(proxy:GetIdealPos())
	end
end)
