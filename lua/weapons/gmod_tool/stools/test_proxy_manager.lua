-- lua/weapons/gmod_tool/stools/test_proxy_manager.lua

TOOL.Category = "Test"
TOOL.Name = "Test ProxyManager"

function TOOL:LeftClick(trace)
	local e = trace.Entity
	if IsValid(e) and e:IsNPC() then
		self.attacker = e
		return true
	else
		return false
	end
end

function TOOL:RightClick(trace)
	local e = trace.Entity
	print("RightClick entity:", e, e:GetClass())
	if IsValid(e) then
		ProxyManager.RequestProxy(e, self.attacker)
		return true
	else
		ProxyManager.RequestProxy(Entity(1), self.attacker)
		return false
	end
end

function TOOL:Reload(trace) end

function TOOL:Think() end
