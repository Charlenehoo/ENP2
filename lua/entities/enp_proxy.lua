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

	self:InitHitStats()

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

function ENT:InitHitStats()
	if not self.hitStats then
		self.hitStats = {}
	end
	if not self.nextShotID then
		self.nextShotID = 1
	end
end

-- 记录一次射击，返回一个唯一 ID
function ENT:RecordShot(boneIndex)
	self:InitHitStats()
	if not self.hitStats[boneIndex] then
		self.hitStats[boneIndex] = {}
	end
	local shotID = self.nextShotID
	self.nextShotID = self.nextShotID + 1
	if self.nextShotID > 1048576 then -- 2^20
		self.nextShotID = 1
	end
	table.insert(self.hitStats[boneIndex], {
		id = shotID,
		time = CurTime(),
		hit = false,
	})
	return shotID
end

-- 根据 ID 将对应的射击记录标记为命中
function ENT:RecordHit(boneIndex, shotID)
	if not self.hitStats or not self.hitStats[boneIndex] then
		return
	end
	local queue = self.hitStats[boneIndex]
	for _, rec in ipairs(queue) do
		if rec.id == shotID then
			rec.hit = true
			break
		end
	end
end

-- 获取指定骨骼在时间窗口内的命中率（自动清理队首超时记录）
function ENT:GetHitRate(boneIndex, window)
	if not self.hitStats or not self.hitStats[boneIndex] then
		return nil
	end
	local queue = self.hitStats[boneIndex]
	local cutoff = CurTime() - window
	-- 只清理队首的超时记录（FIFO 特性）
	while #queue > 0 and queue[1].time < cutoff do
		table.remove(queue, 1)
	end
	if #queue == 0 then
		return nil
	end
	local total = 0
	local hits = 0
	for _, rec in ipairs(queue) do
		total = total + 1
		if rec.hit then
			hits = hits + 1
		end
	end
	return hits / total
end

-- 获取所有骨骼在时间窗口内的总体命中率（自动清理各骨骼的过期记录）
function ENT:GetOverallHitRate(window)
	if not self.hitStats then
		return nil
	end
	local cutoff = CurTime() - window
	local totalShots = 0
	local totalHits = 0
	for boneIndex, queue in pairs(self.hitStats) do
		-- 清理该骨骼的过期记录（保持与 GetHitRate 一致的 FIFO 清理）
		while #queue > 0 and queue[1].time < cutoff do
			table.remove(queue, 1)
		end
		-- 统计有效记录
		for _, rec in ipairs(queue) do
			totalShots = totalShots + 1
			if rec.hit then
				totalHits = totalHits + 1
			end
		end
	end
	if totalShots == 0 then
		return nil
	end
	return totalHits / totalShots
end
