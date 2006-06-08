local require  = require
local luaerror = error
local luatype  = type

local string   = require "string"

module "oil.assert"                                                             --[[VERBOSE]] local verbose = require "oil.verbose"

local Viewer    = require "loop.debug.Viewer"
local Exception = require "oil.Exception"
local idl       = require "oil.idl"

function type(value, name, description, exception, minor)
	local ok = false
	if name == "type" then
		ok, name = idl.istype(value), "IDL type"
	elseif name == "idl" then
		ok, name = idl.isspec(value), "IDL specification"
	elseif luatype(value) == name then
		ok = true
	else
		ok = string.match(name, "^idl(%l+)")
		if ok and idl.istype(value)
			then ok, name = (value._type == ok), ("IDL "..ok.." type")
			else ok = false
		end
	end
	if not ok then
		raise({ exception or "INTERNAL", minor_code_value = minor or 0,
			message = "invalid "..description.." ("..
								name.." expected, got "..luatype(value)..")",
			reason = "type",
			element = description,
			type = name,
			value = value,
		}, 2)
	end
end

function illegal(value, description, exception, minor)
	raise({ exception or "INTERNAL", minor_code_value = minor or 0,
		message = "illegal "..description.." (got "..
							Viewer:tostring(value)..")",
		reason = "value",
		element = description,
		value = value,
	}, 2)
end

function raise(ex_body, level)
	error(Exception(ex_body), level and (level + 1) or 1)
end

error = luaerror
--local luaerror = _G.error
--function error(exception, level)
--  if luatype(exception) ~= "string" then
--    exception = tostring(exception)
--  end
--  luaerror(exception, level and (level + 1) or 1)
--end
