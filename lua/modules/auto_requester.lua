-- -- lua/modules/auto_requester.lua
-- local ProxyManager = _G.ProxyManager

-- local SCAN_INTERVAL = 0.15   -- 创建代理扫描间隔（秒）
-- local CLEANUP_INTERVAL = 3.0 -- 清理无效代理间隔（秒）
-- local MAX_DIST = 8192        -- 最大距离（单位）
-- local SCAN_PER_TICK = 2      -- 每 Tick 最多处理多少个 NPC（分帧）

-- -- 存储每个玩家的扫描状态
-- local playerStates = {}

-- -- 获取指定位置半径内的所有 NPC
-- local function GetNPCsInRange(origin, radius)
--     local allInSphere = ents.FindInSphere(origin, radius)
--     local npcs = {}
--     for _, ent in ipairs(allInSphere) do
--         if ent:IsNPC() and IsValid(ent) and ent:Health() > 0 then
--             npcs[#npcs + 1] = ent
--         end
--     end
--     return npcs
-- end

-- -- 检查 NPC 是否对玩家有敌意（仅用于创建时筛选）
-- local function IsHostileToPlayer(npc, ply)
--     if not IsValid(npc) or not npc:IsNPC() then return false end
--     local disp = npc:Disposition(ply)
--     return disp == D_HT -- 仇恨（主动攻击）
-- end

-- -- 检查一个代理是否仍然有效（用于定期清理，不检查敌意）
-- local function IsProxyValid(proxy, ply)
--     if not IsValid(proxy) then return false end
--     local npc = proxy.attacker
--     local victim = proxy.victim
--     if not IsValid(npc) or not npc:IsNPC() or npc:Health() <= 0 then return false end
--     if not IsValid(victim) or victim ~= ply then return false end

--     -- 距离检查（快速）
--     local distSq = ply:GetPos():DistToSqr(npc:GetPos())
--     if distSq > MAX_DIST * MAX_DIST then return false end

--     -- 视线检查（精确，开销较大，放在最后）
--     if not npc:Visible(ply) then return false end

--     return true
-- end

-- -- 检查并移除该玩家所有无效代理（低频调用）
-- local function CleanupInvalidProxies(ply)
--     for proxy in ProxyManager.ValidProxies() do
--         if not IsProxyValid(proxy, ply) then
--             proxy:Remove()
--         end
--     end
-- end

-- -- 为指定玩家执行扫描和创建代理（分帧）
-- local function ScanAndCreateForPlayer(ply)
--     if not IsValid(ply) then return end

--     local state = playerStates[ply]
--     if not state then return end

--     -- 如果该玩家当前没有 NPC 列表，重新获取（使用空间筛选）
--     if not state.npcList then
--         state.npcList = GetNPCsInRange(ply:GetPos(), MAX_DIST)
--         state.currentIndex = 1
--     end

--     local processed = 0
--     local plyPos = ply:GetPos()

--     while state.currentIndex <= #state.npcList and processed < SCAN_PER_TICK do
--         local npc = state.npcList[state.currentIndex]
--         state.currentIndex = state.currentIndex + 1
--         processed = processed + 1

--         -- 快速有效性检查（NPC 可能已死亡）
--         if not IsValid(npc) or not npc:IsNPC() or npc:Health() <= 0 then
--             continue
--         end

--         -- 1. 距离检查（二次确认，因 FindInSphere 基于包围盒可能包含边界外）
--         local distSq = plyPos:DistToSqr(npc:GetPos())
--         if distSq > MAX_DIST * MAX_DIST then
--             continue
--         end

--         -- 2. 敌意检查（创建时必须）
--         if not IsHostileToPlayer(npc, ply) then
--             continue
--         end

--         -- 3. PVS 检查（快速可见性粗筛）
--         if not npc:TestPVS(ply) then
--             continue
--         end

--         -- 4. 精确视线检查（最后确认）
--         if not npc:Visible(ply) then
--             continue
--         end

--         -- 避免重复创建
--         local exists = false
--         for proxy in ProxyManager.ValidProxies() do
--             if proxy.attacker == npc and proxy.victim == ply then
--                 exists = true
--                 break
--             end
--         end
--         if exists then
--             continue
--         end

--         -- 创建新代理
--         ProxyManager.RequestProxy(ply, npc)
--     end

--     -- 如果当前批次扫描完毕，重置列表，等待下一轮扫描
--     if state.currentIndex > #state.npcList then
--         state.npcList = nil
--         state.currentIndex = 1
--     end
-- end

-- -- 玩家首次进入时初始化扫描状态
-- hook.Add("PlayerInitialSpawn", "ENP_ProxyScanner_Init", function(ply)
--     if not IsValid(ply) then return end
--     playerStates[ply] = {
--         npcList = nil,
--         currentIndex = 1,
--         nextScanTime = 0,
--         nextCleanupTime = 0, -- 新增：下次清理时间
--     }
-- end)

-- -- 玩家离开时清理状态
-- hook.Add("PlayerDisconnected", "ENP_ProxyScanner_Cleanup", function(ply)
--     playerStates[ply] = nil
-- end)

-- -- 全局 Think 钩子：为每个活跃玩家执行扫描和清理（间隔控制）
-- hook.Add("Think", "ENP_ProxyScanner_Tick", function()
--     local curTime = CurTime()
--     for ply, state in pairs(playerStates) do
--         if not IsValid(ply) then
--             playerStates[ply] = nil
--             continue
--         end

--         -- 高频创建扫描
--         if curTime >= state.nextScanTime then
--             state.nextScanTime = curTime + SCAN_INTERVAL
--             ScanAndCreateForPlayer(ply)
--         end

--         -- 低频清理扫描
--         -- if curTime >= state.nextCleanupTime then
--         --     state.nextCleanupTime = curTime + CLEANUP_INTERVAL
--         --     CleanupInvalidProxies(ply)
--         -- end
--     end
-- end)
