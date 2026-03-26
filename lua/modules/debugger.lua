-- lua/modules/debugger.lua
local Debugger = {}

-- 日志级别枚举
Debugger.LEVEL = {
	INFO = 1,
	TRACE = 2,
	WARN = 3,
	ERROR = 4,
}

-- 全局开关（可动态修改）
Debugger.ENABLED = true

-- 颜色映射（GMod Color 对象）
local COLORS = {
	[Debugger.LEVEL.INFO] = Color(255, 255, 255), -- 白色
	[Debugger.LEVEL.TRACE] = Color(0, 255, 255), -- 青色
	[Debugger.LEVEL.WARN] = Color(255, 255, 0), -- 黄色
	[Debugger.LEVEL.ERROR] = Color(255, 0, 0), -- 红色
}

-- 缩进映射（仅对 TRACE 和 WARN 添加4空格，其他无缩进）
local INDENT = {
	[Debugger.LEVEL.INFO] = "",
	[Debugger.LEVEL.TRACE] = "    ",
	[Debugger.LEVEL.WARN] = "    ",
	[Debugger.LEVEL.ERROR] = "",
}

--- 打印调试信息
--- @param msg string 消息内容
--- @param level number 日志级别（Debugger.LEVEL 枚举）
function Debugger.Print(msg, level)
	if not Debugger.ENABLED then
		return
	end
	level = level or Debugger.LEVEL.TRACE
	local color = COLORS[level] or Color(255, 255, 255)
	local indent = INDENT[level] or ""
	MsgC(color, indent .. msg .. "\n")
end

return Debugger
