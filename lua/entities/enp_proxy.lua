-- lua/entities/enp_proxy.lua
local PROXY_MODEL = "models/editor/cube_small.mdl"
local SCALE_1 = 0.03125
local MIN_OFFSET = 32
local EPS = 1e-6

AddCSLuaFile()
ENT.Base = "base_ai"
ENT.Type = "ai"

function ENT:Initialize()
	self:SetModel(PROXY_MODEL)
	self:SetModelScale(SCALE_1)
	-- self:SetNoDraw(true)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
end

function ENT:Init(logicVictim, attacker)
	self.logicVictim = logicVictim
	self.attacker = attacker

	self.lastHitTime = CurTime()
	self.lastBoneHitTime = CurTime()
	self.lastShotTime = CurTime()
	self.active = false -- 当前是否活跃
	self.activeMissTime = 0 -- 活跃期间累积未命中时间
	self.lastActiveUpdate = 0 -- 上次更新活跃计时的时间

	self:SetNPCClass(CLASS_NONE)
	attacker:AddEntityRelationship(self, D_HT, 0)

	local InitPos = self:GetIdealPos()
	self:SetPos(InitPos)
	attacker:SetEnemy(self)
	attacker:UpdateEnemyMemory(self, InitPos)
end

-- 计算理想位置（基于当前骨骼）
function ENT:GetIdealPos()
	local targetPos = self:GetNextBonePos()
	local direction = targetPos - self.attacker:GetShootPos()
	direction:Normalize()
	return self.attacker:GetShootPos() + direction * MIN_OFFSET
end

-- 获取当前选中的骨骼位置（不自动前进）
function ENT:GetNextBonePos()
	local logicVictim = self.logicVictim

	if self.lastLogicVictimModel ~= self.logicVictim:GetModel() then
		self.validBones = nil
		self.currentBoneIndex = 0
		self.lastLogicVictimModel = self.logicVictim:GetModel()
	end

	-- 构建有效骨骼索引列表（仅首次或模型变化时）
	if not self.validBones then
		self.validBones = {}
		local rootPos = logicVictim:GetPos()
		local boneCount = logicVictim:GetBoneCount()
		for i = 0, boneCount - 1 do
			local bonePos, _ = logicVictim:GetBonePosition(i)
			local v = bonePos - rootPos
			if v:LengthSqr() > EPS then
				table.insert(self.validBones, i)
			end
		end
		self.currentBoneIndex = 0
	end

	-- 无有效骨骼时回退到 EyePos
	if #self.validBones == 0 then
		return logicVictim:EyePos()
	end

	-- 首次调用时，自动选中第一个骨骼
	if self.currentBoneIndex == 0 then
		self.currentBoneIndex = 1
	end

	local boneIndex = self.validBones[self.currentBoneIndex]
	local bonePos, _ = logicVictim:GetBonePosition(boneIndex)
	return bonePos
end

-- 前进到下一个骨骼（循环）
function ENT:AdvanceToNextBone()
	if not self.validBones or #self.validBones == 0 then
		return
	end
	self.currentBoneIndex = (self.currentBoneIndex % #self.validBones) + 1
end

function ENT:UpdateLastBoneHitTime()
	self.lastBoneHitTime = CurTime()
end

function ENT:GetLastHitTime()
	return self.lastHitTime
end

function ENT:GetLastBoneHitTime()
	return self.lastBoneHitTime
end

function ENT:GetLastShotTime()
	return self.lastShotTime
end

-- 新增方法
function ENT:SetActive(active)
	self.active = active
	if active then
		self.lastActiveUpdate = CurTime()
	end
end

function ENT:IsActive()
	return self.active
end

function ENT:UpdateActiveMissTime(currentTime)
	if currentTime <= self.lastActiveUpdate then
		return
	end
	local delta = currentTime - self.lastActiveUpdate
	self.activeMissTime = self.activeMissTime + delta
	self.lastActiveUpdate = currentTime
end

function ENT:ResetActiveMissTime()
	self.activeMissTime = 0
end

function ENT:GetActiveMissTime()
	return self.activeMissTime
end

function ENT:UpdateLastHitTime()
	self.lastHitTime = CurTime()
	self:ResetActiveMissTime()
	self:UpdateLastBoneHitTime()
end

function ENT:UpdateLastShotTime()
	self.lastShotTime = CurTime()
end
