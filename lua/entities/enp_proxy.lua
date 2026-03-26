-- lua/entities/enp_proxy.lua
local PROXY_MODEL = "models/editor/cube_small.mdl"
local SCALE_1 = 0.03125

AddCSLuaFile()
ENT.Base = "base_ai"
ENT.Type = "ai"

function ENT:Initialize() -- https://wiki.facepunch.com/gmod/ENTITY:Initialize
	self:SetModel(PROXY_MODEL)
	self:SetModelScale(SCALE_1)
	-- self:SetNoDraw(true)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
end

function ENT:GetIdealPos()
	return (self.victim:EyePos() + self.attacker:GetShootPos()) / 2
end

function ENT:ResetTimeout()
	self.lastHitTime = CurTime()
	self.timeoutTriggered = false
end

function ENT:CheckTimeout(timeoutSeconds)
	if not self.lastHitTime then
		return false
	end
	if self.timeoutTriggered then
		return false
	end
	if CurTime() - self.lastHitTime > timeoutSeconds then
		self.timeoutTriggered = true
		return true
	end
	return false
end

function ENT:Init(victim, attacker)
	self.victim = victim
	self.originalVictim = victim
	self.attacker = attacker

	self:ResetTimeout()

	self:SetNPCClass(CLASS_NONE)
	attacker:AddEntityRelationship(self, D_HT, 0)

	local InitPos = self:GetIdealPos()
	self:SetPos(InitPos)
	attacker:SetEnemy(self)
	attacker:UpdateEnemyMemory(self, InitPos)
end
