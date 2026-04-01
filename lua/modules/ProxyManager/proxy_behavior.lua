-- lua/modules/ProxyManager/proxy_behavior.lua
local Debugger = include("modules/util/debugger.lua")

local BONE_TIMEOUT_SECONDS = 0.3  -- 骨骼未命中超时（秒）
local PROXY_TIMEOUT_SECONDS = 9.0 -- 代理整体未命中超时（秒）
local HEARTBEAD_TIMEOUT_SECONDS = 3.0

hook.Add("Tick", "ENP_ProxyBehavior_Tick", function()
	for proxy in ProxyManager.ValidProxies() do
		if not IsValid(proxy) then
			continue
		end

		local curTime = CurTime()

		if curTime - proxy:GetLastHeartbeatTime() > HEARTBEAD_TIMEOUT_SECONDS then
			Debugger.Print(
				string.format(
					"[ProxyBehavior] Removing proxy %s due to heartbeat timeout (%.1fs without heartbeat)",
					tostring(proxy),
					HEARTBEAD_TIMEOUT_SECONDS
				),
				Debugger.LEVEL.INFO
			)
			proxy:Remove()
			continue
		end

		-- 检查代理整体超时（基于最后一次命中时间）
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

		-- 检查当前骨骼超时（基于最后一次骨骼命中时间）
		if curTime - proxy:GetLastBoneHitTime() > BONE_TIMEOUT_SECONDS then
			proxy:AdvanceToNextBone()
			proxy:UpdateLastBoneHitTime()
			Debugger.Print(
				string.format(
					"[ProxyBehavior] Proxy %s advanced to next bone due to bone timeout (%.1fs without hit)",
					tostring(proxy),
					BONE_TIMEOUT_SECONDS
				),
				Debugger.LEVEL.TRACE
			)
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
		local curTime = CurTime()
		local oldHitTime = proxy:GetLastHitTime()
		local oldBoneHitTime = proxy:GetLastBoneHitTime()
		proxy:UpdateLastHitTime()
		Debugger.Print(
			string.format(
				"[ProxyBehavior] Proxy %s hit victim, extending life. Time since last hit: %.2fs, since last bone hit: %.2fs",
				tostring(proxy),
				curTime - oldHitTime,
				curTime - oldBoneHitTime
			),
			Debugger.LEVEL.TRACE
		)
	end
end)

hook.Add("ENP_Heartbeat", "ENP_ProxyBehavior_RecordHeartbeat", function(proxy)
	if not IsValid(proxy) then
		return
	end
	-- 更新代理的最后心跳时间
	proxy:UpdateLastHeartbeatTime()
	Debugger.Print(
		string.format(
			"[ProxyBehavior] Proxy %s received heartbeat",
			tostring(proxy)
		),
		Debugger.LEVEL.TRACE
	)
end)
