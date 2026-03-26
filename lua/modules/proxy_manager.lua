-- lua/modules/proxy_manager.lua
local Debugger = include("modules/debugger.lua")

ProxyManager = {}
ProxyManager.PROXY_CLASS = "enp_proxy"

local PROXY_CLASS = ProxyManager.PROXY_CLASS
local TIMEOUT_SECONDS = 3.0

local _proxies = {}

local function _CreateProxy(victim, attacker)
	local proxy = ents.Create(PROXY_CLASS)
	if not IsValid(proxy) then
		return
	end
	proxy:Spawn()
	proxy:Init(victim, attacker)
	return proxy
end

function ProxyManager.RequestProxy(victim, attacker)
	if not IsValid(victim) or victim:GetClass() == PROXY_CLASS then
		return
	end
	if not IsValid(attacker) or not attacker:IsNPC() or attacker:GetClass() == PROXY_CLASS then
		return
	end

	local proxy = _CreateProxy(victim, attacker)
	if IsValid(proxy) then
		table.insert(_proxies, proxy)
		Debugger.Print(string.format("[ProxyManager] Created proxy %s", tostring(proxy)), Debugger.LEVEL.INFO)
	end
end

-- Tick 钩子修改
hook.Add("Tick", "ENP_ProxyManager_Update", function()
	for i = #_proxies, 1, -1 do
		local proxy = _proxies[i]
		if not IsValid(proxy) then
			table.remove(_proxies, i)
			continue
		end

		local victim = proxy.victim
		local attacker = proxy.attacker
		if not (IsValid(victim) and IsValid(attacker)) then
			proxy:Remove()
			table.remove(_proxies, i)
			continue
		end

		if proxy:CheckTimeout(TIMEOUT_SECONDS) then
			hook.Run("ENP_ProxyTimeout", proxy)
			if not IsValid(proxy) then
				table.remove(_proxies, i)
				continue
			end
		end

		proxy:SetPos(proxy:GetIdealPos())
	end
end)

hook.Add("ENP_ProxyTimeout", "ENP_Proxy_AdvanceBone", function(proxy)
	if IsValid(proxy) then
		proxy:AdvanceToNextBone() -- 前进到下一个骨骼
		proxy:ResetTimeout() -- 重置超时，开始新一轮计时
		Debugger.Print(
			string.format("[ProxyManager] Proxy %s advanced to next bone and reset timeout", tostring(proxy)),
			Debugger.LEVEL.TRACE
		)
	end
end)

hook.Add("ENP_BulletHit", "ENP_Proxy_UpdateHitTime", function(proxy, isVictimHit, tr)
	if not IsValid(proxy) then
		return
	end
	if isVictimHit then
		proxy:ResetTimeout()
	end
end)

-- 辅助函数：将指定 owner 对应的第一个 proxy 的 victim 更新为 ragdoll
-- 调用者必须保证 owner 和 ragdoll 有效
local function _UpdateProxyVictim(owner, ragdoll)
	for _, proxy in ipairs(_proxies) do
		if IsValid(proxy) and proxy.victim == owner then
			proxy.victim = ragdoll
			Debugger.Print(
				string.format(
					"[ProxyManager] Updated victim of proxy %s to ragdoll %s",
					tostring(proxy),
					tostring(ragdoll)
				),
				Debugger.LEVEL.TRACE
			)
			break
		end
	end
end

-- NPC 及通用 ragdoll 生成钩子
hook.Add("CreateEntityRagdoll", "ENP_ProxyManager_RagdollLink_NPC", function(owner, ragdoll)
	if not IsValid(owner) or not IsValid(ragdoll) then
		return
	end
	_UpdateProxyVictim(owner, ragdoll)
end)

-- 玩家死亡钩子（ragdoll 已生成，无需延迟）
hook.Add("PostPlayerDeath", "ENP_ProxyManager_RagdollLink_Player", function(player)
	if not IsValid(player) then
		return
	end
	local ragdoll = player:GetRagdollEntity()
	if IsValid(ragdoll) then
		_UpdateProxyVictim(player, ragdoll)
	end
end)

-- 玩家重生钩子：通过 originalVictim 匹配并恢复 victim 为玩家实体
hook.Add("PlayerSpawn", "ENP_ProxyManager_PlayerRespawn", function(player)
	if not IsValid(player) then
		Debugger.Print("[ProxyManager] PlayerSpawn: player invalid, skipping", Debugger.LEVEL.WARN)
		return
	end

	Debugger.Print(
		string.format("[ProxyManager] PlayerSpawn: player %s respawned, checking proxies...", tostring(player)),
		Debugger.LEVEL.INFO
	)

	local updatedCount = 0
	for i, proxy in ipairs(_proxies) do
		-- 有效性检查
		if not IsValid(proxy) then
			Debugger.Print(string.format("[ProxyManager]   Proxy #%d is invalid, skipping", i), Debugger.LEVEL.TRACE)
			continue
		end

		-- 检查 originalVictim 是否匹配
		local original = proxy.originalVictim
		if not IsValid(original) or original ~= player then
			Debugger.Print(
				string.format(
					"[ProxyManager]   Proxy #%d (%s) originalVictim %s does not match player %s, skipping",
					i,
					tostring(proxy),
					tostring(original),
					tostring(player)
				),
				Debugger.LEVEL.TRACE
			)
			continue
		end

		-- 匹配成功，更新 victim 为玩家实体
		if IsValid(player) then
			proxy.victim = player
			proxy:ResetTimeout()
			Debugger.Print(
				string.format(
					"[ProxyManager]   Proxy #%d (%s) UPDATED: victim from %s to player %s (original=%s)",
					i,
					tostring(proxy),
					tostring(proxy.victim),
					tostring(player),
					tostring(original)
				),
				Debugger.LEVEL.INFO
			)
			updatedCount = updatedCount + 1
		else
			Debugger.Print(
				string.format("[ProxyManager]   Proxy #%d (%s) player invalid, cannot update", i, tostring(proxy)),
				Debugger.LEVEL.WARN
			)
		end
	end

	if updatedCount == 0 then
		Debugger.Print("[ProxyManager] PlayerSpawn: no proxies updated for this player", Debugger.LEVEL.INFO)
	else
		Debugger.Print(
			string.format(
				"[ProxyManager] PlayerSpawn: updated %d proxies for player %s",
				updatedCount,
				tostring(player)
			),
			Debugger.LEVEL.INFO
		)
	end
end)
