-- lua/modules/LogicEntity/logic_entity.lua
-- =============================================================================
-- 通用 class 工厂函数
-- =============================================================================

-- 生成实体方法包装器
-- 包装后的函数会在调用时动态获取当前目标实体（优先 GetCurrentEntity，回退 GetFallbackEntity），
-- 并自动将参数中的 LogicEntity 实例转换为原始实体，然后调用原始方法。
-- 同时实现了快速路径：当参数中不包含任何 LogicEntity 实例时，直接调用原始方法，避免创建参数表和解包开销。
local function make_wrapper(original_func)
	return function(self, ...)
		local target = self:GetCurrentEntity() or self:GetFallbackEntity()
		if not target then
			return
		end
		-- 快速路径：参数中无 LogicEntity 实例则直接调用
		local n = select("#", ...)
		local need_convert = false
		for i = 1, n do
			local arg = select(i, ...)
			if type(arg) == "table" and arg.GetCurrentEntity then
				need_convert = true
				break
			end
		end
		if not need_convert then
			return original_func(target, ...)
		end
		-- 需要转换：构建参数表并替换所有 LogicEntity 实例为原始实体
		local args = { ... }
		for i = 1, n do
			local arg = args[i]
			if type(arg) == "table" and arg.GetCurrentEntity then
				args[i] = arg:GetCurrentEntity()
			end
		end
		return original_func(target, unpack(args))
	end
end

local function class(name, base)
	local cls = {}
	cls.name = name
	cls.base = base

	if base then
		setmetatable(cls, { __index = base })
	end

	-- 实例元方法：方法查找顺序为：
	-- 1. 子类自身定义的方法（类表）
	-- 2. 基类方法（递归）
	-- 3. 实体方法（通过当前实体或备用实体），并将包装器缓存到实例的 __wrappers 表中
	cls.__index = function(self, key)
		-- 1. 子类方法
		local method = cls[key]
		if method ~= nil then
			return method
		end

		-- 2. 基类方法（递归）
		if base then
			method = base.__index(self, key)
			if method ~= nil then
				return method
			end
		end

		-- 3. 实体方法（使用缓存表，避免重复创建包装器）
		local wrappers = rawget(self, "__wrappers")
		if not wrappers then
			wrappers = {}
			rawset(self, "__wrappers", wrappers)
		end

		local wrapper = wrappers[key]
		if wrapper ~= nil then
			return wrapper
		end

		local target = self:GetCurrentEntity() or self:GetFallbackEntity()
		if target then
			local value = target[key]
			if value ~= nil then
				if type(value) == "function" then
					wrapper = make_wrapper(value)
					wrappers[key] = wrapper
					return wrapper
				else
					-- 非函数值不缓存（可能变化）
					return value
				end
			end
		end

		return nil
	end

	-- 实例赋值：转发给当前实体
	cls.__newindex = function(self, key, value)
		local current = self:GetCurrentEntity()
		if current then
			current[key] = value
		else
			error("No valid current entity to write to")
		end
	end

	return cls
end



-- =============================================================================
-- LogicEntity 基类
-- =============================================================================
local LogicEntity = class("LogicEntity")
LogicEntity._routers = {} -- 路由表：{ predicate, factory }

--- 注册实体类型
function LogicEntity.RegisterEntityType(predicate, factory)
	table.insert(LogicEntity._routers, { predicate = predicate, factory = factory })
end

-- 抽象方法（子类必须实现）
function LogicEntity:GetCurrentEntity()
	error("GetCurrentEntity must be overridden by subclass")
end

function LogicEntity:GetFallbackEntity()
	return nil
end

function LogicEntity:GetOriginalEntity()
	error("GetOriginalEntity must be overridden by subclass")
end

function LogicEntity:IsEntityMine(entity)
	error("IsEntityMine must be overridden by subclass")
end

-- 通用方法
function LogicEntity:IsValid()
	return IsValid(self:GetCurrentEntity())
end

function LogicEntity:IsEqualTo(other)
	if type(other) == "table" and other.GetCurrentEntity then
		local selfOrig = self:GetOriginalEntity()
		local otherOrig = other:GetOriginalEntity()
		return IsValid(selfOrig) and IsValid(otherOrig) and selfOrig == otherOrig
	end
	if IsValid(other) then
		return self:IsEntityMine(other)
	end
	return false
end

-- 统一工厂方法（幂等）
function LogicEntity.GetOrCreate(entity)
	-- 幂等：已经是逻辑实例则直接返回
	if type(entity) == "table" and entity.GetCurrentEntity then
		return entity
	end

	if not IsValid(entity) then
		return nil
	end

	-- 遍历路由表，找到第一个匹配的注册项
	for _, router in ipairs(LogicEntity._routers) do
		if router.predicate(entity) then
			return router.factory(entity)
		end
	end

	return LogicDummy.GetOrCreate(entity)
end

-- =============================================================================
-- 导出到全局（可选）
-- =============================================================================
_G.class = class
_G.LogicEntity = LogicEntity
