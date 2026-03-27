-- lua/modules/ProxyManager/proxy_behavior.lua
local Debugger = include("modules/util/debugger.lua")
local Wall = include("modules/util/wall.lua")
local Predict = include("modules/util/predict.lua")

local TIMEOUT_SECONDS = 0.15
local HITRATE_WINDOW = 3.0
local HITRATE_THRESHOLD = 0.1
local REMOVAL_DELAY = 3.0

local lastPrintTime = {}

local function PrintProxyStats(proxy, window)
	local curTime = CurTime()
	local proxyId = proxy:EntIndex()
	if not lastPrintTime[proxyId] or curTime - lastPrintTime[proxyId] >= window then
		lastPrintTime[proxyId] = curTime

		local victim = proxy.victim
		local attacker = proxy.attacker
		local victimName = IsValid(victim) and (victim:IsPlayer() and victim:Name() or tostring(victim)) or "none"
		local attackerName = IsValid(attacker) and attacker:GetClass() or "none"

		local boneRates = {}
		local totalShots = 0
		local totalHits = 0

		if proxy.validBones then
			for _, boneIndex in ipairs(proxy.validBones) do
				local hitRate = proxy:GetHitRate(boneIndex, window)
				if hitRate then
					table.insert(boneRates, string.format("bone%d:%.2f", boneIndex, hitRate))
					-- 累计总体统计
					if proxy.hitStats and proxy.hitStats[boneIndex] then
						for _, rec in ipairs(proxy.hitStats[boneIndex]) do
							totalShots = totalShots + 1
							if rec.hit then
								totalHits = totalHits + 1
							end
						end
					end
				end
			end
		end

		local overallRate = totalShots > 0 and (totalHits / totalShots) or nil
		local overallStr = overallRate and string.format("%.2f", overallRate) or "no data"

		Debugger.Print(
			string.format(
				"[ProxyBehavior] Proxy %s (attacker=%s, victim=%s) stats in last %.1fs: bones=[%s] overall=%s (hits=%d/total=%d)",
				tostring(proxy),
				attackerName,
				victimName,
				window,
				table.concat(boneRates, ", "),
				overallStr,
				totalHits,
				totalShots
			),
			Debugger.LEVEL.INFO
		)
	end
end

local function LogProxyRemoval(proxy, walls, removeReasonBase)
	local wallsStr = ""
	if walls and #walls > 0 then
		local wallDesc = {}
		for i, w in ipairs(walls) do
			table.insert(
				wallDesc,
				string.format(
					"layer%d: thickness=%.2f, matType=%d, angle=%.2f",
					i,
					w.thickness,
					w.matType,
					w.incidentAngle
				)
			)
		end
		wallsStr = " (walls=[" .. table.concat(wallDesc, "; ") .. "])"
	end
	Debugger.Print(
		string.format("[ProxyBehavior] Removing proxy %s: %s%s", tostring(proxy), removeReasonBase, wallsStr),
		Debugger.LEVEL.INFO
	)
	lastPrintTime[proxy:EntIndex()] = nil
end

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
		-- Cancel any pending removal that was scheduled based on heuristics
		if proxy.pendingRemoval then
			Debugger.Print(
				string.format(
					"[ProxyBehavior] Cancelling pending removal for proxy %s due to bullet hit",
					tostring(proxy)
				),
				Debugger.LEVEL.INFO
			)
			proxy.pendingRemoval = nil
			proxy.removalCheckTime = nil
		end
	end
end)

hook.Add("ENP_ProxyTimeout", "ENP_ProxyBehavior_AdvanceBone", function(proxy)
	if not IsValid(proxy) then
		return
	end

	PrintProxyStats(proxy, HITRATE_WINDOW)
	proxy:AdvanceToNextBone()
	proxy:ResetTimeout()

	local attacker = proxy.attacker
	local victim = proxy.victim
	if not IsValid(attacker) or not IsValid(victim) then
		return
	end

	local weapon = attacker:GetActiveWeapon()
	if not IsValid(weapon) or not weapon.ARC9 then
		return
	end

	local pen = weapon:GetProcessedValue("Penetration")
	local maxLayers = weapon.MaxPenetrationLayers or 3
	if not pen or pen <= 0 then
		return
	end

	local attackerPos = attacker:GetShootPos()
	local victimPos = victim:GetPos()

	local walls = Wall.GetWallInfoAlongLine(attacker, victim, attackerPos, victimPos, proxy)
	local result = Predict.PredictPenetration(walls, pen, maxLayers)
	local overallHitRate = proxy:GetOverallHitRate(HITRATE_WINDOW)

	-- 基于穿透结果和命中率确定是否应移除
	local shouldRemoveNow = false
	local removalReason = nil
	if result == Predict.PenetrationResult.CANNOT_PENETRATE then
		shouldRemoveNow = true
		removalReason = string.format("cannot penetrate (pen=%f, maxLayers=%d)", pen, maxLayers)
	elseif result == Predict.PenetrationResult.UNCERTAIN then
		local keepProxy = false
		if proxy.validBones then
			for _, boneIndex in ipairs(proxy.validBones) do
				local hitRate = proxy:GetHitRate(boneIndex, HITRATE_WINDOW)
				if hitRate and hitRate >= HITRATE_THRESHOLD then
					keepProxy = true
					break
				end
			end
		end
		shouldRemoveNow = not keepProxy
		if shouldRemoveNow then
			removalReason = "uncertain, all bone hit rates below threshold"
		end
	else -- CAN_PENETRATE
		shouldRemoveNow = false
	end

	if overallHitRate ~= nil and overallHitRate == 0 then
		shouldRemoveNow = true
		removalReason = string.format("overall hit rate is 0") --  (hits=%d, total=%d)", totalHits, totalShots) -- 注意这里 totalHits/totalShots 需要从统计中获取，可改用字符串
	end

	local pending = proxy.pendingRemoval
	local checkTime = proxy.removalCheckTime

	if pending then
		-- 持续检测：条件不再满足则立即取消 pending
		if not shouldRemoveNow then
			Debugger.Print(
				string.format(
					"[ProxyBehavior] Cancelling pending removal for proxy %s (condition cleared during pending)",
					tostring(proxy)
				),
				Debugger.LEVEL.INFO
			)
			proxy.pendingRemoval = nil
			proxy.removalCheckTime = nil
			return
		end

		-- 条件仍然满足，检查是否到达移除时间
		if CurTime() >= checkTime then
			LogProxyRemoval(proxy, walls, "confirmed after delay")
			proxy:Remove()
			proxy.pendingRemoval = nil
			proxy.removalCheckTime = nil
		end
	else
		-- 第一次超时，需要进入 pending 状态
		if shouldRemoveNow then
			Debugger.Print(
				string.format(
					"[ProxyBehavior] Proxy %s entering pending removal (reason: %s), will recheck in %.1f seconds",
					tostring(proxy),
					removalReason or "unknown",
					REMOVAL_DELAY
				),
				Debugger.LEVEL.INFO
			)
			proxy.pendingRemoval = true
			proxy.removalCheckTime = CurTime() + REMOVAL_DELAY
		end
	end
end)
