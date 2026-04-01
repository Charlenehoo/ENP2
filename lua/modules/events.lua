local MAX_PROCESS_TIME_PER_TICK = 0.005
local MAX_DIST = 8192

local Backlog = {}

local function ProcessEntity(ent, ply)
	if not IsValid(ent) then return false end
	if not ent:IsNPC() then return false end

	local distSqr = ply:GetPos():DistToSqr(ent:GetPos())
	if distSqr > MAX_DIST * MAX_DIST then return false end

	if ent:Disposition(ply) ~= D_HT then return false end

	local gunTipPos = ply:GetShootPos() + ply:GetAimVector() * 32

	if not ent:TestPVS(gunTipPos) then return false end
	if not ent:IsLineOfSightClear(gunTipPos) then return false end

	ProxyManager.RequestProxy(ply, ent)
	return true
end

local function RefillBacklog()
	Backlog = ents.GetAll() -- 直接赋值，无需遍历
end

local function ProcessBacklogWithLimit(startTime, ply)
	while #Backlog > 0 do
		local ent = table.remove(Backlog, 1)
		ProcessEntity(ent, ply)
		if SysTime() - startTime > MAX_PROCESS_TIME_PER_TICK then
			return true
		end
	end
	return false
end

hook.Add("PlayerInitialSpawn", "ENP_PlayerInitialSpawn", function(ply)
	hook.Add("Tick", "EntityThreatProcessor", function()
		local startTime = SysTime()

		if #Backlog > 0 then
			ProcessBacklogWithLimit(startTime, ply)
		else
			RefillBacklog()
			if SysTime() - startTime <= MAX_PROCESS_TIME_PER_TICK then
				ProcessBacklogWithLimit(startTime, ply)
			end
		end
	end)
end)
