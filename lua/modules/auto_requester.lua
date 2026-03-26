-- lua/modules/ProxyManager/proxy_scanner.lua
local ProxyManager = _G.ProxyManager

local SCAN_INTERVAL = 0.1       -- 扫描间隔（秒）
local MAX_DIST_SQ = 8192 * 8192 -- 距离阈值平方（8192 单位）
local SCAN_PER_TICK = 2         -- 每 Tick 最多处理多少个 NPC（分帧）

local _state = {
    nextScanTime = 0,
    npcList = nil,    -- 当前帧扫描的 NPC 列表
    currentIndex = 1,
    lastPlayer = nil, -- 上次扫描的玩家（用于玩家切换时重置）
}

-- 检查该 NPC 是否已存在针对此玩家的代理
local function HasProxyForNPC(npc, player)
    for proxy in ProxyManager.ValidProxies() do
        if proxy.attacker == npc and proxy.victim == player then
            return true
        end
    end
    return false
end

-- 获取所有联合军士兵（根据你的游戏实际类名调整）
local function GetCombineSoldiers()
    -- 常见联合军类名：npc_combine_s, npc_combine_elite, npc_metropolice 等
    -- 这里使用通配符 "*" 匹配所有以 npc_combine 开头的 NPC
    return ents.FindByClass("npc_combine*")
end

-- 扫描并创建代理的主逻辑（分帧执行）
local function ScanAndCreate()
    local ply = Entity(1)
    if not IsValid(ply) then
        _state.npcList = nil
        _state.currentIndex = 1
        return
    end

    -- 玩家变化时重置扫描
    if _state.lastPlayer ~= ply then
        _state.npcList = nil
        _state.currentIndex = 1
        _state.lastPlayer = ply
    end

    -- 每轮扫描开始时重新获取 NPC 列表（NPC 可能死亡、刷新）
    if not _state.npcList then
        _state.npcList = GetCombineSoldiers()
        _state.currentIndex = 1
    end

    local processed = 0
    local plyPos = ply:GetPos()

    while _state.currentIndex <= #_state.npcList and processed < SCAN_PER_TICK do
        local npc = _state.npcList[_state.currentIndex]
        _state.currentIndex = _state.currentIndex + 1
        processed = processed + 1

        -- NPC 无效或已死亡，跳过
        if not IsValid(npc) or not npc:IsNPC() or npc:Health() <= 0 then
            continue
        end

        -- 距离检查
        local distSq = plyPos:DistToSqr(npc:GetPos())
        if distSq > MAX_DIST_SQ then
            continue
        end

        -- PVS 检查（实体是否在玩家潜在可见集内）
        if not npc:TestPVS(ply) then
            continue
        end

        -- 避免为同一个 (NPC, 玩家) 创建多个代理
        if HasProxyForNPC(npc, ply) then
            continue
        end

        -- 创建代理
        ProxyManager.RequestProxy(ply, npc)
    end

    -- 如果当前批次扫描完毕，重置列表，等待下一轮扫描（由 SCAN_INTERVAL 控制）
    if _state.currentIndex > #_state.npcList then
        _state.npcList = nil
        _state.currentIndex = 1
    end
end

-- 定时扫描（使用 Tick 或定时器）
hook.Add("Think", "ENP_ProxyScanner", function()
    if CurTime() < _state.nextScanTime then
        return
    end
    _state.nextScanTime = CurTime() + SCAN_INTERVAL
    ScanAndCreate()
end)
