-- lua/modules/LogicEntity/logic_entity.lua
-- 逻辑实体基类，为玩家、NPC 等提供统一的代理接口

local LogicEntity = {}
LogicEntity.__index = LogicEntity

-- =============================================================================
-- 私有变量
-- =============================================================================

local classMap = {}

-- =============================================================================
-- 公开工厂方法
-- =============================================================================

-- 注册实体类型对应的逻辑类
function LogicEntity.RegisterClass(entityClass, logicClass)
	classMap[entityClass] = logicClass
end

-- 根据任意实体（玩家、NPC、ragdoll）获取对应的逻辑实体实例
function LogicEntity.GetOrCreate(entity)
	if not IsValid(entity) then
		return nil
	end
	local logicClass = classMap[entity:GetClass()]
	if logicClass then
		return logicClass.GetOrCreate(entity)
	end
	if entity:IsRagdoll() then
		local owner = entity:GetRagdollOwner()
		if IsValid(owner) then
			return LogicEntity.GetOrCreate(owner) -- 修正：原为 Get，现改为 GetOrCreate
		end
	end
	return nil
end

-- =============================================================================
-- 抽象方法（子类必须实现）
-- =============================================================================

-- 判断给定实体是否属于该逻辑实例
function LogicEntity:IsEntityMine(entity)
	error("IsEntityMine must be overridden by subclass")
end

-- 返回原始实体（如玩家、NPC 本身）
function LogicEntity:GetOriginalEntity()
	error("GetOriginalEntity must be overridden by subclass")
end

-- 返回当前激活的实体（原始实体或其 ragdoll）
function LogicEntity:GetCurrentEntity()
	error("GetCurrentEntity must be overridden by subclass")
end

-- 返回回退实体（可选，用于弥补当前实体缺失的方法）
function LogicEntity:GetFallbackEntity()
	return nil
end

-- =============================================================================
-- 公开方法
-- =============================================================================

-- 判断两个逻辑实体是否代表同一个原始实体，或判断某个实体是否属于当前逻辑实体
function LogicEntity:IsEqualTo(other)
	-- 另一个逻辑实体
	if type(other) == "table" and other.GetOriginalEntity then
		local selfOriginal = self:GetOriginalEntity()
		local otherOriginal = other:GetOriginalEntity()
		return IsValid(selfOriginal) and IsValid(otherOriginal) and selfOriginal == otherOriginal
	end
	-- 普通实体
	if IsValid(other) then
		return self:IsEntityMine(other)
	end
	return false
end

-- =============================================================================
-- 元方法（实现透明转发）
-- =============================================================================

function LogicEntity:__index(key)
	local current = self:GetCurrentEntity()
	if current then
		local value = current[key]
		if value ~= nil then
			if type(value) == "function" then
				return function(_, ...)
					return value(current, ...)
				end
			else
				return value
			end
		end
	end
	local fallback = self:GetFallbackEntity()
	if fallback then
		local value = fallback[key]
		if value ~= nil then
			if type(value) == "function" then
				return function(_, ...)
					return value(fallback, ...)
				end
			else
				return value
			end
		end
	end
	return rawget(LogicEntity, key) or rawget(self, key)
end

function LogicEntity:__newindex(key, value)
	local current = self:GetCurrentEntity()
	if current then
		current[key] = value
	else
		error("No valid current entity to write to")
	end
end

-- =============================================================================
-- 返回模块
-- =============================================================================

return LogicEntity
