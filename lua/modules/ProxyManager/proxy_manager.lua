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
			if IsValid(proxy) and IsValid(proxy.attacker) and proxy.logicVictim:IsValid() then
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

local function _HasExistingProxy(logicVictim, attacker)
	for proxy in ValidProxies() do
		if proxy.attacker ~= attacker then
			continue
		end

		if proxy.logicVictim and proxy.logicVictim:IsEqualTo(logicVictim) then
			return true
		end
	end
	return false
end

local function _CreateProxy(logicVictim, attacker)
	local proxy = ents.Create(PROXY_CLASS)
	if not IsValid(proxy) then
		return nil
	end
	proxy:Spawn()
	proxy:Init(logicVictim, attacker)

	Debugger.Print(
		string.format(
			"[ProxyManager] Created proxy %s for attacker %s, victim %s",
			tostring(proxy),
			tostring(attacker),
			tostring(logicVictim)
		),
		Debugger.LEVEL.INFO
	)

	return proxy
end

local function RequestProxy(victim, attacker)
	if not IsValid(attacker) or not attacker:IsNPC() or attacker:GetClass() == PROXY_CLASS then
		return nil
	end

	local logicVictim = LogicEntity.GetOrCreate(victim)
	if not logicVictim then
		return nil
	end

	-- 以下为 logicVictim
	if logicVictim:IsEqualTo(attacker) then
		return nil
	end

	if _HasExistingProxy(logicVictim, attacker) then
		return nil
	end

	local proxy = _CreateProxy(logicVictim, attacker)
	if IsValid(proxy) then
		table.insert(_proxies, proxy)
		return proxy
	end
end

ProxyManager.PROXY_CLASS = PROXY_CLASS
ProxyManager.RequestProxy = RequestProxy
ProxyManager.ValidProxies = ValidProxies
_G.ProxyManager = ProxyManager
