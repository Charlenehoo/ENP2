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
		self.victim = e
		return true
	else
		self.victim = Entity(1)
		return false
	end
end

function TOOL:Reload(trace)
	ProxyManager.RequestProxy(self.victim, self.attacker)
end

function TOOL:Think() end
