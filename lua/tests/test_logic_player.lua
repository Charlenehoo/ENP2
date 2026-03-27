-- test_logic_player.lua
-- 完整测试 LogicPlayer 模块，包括方法转发、相等判断、死亡/重生自动切换

-- 确保模块已加载
local LogicPlayer = include("modules/util/logic_player.lua")
if not LogicPlayer then
    error("Failed to load LogicPlayer module")
end
print("LogicPlayer loaded:", type(LogicPlayer))
print("LogicPlayer.IsEqualTo type:", type(LogicPlayer.IsEqualTo))

-- 辅助函数：打印测试结果
local function Test(name, condition)
    if condition then
        print(string.format("[PASS] %s", name))
    else
        print(string.format("[FAIL] %s", name))
    end
end

-- 辅助函数：安全执行并捕获错误
local function TestNoError(name, fn)
    local ok, err = pcall(fn)
    if ok then
        Test(name, true)
    else
        print(string.format("[FAIL] %s: %s", name, err))
    end
end

-- 获取第一个有效玩家
local allPlayers = player.GetAll()
local testPlayer = allPlayers[1]
if not IsValid(testPlayer) then
    print("No valid player found. Please join a game to run tests.")
    return
end

print("=== Testing LogicPlayer with player: " .. testPlayer:Name() .. " ===")

-- 1. 创建逻辑玩家
local lp1 = LogicPlayer.GetOrCreate(testPlayer)
Test("GetOrCreate returns non-nil", lp1 ~= nil)
Test("GetOrCreate returns same instance for same player", lp1 == LogicPlayer.GetOrCreate(testPlayer))
print("lp1.IsEqualTo type:", type(lp1.IsEqualTo)) -- 应为 function

-- 2. 测试方法调用转发（使用 SetHealth）
local originalHealth = testPlayer:Health()
local newHealth = originalHealth + 10
lp1:SetHealth(newHealth)
Test("Method SetHealth works", testPlayer:Health() == newHealth)
-- 恢复原血量
lp1:SetHealth(originalHealth)

-- 3. 测试其他方法转发（如 GetPos）
local pos = lp1:GetPos()
Test("Method GetPos returns player's position", pos == testPlayer:GetPos())

-- 4. 测试相等判断
Test("IsEqualTo with same player", lp1:IsEqualTo(testPlayer))
Test("IsEqualTo with invalid entity", not lp1:IsEqualTo(Entity(0)))
local lp2 = LogicPlayer.GetOrCreate(testPlayer)
Test("IsEqualTo with another logic player instance", lp1:IsEqualTo(lp2))

-- 5. 测试无关 ragdoll 的相等判断（不应相等）
local tempRagdoll = ents.Create("prop_ragdoll")
if IsValid(tempRagdoll) then
    tempRagdoll:SetPos(testPlayer:GetPos())
    tempRagdoll:Spawn()
    Test("IsEqualTo with unrelated ragdoll", not lp1:IsEqualTo(tempRagdoll))
    tempRagdoll:Remove()
else
    print("[WARN] Could not create test ragdoll, skipping unrelated ragdoll test.")
end

-- 6. 测试死亡切换（异步，需要等待玩家死亡）
print("--- Testing death transition ---")
local deathTestPassed = false
local deathHook = hook.Add("PostPlayerDeath", "TestLogicPlayerDeath", function(ply)
    if ply ~= testPlayer then return end
    hook.Remove("PostPlayerDeath", "TestLogicPlayerDeath")

    -- 死亡后，当前实体应为 ragdoll 或回退到玩家（但不能是 nil）
    local current = lp1:_GetCurrent()
    Test("After death, _GetCurrent returns valid entity", IsValid(current))
    if IsValid(current) then
        print("[DEBUG] After death, current entity:", current:GetClass(), "IsRagdoll:", current:IsRagdoll())
        if current:IsRagdoll() or current == testPlayer then
            Test("After death, current entity is ragdoll or player", true)
        else
            Test("After death, unexpected entity type", false)
        end
    end

    -- 延迟检查 ragdoll 是否最终生成（异步）
    timer.Simple(0.2, function()
        local ragdoll = testPlayer:GetRagdollEntity()
        if IsValid(ragdoll) then
            Test("IsEqualTo recognizes ragdoll after creation", lp1:IsEqualTo(ragdoll))
        else
            print("[WARN] Ragdoll not created within 0.2 seconds, skipping ragdoll recognition test.")
        end
        deathTestPassed = true
    end)
end)

-- 让玩家死亡以触发测试
print("Killing player to trigger death test...")
testPlayer:Kill()

-- 7. 测试重生切换（可选，如果游戏模式支持重生）
local spawnTestPassed = false
local spawnHook = hook.Add("PlayerSpawn", "TestLogicPlayerSpawn", function(ply)
    if ply ~= testPlayer then return end
    hook.Remove("PlayerSpawn", "TestLogicPlayerSpawn")

    local current = lp1:_GetCurrent()
    Test("After spawn, current entity is player", current == testPlayer)
    Test("IsEqualTo with player after spawn", lp1:IsEqualTo(testPlayer))
    spawnTestPassed = true
    print("=== All tests completed (spawn part) ===")
end)

-- 超时处理：防止测试无限等待
timer.Simple(5, function()
    if not deathTestPassed then
        hook.Remove("PostPlayerDeath", "TestLogicPlayerDeath")
        print("[WARN] Death test did not complete within 5 seconds.")
    end
    if not spawnTestPassed then
        hook.Remove("PlayerSpawn", "TestLogicPlayerSpawn")
        print("[WARN] Spawn test did not complete within 5 seconds (maybe no respawn).")
    end
end)
