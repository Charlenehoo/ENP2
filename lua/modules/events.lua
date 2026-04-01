--[[
    威胁评估系统（谓词注册 + 独立冷却）
    - 每个检查条件可独立设置冷却时间（宽容延迟）
    - 冷却期间该条件失败视为临时失败，不触发事件
    - 只有持续失败超过冷却时间才真正触发丢失事件
    - 每帧受时间预算控制，避免卡顿
]]

-- ===== 配置参数 =====
local MAX_PROCESS_TIME_PER_TICK = 0.005 -- 每帧最大处理时间（秒）
local MAX_DIST = 1000 -- 基础距离阈值（用于默认距离谓词）

-- ===== 谓词注册系统 =====
local ThreatPredicates = {} -- 存储所有谓词 { func, hookName, cooldown }

-- 注册一个新谓词
-- @param name string       名称（调试用）
-- @param func function     检查函数(ent, ply) -> boolean
-- @param hookName string   失败时触发的全局钩子名
-- @param cooldown number   冷却时间（秒），谓词失败后需持续失败这么久才触发事件
function RegisterThreatPredicate(name, func, hookName, cooldown)
	ThreatPredicates[#ThreatPredicates + 1] = {
		func = func,
		hookName = hookName,
		cooldown = cooldown or 0.3, -- 默认0.3秒
	}
end

-- 清空所有谓词（谨慎使用）
function ClearThreatPredicates()
	ThreatPredicates = {}
end

-- ===== 默认谓词（按性能开销升序） =====
RegisterThreatPredicate("DistanceCheck", function(ent, ply)
	local distSqr = ply:GetPos():DistToSqr(ent:GetPos())
	return distSqr <= MAX_DIST * MAX_DIST
end, "OnThreatGoFar", 0.3)

RegisterThreatPredicate("PVSCheck", function(ent, ply)
	return ent:TestPVS(ply)
end, "OnThreatLostSight", 0.2)

RegisterThreatPredicate("DispositionCheck", function(ent, ply)
	return ent:IsNPC() and ent:Disposition(ply) == D_HT
end, "OnThreatLost", 0.1)

RegisterThreatPredicate("VisibleCheck", function(ent, ply)
	return ent:Visible(ply)
end, "OnThreatLostSight", 0.3)

-- ===== 核心数据结构 =====
local Backlog = {} -- 待处理的实体队列（每轮刷新）
local lastThreats = {} -- 上一轮完整扫描后确认的威胁实体集合
local currentThreats = {} -- 本轮已确认的威胁实体（扫描过程中累积）
local entityFailStartTime = {} -- [ent][predIndex] = 失败开始时间
local entityFinalFailHook = {} -- [ent] = 最终失败时的hook名（用于丢失事件）

local function GetLocalPlayer()
	return LocalPlayer()
end

-- 重置本轮累积数据（开始新一轮扫描时调用）
local function ResetCurrentThreats()
	currentThreats = {}
	entityFinalFailHook = {}
	-- 注意：entityFailStartTime 不清空，因为它是跨帧的冷却计时器
end

-- 检查单个实体，更新其威胁状态（使用谓词冷却机制）
-- 返回值：(isThreat, failHook)
--  isThreat: 当前是否应视为威胁（所有谓词均通过或处于冷却期内）
--  failHook: 如果最终失败，是哪个谓词导致的（仅当 isThreat==false 时有意义）
local function EvaluateEntity(ent, ply)
	if not IsValid(ent) then
		return false, nil
	end

	local now = SysTime()
	local anyRealFail = false
	local firstFailHook = nil

	-- 确保失败时间表存在
	if not entityFailStartTime[ent] then
		entityFailStartTime[ent] = {}
	end
	local failTimes = entityFailStartTime[ent]

	for idx, pred in ipairs(ThreatPredicates) do
		local passed = pred.func(ent, ply)
		if passed then
			-- 通过检查：清除该谓词的失败记录
			failTimes[idx] = nil
		else
			-- 失败：记录失败开始时间（如果尚未记录）
			if not failTimes[idx] then
				failTimes[idx] = now
			end
			local failDuration = now - failTimes[idx]
			if failDuration >= pred.cooldown then
				-- 超过冷却时间，确认为真正失败
				anyRealFail = true
				if not firstFailHook then
					firstFailHook = pred.hookName
				end
			else
				-- 仍在冷却期内，视为临时失败，不计入真正失败
			end
		end
	end

	-- 清理没有失败记录的实体条目（避免内存泄漏）
	if next(failTimes) == nil then
		entityFailStartTime[ent] = nil
	end

	if anyRealFail then
		return false, firstFailHook
	else
		return true, nil
	end
end

-- 填充队列：获取所有实体快照
local function RefillBacklog()
	Backlog = ents.GetAll()
	ResetCurrentThreats()
end

-- 处理队列中的实体（受时间预算限制）
-- 返回值: true 表示队列已清空，false 表示还有剩余
local function ProcessBacklogWithLimit(startTime, ply)
	while #Backlog > 0 do
		local ent = table.remove(Backlog, 1)
		local isThreat, failHook = EvaluateEntity(ent, ply)
		if isThreat then
			currentThreats[ent] = true
			-- 如果之前有失败记录，清除（因为现在又成为威胁了）
			entityFinalFailHook[ent] = nil
		else
			if failHook then
				entityFinalFailHook[ent] = failHook
			end
			-- 确保不在 currentThreats 中（如果之前是威胁，本轮失败后移除）
			currentThreats[ent] = nil
		end
		if SysTime() - startTime > MAX_PROCESS_TIME_PER_TICK then
			return false -- 时间用尽，队列未清空
		end
	end
	return true -- 队列已清空
end

-- 比较新旧威胁集合，触发相应事件
local function FireEvents(ply)
	local newThreats = currentThreats
	local oldThreats = lastThreats

	-- 新增威胁
	for ent, _ in pairs(newThreats) do
		if not oldThreats[ent] then
			hook.Run("OnNewThreat", ent, ply)
		end
	end

	-- 丢失威胁（根据记录的失败hook触发具体事件）
	for ent, _ in pairs(oldThreats) do
		if not newThreats[ent] then
			local failHook = entityFinalFailHook[ent]
			if failHook then
				hook.Run(failHook, ent, ply)
			else
				hook.Run("OnThreatLost", ent, ply) -- 兜底
			end
			-- 清理该实体的失败记录（可选）
			entityFailStartTime[ent] = nil
			entityFinalFailHook[ent] = nil
		end
	end

	lastThreats = newThreats
	ResetCurrentThreats()
end

-- 每帧主逻辑
hook.Add("Think", "ThreatEvaluationSystem", function()
	local ply = GetLocalPlayer()
	if not IsValid(ply) then
		return
	end

	local startTime = SysTime()

	if #Backlog > 0 then
		local finished = ProcessBacklogWithLimit(startTime, ply)
		if finished then
			FireEvents(ply)
		end
	else
		RefillBacklog()
		-- 若填充后仍有时间预算，立即处理一部分
		if SysTime() - startTime <= MAX_PROCESS_TIME_PER_TICK then
			local finished = ProcessBacklogWithLimit(startTime, ply)
			if finished then
				FireEvents(ply)
			end
		end
	end
end)
