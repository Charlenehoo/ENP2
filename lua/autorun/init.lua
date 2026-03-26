-- lua/autorun/init.lua
if SERVER then
	include("modules/ProxyManager/proxy_manager.lua")
	include("modules/ProxyManager/proxy_behavior.lua")
	include("modules/ProxyManager/ragdoll_linker.lua")
	include("modules/ProxyManager/proxy_monitor.lua")
	include("modules/auto_requester.lua")
	-- include("modules/bone_manager.lua")
end
