-- lua/modules/debugger.lua
local Debugger = {}

-- 日志级别枚举（数值越大越严重，顺序：TRACE -> DEBUG -> INFO -> WARN -> ERROR -> CRITICAL）
Debugger.LEVEL = {
	TRACE = 0, -- 追踪信息（最详细）
	DEBUG = 1, -- 调试信息
	INFO = 2,  -- 一般信息
	WARN = 3,  -- 警告
	ERROR = 4, -- 错误
	CRITICAL = 5, -- 严重错误
}

-- 全局开关（可动态修改）
Debugger.ENABLED = true

-- 打印级别阈值：只打印级别 >= LOG_LEVEL 的消息
Debugger.LOG_LEVEL = Debugger.LEVEL.INFO -- 默认为 INFO，可根据需要修改

-- 颜色映射（GMod Color 对象）
local COLORS = {
	[Debugger.LEVEL.TRACE]    = Color(0, 255, 255), -- 青色
	[Debugger.LEVEL.DEBUG]    = Color(128, 128, 128), -- 灰色
	[Debugger.LEVEL.INFO]     = Color(255, 255, 255), -- 白色
	[Debugger.LEVEL.WARN]     = Color(255, 255, 0), -- 黄色
	[Debugger.LEVEL.ERROR]    = Color(255, 0, 0), -- 红色
	[Debugger.LEVEL.CRITICAL] = Color(255, 0, 255), -- 洋红色
}

-- 缩进映射（空格数，便于区分层级）
local INDENT = {
	[Debugger.LEVEL.TRACE]    = "        ", -- 8 空格
	[Debugger.LEVEL.DEBUG]    = "    ", -- 4 空格
	[Debugger.LEVEL.INFO]     = "",
	[Debugger.LEVEL.WARN]     = "        ", -- 8 空格
	[Debugger.LEVEL.ERROR]    = "    ", -- 4 空格
	[Debugger.LEVEL.CRITICAL] = "",
}

--- 打印调试信息
--- @param msg string 消息内容
--- @param level number 日志级别（Debugger.LEVEL 枚举）
function Debugger.Print(msg, level)
	if not Debugger.ENABLED then
		return
	end
	level = level or Debugger.LEVEL.TRACE
	if level < Debugger.LOG_LEVEL then
		return -- 低于阈值则不打印
	end
	local color = COLORS[level] or Color(255, 255, 255)
	local indent = INDENT[level] or ""
	MsgC(color, indent .. msg .. "\n")
end

return Debugger
