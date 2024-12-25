local rawget, rawset = rawget, rawset

function core.global_exists(name)
	if type(name) ~= "string" then
		error("core.global_exists: " .. tostring(name) .. " is not a string")
	end
	return rawget(_G, name) ~= nil
end


local meta = {}
local declared = {}
-- Key is source file, line, and variable name; separated by NULs
local warned = {}

function meta:__newindex(name, value)
	rawset(self, name, value)
	if declared[name] then
		return
	end
	local info = {debug.info(2, "sln")}
	local desc = ("%s:%d"):format(info[1], info[2])
	local warn_key = ("%s\0%d\0%s"):format(info[1], info[2], name)
	if not warned[warn_key] and info[3] ~= "" and info[1] ~= "[C]" then
		core.log("warning", ("Assignment to undeclared global %q inside a function at %s.")
				:format(name, desc))
		warned[warn_key] = true
	end
	declared[name] = true
end


function meta:__index(name)
	if declared[name] then
		return
	end
	local info = {debug.info(2, "sl")}
	local warn_key = ("%s\0%d\0%s"):format(info[1], info[2], name)
	if not warned[warn_key] and info[1] ~= "[C]" then
		core.log("warning", ("Undeclared global variable %q accessed at %s:%s")
				:format(name, info[1], info[2]))
		warned[warn_key] = true
	end
end

setmetatable(_G, meta)
