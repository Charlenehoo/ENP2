-- lua/modules/ProxyManager/proxy_monitor.lua
local Debugger = include("modules/util/debugger.lua")

local PROXY_CLASS = ProxyManager.PROXY_CLASS

--- 判断被击中实体是否应视为命中 victim
--- @param logicVictim  Entity  目标实体（可能是玩家或 ragdoll）
--- @param entityHit Entity  被击中的实体
--- @return boolean
local function IsVictimHit(logicVictim, entityHit)
	-- 直接命中：victim 有效且相等
	if logicVictim:IsValid() then
		return logicVictim:IsEqualTo(entityHit)
	end
	return false
end

--- @param entity Entity  发射子弹的实体（可能是武器或 NPC）
--- @param data Bullet    子弹数据
local function OnEntityFireBullets(entity, data)
    local actualShooter = entity
    if IsValid(actualShooter) and actualShooter:IsWeapon() then
        actualShooter = actualShooter:GetOwner()
    end
    if not IsValid(actualShooter) or not actualShooter:IsNPC() then
        return
    end

    local proxy = actualShooter:GetEnemy()
    if not IsValid(proxy) or proxy:GetClass() ~= PROXY_CLASS then
        return
    end

    local attacker = proxy.attacker
    if not IsValid(attacker) or attacker ~= actualShooter then
        return
    end

    local logicVictim = proxy.logicVictim
    local originalCallback = data.Callback

    data.Callback = function(shooter, tr, dmgInfo)
        local isVictimHit = logicVictim and logicVictim:IsEqualTo(tr.Entity)
        hook.Run("ENP_BulletHit", proxy, isVictimHit)

        if originalCallback then
            return originalCallback(shooter, tr, dmgInfo)
        end
        return true, true
    end
end

hook.Add("EntityFireBullets", "ENP_ProxyMonitor", OnEntityFireBullets)
