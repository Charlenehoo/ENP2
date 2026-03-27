-- test_logic_player.lua
-- 测试 LogicPlayer 模块的正确性

-- 确保模块已加载
local LogicPlayer = include("modules/util/logic_player.lua")
print("LogicPlayer type:", type(LogicPlayer))
print("LogicPlayer.IsEqualTo type:", type(LogicPlayer.IsEqualTo))


-- 辅助函数：打印测试结果
local function Test(name, condition)
    if condition then
        print(string.format("[PASS] %s", name))
    else
        print(string.format("[FAIL] %s", name))
    end
end

-- 辅助函数：检查异常是否抛出
local function TestNoError(name, fn)
    local ok, err = pcall(fn)
    if ok then
        Test(name, true)
    else
        print(string.format("[FAIL] %s: %s", name, err))
    end
end

-- 获取第一个有效玩家（如果没有则退出）
local allPlayers = player.GetAll()
local testPlayer = allPlayers[1]
if not IsValid(testPlayer) then
    print("No valid player found. Please join a game to run tests.")
    return
end

print("=== Testing LogicPlayer with player: " .. testPlayer:Name() .. " ===")

-- 1. 创建逻辑玩家
local lp1 = LogicPlayer.GetOrCreate(testPlayer)
local lp1 = LogicPlayer.GetOrCreate(testPlayer)
print("lp1.IsEqualTo type:", type(lp1.IsEqualTo))
Test("GetOrCreate returns non-nil", lp1 ~= nil)
Test("GetOrCreate returns same instance for same player", lp1 == LogicPlayer.GetOrCreate(testPlayer))

-- 2. 字段读写转发（假设玩家有 health 字段）
local originalHealth = testPlayer:Health()
lp1.health = 123
Test("Write to logic player updates player", testPlayer:Health() == 123)
lp1.health = originalHealth -- 恢复

-- 3. 方法调用转发
local pos = lp1:GetPos()
Test("Method call GetPos returns player's position", pos == testPlayer:GetPos())

-- 4. 相等判断 (IsEqualTo)
Test("IsEqualTo with same player", lp1:IsEqualTo(testPlayer))
Test("IsEqualTo with ragdoll before creation", not lp1:IsEqualTo(Entity(0))) -- 无效实体

-- 模拟 ragdoll 创建（如果玩家死亡会自动创建，这里手动创建一个临时 ragdoll 用于测试）
local tempRagdoll = ents.Create("prop_ragdoll")
if IsValid(tempRagdoll) then
    tempRagdoll:SetPos(testPlayer:GetPos())
    tempRagdoll:Spawn()
    -- 注意：真正的 ragdoll 需要通过玩家死亡生成，这里仅用于测试 IsEqualTo 对 ragdoll 的支持
    -- 但由于 owner 关系不成立，应该返回 false
    Test("IsEqualTo with unrelated ragdoll", not lp1:IsEqualTo(tempRagdoll))
    tempRagdoll:Remove()
end

-- 5. 测试死亡切换（需要实际杀死玩家）
print("--- Testing death transition ---")
local deathHook = nil
deathHook = hook.Add("PostPlayerDeath", "TestLogicPlayerDeath", function(ply)
    if ply ~= testPlayer then return end
    hook.Remove("PostPlayerDeath", "TestLogicPlayerDeath") -- 只运行一次

    -- 死亡后，当前实体应为 ragdoll（如果已生成）或回退到玩家
    local current = lp1:_GetCurrent()
    Test("After death, _GetCurrent returns valid entity", IsValid(current))
    if IsValid(current) and current:IsRagdoll() then
        Test("After death, current entity is ragdoll", true)
    elseif current == testPlayer then
        Test("After death, current entity falls back to player (ragdoll not ready)", true)
    else
        Test("After death, unexpected entity type", false)
    end

    -- IsEqualTo 应能识别 ragdoll（当它最终出现时）
    -- 由于 ragdoll 生成是异步的，我们需要延迟测试
    timer.Simple(0.2, function()
        local ragdoll = testPlayer:GetRagdollEntity()
        if IsValid(ragdoll) then
            Test("IsEqualTo recognizes ragdoll after creation", lp1:IsEqualTo(ragdoll))
        else
            print("[WARN] Ragdoll not created within 0.2 seconds, skipping test.")
        end
        -- 测试另一个逻辑玩家相等
        local lp2 = LogicPlayer.GetOrCreate(testPlayer)
        Test("IsEqualTo with another logic player instance", lp1:IsEqualTo(lp2))
    end)
end)

-- 让玩家死亡以触发测试
print("Killing player to trigger death test...")
testPlayer:Kill()

-- 6. 测试重生切换（等待玩家重生后）
local spawnHook = hook.Add("PlayerSpawn", "TestLogicPlayerSpawn", function(ply)
    if ply ~= testPlayer then return end
    hook.Remove("PlayerSpawn", "TestLogicPlayerSpawn")

    -- 重生后，当前实体应切回玩家
    local current = lp1:_GetCurrent()
    Test("After spawn, current entity is player", current == testPlayer)
    Test("IsEqualTo with player after spawn", lp1:IsEqualTo(testPlayer))

    print("=== All tests completed ===")
end)

-- 注意：如果玩家未重生（例如无重生逻辑），请手动重生或使用其他方式
-- 可以添加一个超时避免卡住
timer.Simple(5, function()
    if hook.GetTable()["PlayerSpawn"]["TestLogicPlayerSpawn"] then
        hook.Remove("PlayerSpawn", "TestLogicPlayerSpawn")
        print("[WARN] Player did not respawn within 5 seconds, skipping spawn test.")
    end
end)
