-- lua/autorun/init.lua
if SERVER then
	include("modules/LogicEntity/logic_entity.lua")
	include("modules/LogicEntity/logic_player.lua")
	include("modules/LogicEntity/logic_npc.lua")
	include("modules/LogicEntity/logic_dummy.lua")

	include("modules/ProxyManager/proxy_manager.lua")
	include("modules/ProxyManager/proxy_behavior.lua")
	include("modules/ProxyManager/proxy_monitor.lua")

	include("modules/events.lua")
end
