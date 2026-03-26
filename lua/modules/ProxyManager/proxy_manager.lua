-- lua\modules\ProxyManager\proxy_manager.lua
local Debugger = include("modules/util/debugger.lua")

local ProxyManager = {}

local PROXY_CLASS = "enp_proxy"

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

local function RequestProxy(victim, attacker)
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
		return proxy
	end
end

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

ProxyManager.PROXY_CLASS = PROXY_CLASS
ProxyManager.RequestProxy = RequestProxy
ProxyManager.ValidProxies = ValidProxies
_G.ProxyManager = ProxyManager
