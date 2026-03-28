-- -- lua/modules/ProxyManager/ragdoll_linker.lua

-- local function _UpdateProxyVictim(owner, ragdoll)
-- 	for proxy in ProxyManager.ValidProxies() do
-- 		if proxy.victim == owner then
-- 			proxy._originalVictim = owner
-- 			proxy.victim = ragdoll
-- 		end
-- 	end
-- end

-- -- NPC 及通用 ragdoll 生成钩子
-- hook.Add("CreateEntityRagdoll", "ENP_ProxyManager_RagdollLink_NPC", function(owner, ragdoll)
-- 	if not IsValid(owner) or not IsValid(ragdoll) then
-- 		return
-- 	end
-- 	_UpdateProxyVictim(owner, ragdoll)
-- end)

-- -- 递归重试函数，等待 ragdoll 生成
-- local function UpdateVictimWithRetry(player, retriesLeft)
-- 	if not IsValid(player) then
-- 		return
-- 	end
-- 	local ragdoll = player:GetRagdollEntity()
-- 	if IsValid(ragdoll) then
-- 		_UpdateProxyVictim(player, ragdoll)
-- 	elseif retriesLeft > 0 then
-- 		timer.Simple(0.1, function()
-- 			UpdateVictimWithRetry(player, retriesLeft - 1)
-- 		end)
-- 	end
-- 	-- 重试次数用尽且 ragdoll 仍无效，则放弃
-- end

-- -- 玩家死亡钩子（ragdoll 可能延迟生成，带重试）
-- hook.Add("PostPlayerDeath", "ENP_ProxyManager_RagdollLink_Player", function(player)
-- 	if not IsValid(player) then
-- 		return
-- 	end
-- 	UpdateVictimWithRetry(player, 5) -- 最多重试5次，每次间隔0.1秒
-- end)

-- -- 玩家重生钩子：通过 originalVictim 匹配并恢复 victim 为玩家实体
-- hook.Add("PlayerSpawn", "ENP_ProxyManager_PlayerRespawn", function(player)
-- 	if not IsValid(player) then
-- 		return
-- 	end

-- 	for proxy in ProxyManager.ValidProxies() do
-- 		local original = proxy._originalVictim
-- 		if IsValid(original) and original == player then
-- 			proxy.victim = player
-- 			proxy:ResetTimeout()
-- 		end
-- 	end
-- end)
