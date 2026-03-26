-- lua/autorun/init.lua
if SERVER then
	include("modules/proxy_manager.lua")
	include("modules/proxy_monitor.lua")
	include("modules/bone_manager.lua")
end
