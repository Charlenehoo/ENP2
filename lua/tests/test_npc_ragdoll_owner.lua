-- 测试 GetRagdollOwner 对 NPC ragdoll 的有效性
-- 在服务器控制台执行：lua_openscript tests\test_npc_ragdoll_owner.lua
-- 或者直接复制以下代码到控制台（注意多行输入可能需要换行）

local function TestNPCRagdollOwner()
	-- 创建一个 NPC（Combine Soldier）
	local npc = ents.Create("npc_combine_s")
	if not IsValid(npc) then
		print("Failed to create NPC")
		return
	end

	-- 设置位置为玩家前方
	local ply = player.GetAll()[1]
	if IsValid(ply) then
		npc:SetPos(ply:GetPos() + ply:GetForward() * 200)
	else
		npc:SetPos(Vector(0, 0, 0))
	end
	npc:Spawn()
	npc:Activate()

	print("NPC created:", npc)

	-- 监听 ragdoll 生成
	local hookId = "TestGetRagdollOwner"
	hook.Add("CreateEntityRagdoll", hookId, function(owner, ragdoll)
		if owner ~= npc then
			return
		end
		print("CreateEntityRagdoll triggered!")
		print("  owner:", owner)
		print("  ragdoll:", ragdoll)
		print("  ragdoll:GetRagdollOwner() =", ragdoll:GetRagdollOwner())
		print("  IsValid(ragdoll:GetRagdollOwner()) =", IsValid(ragdoll:GetRagdollOwner()))
		-- 延迟检查 ragdoll 是否还在
		timer.Simple(0.5, function()
			if IsValid(ragdoll) then
				print("After 0.5s, ragdoll still valid, owner =", ragdoll:GetRagdollOwner())
			else
				print("After 0.5s, ragdoll removed.")
			end
		end)
		-- 测试完成后移除钩子
		hook.Remove("CreateEntityRagdoll", hookId)
	end)

	-- 使用 TakeDamage 杀死 NPC
	print("Killing NPC with TakeDamage...")
	npc:TakeDamage(9999, npc, npc) -- 伤害量足够大，攻击者和伤害来源都设为自身
end

TestNPCRagdollOwner()

-- ] lua_openscript tests\test_npc_ragdoll_owner.lua
-- Running script tests\test_npc_ragdoll_owner.lua...
-- NPC created:	NPC [83][npc_combine_s]
-- Killing NPC with TakeDamage...
-- CreateEntityRagdoll triggered!
--   owner:	NPC [83][npc_combine_s]
--   ragdoll:	Entity [152][prop_ragdoll]
--   ragdoll:GetRagdollOwner() =	[NULL Entity]
--   IsValid(ragdoll:GetRagdollOwner()) =	false
-- After 0.5s, ragdoll still valid, owner =	[NULL Entity]
