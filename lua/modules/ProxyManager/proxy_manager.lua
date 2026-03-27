-- lua\modules\ProxyManager\proxy_manager.lua
local Debugger = include("modules/util/debugger.lua")

local ProxyManager = {}

local PROXY_CLASS = "enp_proxy"

local _proxies = {}

local function ValidProxies()
	local i = #_proxies
	return function()
		while i >= 1 do
			local proxy = _proxies[i]
			i = i - 1
			if IsValid(proxy) and IsValid(proxy.victim) and IsValid(proxy.attacker) then
				return proxy
			else
				if IsValid(proxy) then
					proxy:Remove()
				end
				table.remove(_proxies, i + 1)
			end
		end
		return nil
	end
end

local function _HasExistingProxy(victim, attacker)
	for proxy in ValidProxies() do
		if proxy.attacker ~= attacker then
			continue
		end

		local proxiedVictim = proxy.victim
		local originalVictim = proxy._originalVictim

		-- 确定当前代理所代表的逻辑玩家
		local logicPlayer = nil
		if IsValid(proxiedVictim) and proxiedVictim:IsRagdoll() then
			-- 代理的 victim 是 ragdoll，则逻辑玩家应该是 originalVictim
			logicPlayer = originalVictim
		else
			-- 否则，代理的 victim 就是逻辑玩家（活体玩家）
			logicPlayer = proxiedVictim
		end

		-- 如果逻辑玩家无效，跳过
		if not IsValid(logicPlayer) or not logicPlayer:IsPlayer() then
			continue
		end

		-- 判断请求的 victim 是否代表同一个逻辑玩家
		if IsValid(victim) then
			if victim:IsPlayer() then
				-- 请求是玩家：直接比较
				if victim == logicPlayer then
					return true
				end
			elseif victim:IsRagdoll() then
				-- 请求是 ragdoll：检查它是否属于该逻辑玩家
				local ragdoll = logicPlayer:GetRagdollEntity()
				if IsValid(ragdoll) and ragdoll == victim then
					return true
				end
			end
		end
	end
	return false
end

local function _CreateProxy(victim, attacker)
	local proxy = ents.Create(PROXY_CLASS)
	if not IsValid(proxy) then
		return
	end
	proxy:Spawn()
	proxy:Init(victim, attacker)
	return proxy
end

local function RequestProxy(victim, attacker)
	if not IsValid(victim) or victim:GetClass() == PROXY_CLASS then
		return
	end
	if not IsValid(attacker) or not attacker:IsNPC() or attacker:GetClass() == PROXY_CLASS then
		return
	end

	if _HasExistingProxy(victim, attacker) then
		Debugger.Print(
			string.format(
				"[ProxyManager] RequestProxy rejected: existing proxy for victim %s (or its ragdoll) and attacker %s",
				tostring(victim),
				tostring(attacker)
			),
			Debugger.LEVEL.TRACE
		)
		return nil
	end

	local proxy = _CreateProxy(victim, attacker)
	if IsValid(proxy) then
		table.insert(_proxies, proxy)
		Debugger.Print(string.format("[ProxyManager] Created proxy %s", tostring(proxy)), Debugger.LEVEL.INFO)
		return proxy
	end
end

ProxyManager.PROXY_CLASS = PROXY_CLASS
ProxyManager.RequestProxy = RequestProxy
ProxyManager.ValidProxies = ValidProxies
_G.ProxyManager = ProxyManager
