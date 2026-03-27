-- lua/modules/ProxyManager/proxy_monitor.lua
local Debugger = include("modules/util/debugger.lua")

local PROXY_CLASS = ProxyManager.PROXY_CLASS

--- 判断被击中实体是否应视为命中 victim
--- @param victim Entity  目标实体（可能是玩家或 ragdoll）
--- @param entityHit Entity  被击中的实体
--- @return boolean
local function IsVictimHit(victim, entityHit)
	-- 直接命中：victim 有效且相等
	if IsValid(victim) then
		return entityHit == victim
	end
	-- 命中 ragdoll 且 ragdoll 的主人等于 victim（即使 victim 无效也可比较）
	if IsValid(entityHit) and entityHit:IsRagdoll() then
		local owner = entityHit:GetRagdollOwner()
		return owner == victim
	end
	return false
end

--- @param entity Entity  发射子弹的实体（可能是武器或 NPC）
--- @param data Bullet    子弹数据
local function OnEntityFireBullets(entity, data)
	-- 1. 获取实际开枪的 NPC
	local actualShooter = entity
	if IsValid(actualShooter) and actualShooter:IsWeapon() then
		actualShooter = actualShooter:GetOwner()
	end
	if not IsValid(actualShooter) or not actualShooter:IsNPC() then
		Debugger.Print("[ENP Monitor] Shooter is not a valid NPC, skipping", Debugger.LEVEL.TRACE)
		return
	end

	-- 2. 获取 shooter 的敌人，这个敌人应该是 proxy 实体
	local proxy = actualShooter:GetEnemy()
	if not IsValid(proxy) or proxy:GetClass() ~= PROXY_CLASS then
		Debugger.Print("[ENP Monitor] Shooter's enemy is not a valid proxy, skipping", Debugger.LEVEL.TRACE)
		return
	end

	-- 3. 验证 proxy 的 attacker 确实是这个 shooter
	local attacker = proxy.attacker
	if not IsValid(attacker) or attacker ~= actualShooter then
		Debugger.Print("[ENP Monitor] Proxy's attacker mismatch, skipping", Debugger.LEVEL.TRACE)
		return
	end

	local victim = proxy.victim

	local boneIndex = nil
	if proxy.validBones and proxy.currentBoneIndex then
		boneIndex = proxy.validBones[proxy.currentBoneIndex]
	end

	local shotID = nil
	if boneIndex then
		shotID = proxy:RecordShot(boneIndex)
	end

	local originalCallback = data.Callback

	local function wrappedCallback(shooter, tr, dmgInfo)
		local entityHit = tr.Entity
		local isVictimHit = IsVictimHit(victim, entityHit)

		if isVictimHit and boneIndex and shotID then
			proxy:RecordHit(boneIndex, shotID)
		end

		hook.Run("ENP_BulletHit", proxy, isVictimHit, tr)

		if originalCallback then
			return originalCallback(shooter, tr, dmgInfo)
		end
		return true, true
	end

	data.Callback = wrappedCallback
end

hook.Add("EntityFireBullets", "ENP_ProxyMonitor", OnEntityFireBullets)
