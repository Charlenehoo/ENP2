-- test_logic_player_new.lua
-- 完整测试新版 LogicPlayer（监听 CreateEntityRagdoll 钩子）

local LogicPlayer = include("modules/util/logic_player.lua")
if not LogicPlayer then error("Failed to load LogicPlayer") end
print("LogicPlayer loaded:", type(LogicPlayer))

-- 辅助函数
local function Test(name, condition)
    if condition then print("[PASS] " .. name) else print("[FAIL] " .. name) end
end

-- 获取第一个玩家
local allPlayers = player.GetAll()
local testPlayer = allPlayers[1]
if not IsValid(testPlayer) then
    print("No player found.")
    return
end
print("=== Testing LogicPlayer with player: " .. testPlayer:Name() .. " ===")

-- 确保钩子已注册
LogicPlayer.Init()

-- 创建逻辑玩家实例
local lp = LogicPlayer.GetOrCreate(testPlayer)
Test("GetOrCreate returns non-nil", lp ~= nil)
Test("GetOrCreate returns same instance", lp == LogicPlayer.GetOrCreate(testPlayer))

-- 测试方法调用
local originalHealth = testPlayer:Health()
lp:SetHealth(originalHealth + 10)
Test("SetHealth works", testPlayer:Health() == originalHealth + 10)
lp:SetHealth(originalHealth)

local pos = lp:GetPos()
Test("GetPos works", pos == testPlayer:GetPos())

-- 相等判断
Test("IsEqualTo with same player", lp:IsEqualTo(testPlayer))
Test("IsEqualTo with invalid entity", not lp:IsEqualTo(Entity(0)))
local lp2 = LogicPlayer.GetOrCreate(testPlayer)
Test("IsEqualTo with another logic player", lp:IsEqualTo(lp2))

-- 测试无关 ragdoll
local tempRagdoll = ents.Create("prop_ragdoll")
if IsValid(tempRagdoll) then
    tempRagdoll:SetPos(testPlayer:GetPos())
    tempRagdoll:Spawn()
    Test("IsEqualTo with unrelated ragdoll", not lp:IsEqualTo(tempRagdoll))
    tempRagdoll:Remove()
end

-- 记录钩子是否触发
local hookFired = false
local hookRagdoll = nil

hook.Add("CreateEntityRagdoll", "TestRagdollHook", function(owner, ragdoll)
    if owner == testPlayer then
        hookFired = true
        hookRagdoll = ragdoll
        print("[DEBUG] CreateEntityRagdoll fired for test player. Ragdoll class:", ragdoll:GetClass())
    end
end)

-- 死亡测试
print("--- Testing death and ragdoll ---")
local deathHook = hook.Add("PostPlayerDeath", "TestDeath", function(ply)
    if ply ~= testPlayer then return end
    hook.Remove("PostPlayerDeath", "TestDeath")

    -- 死亡后立即检查 _GetCurrent
    local current = lp:_GetCurrent()
    Test("After death, _GetCurrent returns valid entity", IsValid(current))
    if IsValid(current) then
        print("[DEBUG] Current entity class:", current:GetClass())
        -- 如果钩子已触发，应返回钩子的 ragdoll
        if hookFired then
            Test("_GetCurrent returns hook ragdoll when available", current == hookRagdoll)
        else
            print("[WARN] Hook did not fire immediately, might be using fallback.")
        end
        -- 验证 IsEqualTo 能识别当前实体
        Test("IsEqualTo recognizes current entity", lp:IsEqualTo(current))
    end

    -- 延迟验证：检查 _ragdoll 字段是否被正确设置
    timer.Simple(0.1, function()
        if IsValid(lp._ragdoll) then
            Test("_ragdoll field is set after death", true)
            print("[DEBUG] _ragdoll class:", lp._ragdoll:GetClass())
            -- 如果钩子触发过，应该就是那个 ragdoll
            if hookFired then
                Test("_ragdoll matches hook ragdoll", lp._ragdoll == hookRagdoll)
            end
        else
            print("[WARN] _ragdoll field not set within 0.1s")
        end
    end)

    -- 移除测试钩子
    hook.Remove("CreateEntityRagdoll", "TestRagdollHook")
end)

print("Killing player...")
testPlayer:Kill()

-- 重生测试（如果游戏模式支持重生）
local spawnHook = hook.Add("PlayerSpawn", "TestSpawn", function(ply)
    if ply ~= testPlayer then return end
    hook.Remove("PlayerSpawn", "TestSpawn")

    timer.Simple(0.1, function()
        local current = lp:_GetCurrent()
        Test("After spawn, current entity is player", current == testPlayer)
        Test("IsEqualTo with player after spawn", lp:IsEqualTo(testPlayer))
        Test("_ragdoll field is cleared after spawn", not IsValid(lp._ragdoll))
        print("=== All tests completed (spawn part) ===")
    end)
end)

-- 超时保护
timer.Simple(5, function()
    if hook.GetTable()["PlayerSpawn"]["TestSpawn"] then
        hook.Remove("PlayerSpawn", "TestSpawn")
        print("[INFO] No respawn detected, spawn tests skipped.")
    end
    if hook.GetTable()["CreateEntityRagdoll"]["TestRagdollHook"] then
        hook.Remove("CreateEntityRagdoll", "TestRagdollHook")
    end
    print("=== Test execution finished ===")
end)
