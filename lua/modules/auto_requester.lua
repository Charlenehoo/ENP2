-- lua/modules/auto_requester.lua
local ProxyManager = _G.ProxyManager

-- 配置参数
local SCAN_INTERVAL = 0.5 -- 扫描间隔（秒），仅用于节流
local MAX_DIST = 8192 -- 最大距离（单位）
local SCAN_PER_TICK = 3 -- 每 Tick 最多处理多少个有效候选

-- 存储每个玩家的扫描状态
local playerStates = {}

-- 检查是否已存在代理（简单遍历，创建频率低）
local function HasProxy(ply, npc)
	for proxy in ProxyManager.ValidProxies() do
		if proxy.attacker == npc and proxy.victim == ply then
			return true
		end
	end
	return false
end

-- 玩家出生时初始化状态
hook.Add("PlayerSpawn", "ENP_AutoRequester_PlayerSpawn", function(ply)
	if not IsValid(ply) then
		return
	end
	if not playerStates[ply] then
		playerStates[ply] = {
			candidates = {}, -- 待处理的 NPC 列表
			currentIndex = 1,
			nextScanTime = 0, -- 下次允许扫描的时间
		}
	end
end)

-- 玩家离开时清理状态
hook.Add("PlayerDisconnected", "ENP_AutoRequester_Cleanup", function(ply)
	playerStates[ply] = nil
end)

-- 执行扫描：收集周围敌对 NPC 加入候选列表（不做去重）
local function ScanForNPCs(ply, state)
	local curTime = CurTime()
	if curTime < state.nextScanTime then
		return false -- 节流：尚未到达扫描时间
	end
	-- 更新下次允许扫描的时间
	state.nextScanTime = curTime + SCAN_INTERVAL

	local nearbyNPCs = ents.FindInSphere(ply:GetPos(), MAX_DIST)
	for _, npc in ipairs(nearbyNPCs) do
		if npc:IsNPC() and npc:Health() > 0 and npc:Disposition(ply) == D_HT then
			table.insert(state.candidates, npc)
		end
	end
	return true
end

-- 分帧处理候选 NPC，创建代理
-- 返回是否还有剩余候选（即列表未清空）
local function ProcessCandidates(ply, state)
	if #state.candidates == 0 then
		return false
	end

	local processedInTick = 0
	while state.currentIndex <= #state.candidates do
		local npc = state.candidates[state.currentIndex]
		state.currentIndex = state.currentIndex + 1

		-- 轻量级预筛选（不占分帧额度）
		if not IsValid(npc) or not npc:IsNPC() or npc:Health() <= 0 then
			continue
		end
		if HasProxy(ply, npc) then
			continue
		end

		-- 达到分帧上限，暂停处理，下次继续
		if processedInTick >= SCAN_PER_TICK then
			state.currentIndex = state.currentIndex - 1
			return true -- 还有候选未处理
		end
		processedInTick = processedInTick + 1

		-- 相对耗时的验证：距离、视线
		local plyPos = ply:GetPos()
		local npcPos = npc:GetPos()
		if plyPos:DistToSqr(npcPos) > MAX_DIST * MAX_DIST then
			continue
		end
		if not npc:TestPVS(ply) or not npc:Visible(ply) then
			continue
		end

		-- 创建代理
		ProxyManager.RequestProxy(ply, npc)
	end

	-- 列表已全部处理完毕，重置
	state.candidates = {}
	state.currentIndex = 1
	return false -- 无剩余候选
end

-- 全局 Think 钩子：协作执行扫描和创建
hook.Add("Think", "ENP_AutoRequester_Tick", function()
	for ply, state in pairs(playerStates) do
		if not IsValid(ply) then
			playerStates[ply] = nil
			continue
		end

		-- 1. 处理候选列表（消耗分帧）
		local hasRemaining = ProcessCandidates(ply, state)

		-- 2. 如果候选列表已空，尝试触发扫描（受节流限制）
		if not hasRemaining then
			ScanForNPCs(ply, state)
		end
	end
end)
