-- lua/entities/enp_proxy.lua
local PROXY_MODEL = "models/editor/cube_small.mdl"
local SCALE_1 = 0.03125
local MIN_OFFSET = 32
local EPS = 1e-6

AddCSLuaFile()
ENT.Base = "base_ai"
ENT.Type = "ai"

function ENT:Initialize() -- https://wiki.facepunch.com/gmod/ENTITY:Initialize
	self:SetModel(PROXY_MODEL)
	self:SetModelScale(SCALE_1)
	-- self:SetNoDraw(true)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
end

function ENT:GetNextBonePos()
	local victim = self.victim
	if not IsValid(victim) then
		return
	end

	-- 首次调用时构建有效骨骼索引列表（缓存）
	if not self.validBones then
		self.validBones = {}
		local rootPos = victim:GetPos()
		local boneCount = victim:GetBoneCount()
		for i = 0, boneCount - 1 do
			local bonePos, _ = victim:GetBonePosition(i)
			local v = bonePos - rootPos
			if v:LengthSqr() > EPS then
				table.insert(self.validBones, i) -- 存储索引，而非位置
			end
		end
		self.currentBoneIndex = 0 -- 当前使用的索引（0表示未开始）
	end

	-- 若无有效骨骼，回退到 EyePos
	if #self.validBones == 0 then
		return victim:EyePos()
	end

	-- 循环到下一个骨骼
	self.currentBoneIndex = (self.currentBoneIndex % #self.validBones) + 1
	local boneIndex = self.validBones[self.currentBoneIndex]
	local bonePos, _ = victim:GetBonePosition(boneIndex)
	return bonePos
end

function ENT:GetIdealPos()
	local direction = self.victim:EyePos() - self.attacker:GetShootPos() -- attacker -> victim
	direction:Normalize()
	return self.attacker:GetShootPos() + direction * MIN_OFFSET
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
