local LogicEntity = {}
LogicEntity.__index = LogicEntity

local classMap = {}

function LogicEntity.RegisterClass(entityClass, logicClass)
	classMap[entityClass] = logicClass
end

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
			return LogicEntity.Get(owner)
		end
	end
	return nil
end

function LogicEntity:IsEntityMine(entity)
	error("IsEntityMine must be overridden by subclass")
end

function LogicEntity:IsEqualTo(other)
	if type(other) == "table" and getmetatable(other) and getmetatable(other).__index == LogicEntity then
		local selfOriginal = self:GetOriginalEntity()
		local otherOriginal = other:GetOriginalEntity()
		return IsValid(selfOriginal) and IsValid(otherOriginal) and selfOriginal == otherOriginal
	end

	if IsValid(other) then
		return self:IsEntityMine(other)
	end

	return false
end

function LogicEntity:GetOriginalEntity()
	error("GetOriginalEntity must be overridden by subclass")
end

function LogicEntity:GetCurrentEntity()
	error("GetCurrentEntity must be overridden by subclass")
end

function LogicEntity:GetFallbackEntity()
	return nil
end

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

return LogicEntity
