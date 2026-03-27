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

function ENT:Init(victim, attacker)
	self.victim = victim
	self.attacker = attacker

	self:ResetTimeout()

	self:SetNPCClass(CLASS_NONE)
	attacker:AddEntityRelationship(self, D_HT, 0)

	local InitPos = self:GetIdealPos()
	self:SetPos(InitPos)
	attacker:SetEnemy(self)
	attacker:UpdateEnemyMemory(self, InitPos)
end

-- 获取当前选中的骨骼位置（不自动前进）
function ENT:GetNextBonePos()
	local victim = self.victim
	if not IsValid(victim) then
		return vector_origin
	end

	-- 如果 victim 发生变化，清空缓存并重建
	if self.lastVictim ~= victim then
		self.validBones = nil
		self.currentBoneIndex = 0
		self.lastVictim = victim
	end

	-- 构建有效骨骼索引列表（仅首次或 victim 变化时）
	if not self.validBones then
		self.validBones = {}
		local rootPos = victim:GetPos()
		local boneCount = victim:GetBoneCount()
		for i = 0, boneCount - 1 do
			local bonePos, _ = victim:GetBonePosition(i)
			local v = bonePos - rootPos
			if v:LengthSqr() > EPS then
				table.insert(self.validBones, i)
			end
		end
		self.currentBoneIndex = 0
	end

	-- 无有效骨骼时回退到 EyePos
	if #self.validBones == 0 then
		return victim:EyePos()
	end

	-- 首次调用时，自动选中第一个骨骼
	if self.currentBoneIndex == 0 then
		self.currentBoneIndex = 1
	end

	local boneIndex = self.validBones[self.currentBoneIndex]
	local bonePos, _ = victim:GetBonePosition(boneIndex)
	return bonePos
end

-- 超时时前进到下一个骨骼
function ENT:AdvanceToNextBone()
	if not self.validBones or #self.validBones == 0 then
		return
	end
	-- 循环递增索引
	self.currentBoneIndex = (self.currentBoneIndex % #self.validBones) + 1
end

-- 计算理想位置（基于当前骨骼）
function ENT:GetIdealPos()
	local targetPos = self:GetNextBonePos()
	local direction = targetPos - self.attacker:GetShootPos()
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
