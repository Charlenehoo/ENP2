-- lua/autorun/init.lua
if SERVER then
	include("modules/LogicEntity/logic_entity.lua")
	local LogicPlayer = include("modules/LogicEntity/logic_player.lua")
	LogicPlayer.Init() -- register hooks
	local LogicNPC = include("modules/LogicEntity/logic_npc.lua")
	LogicNPC.Init() -- register hooks
	include("modules/ProxyManager/proxy_manager.lua")
	include("modules/ProxyManager/proxy_behavior.lua")
	include("modules/ProxyManager/proxy_monitor.lua")
	include("modules/auto_requester.lua")
	-- include("modules/bone_manager.lua")
end
