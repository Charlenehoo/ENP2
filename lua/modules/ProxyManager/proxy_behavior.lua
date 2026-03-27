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
	end
end)

hook.Add("ENP_ProxyTimeout", "ENP_ProxyBehavior_AdvanceBone", function(proxy)
	if not IsValid(proxy) then
		return
	end

	PrintProxyStats(proxy, HITRATE_WINDOW)

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

	local shouldRemove = false
	local removeReasonBase = ""

	if result == Predict.PenetrationResult.CANNOT_PENETRATE then
		shouldRemove = true
		removeReasonBase = string.format("cannot penetrate (pen=%f, maxLayers=%d)", pen, maxLayers)
	elseif result == Predict.PenetrationResult.UNCERTAIN then
		local keepProxy = false
		local boneRates = {}
		if proxy.validBones then
			for _, boneIndex in ipairs(proxy.validBones) do
				local hitRate = proxy:GetHitRate(boneIndex, HITRATE_WINDOW)
				local rateStr = hitRate and string.format("%.2f", hitRate) or "nil"
				table.insert(boneRates, string.format("bone%d:%s", boneIndex, rateStr))
				if hitRate and hitRate >= HITRATE_THRESHOLD then
					keepProxy = true
				end
			end
		end
		if not keepProxy then
			shouldRemove = true
			local ratesStr = table.concat(boneRates, ", ")
			removeReasonBase = string.format(
				"uncertain, all bone hit rates (%s) below threshold %.2f in window %.2f",
				ratesStr,
				HITRATE_THRESHOLD,
				HITRATE_WINDOW
			)
		end
	end

	if shouldRemove then
		LogProxyRemoval(proxy, walls, removeReasonBase)
		proxy:Remove()
	end
end)
