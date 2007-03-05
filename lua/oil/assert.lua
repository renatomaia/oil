local luaerror = error
local luatype  = type
local tostring = tostring

local string   = require "string"

local Exception = require "oil.Exception"
local Viewer    = require "loop.debug.Viewer"

module("oil.assert", package.seeall)

viewer = Viewer{ maxdepth = 1 }

function type(value, name, description, except, minor)
	local ok = false
	if name == "type" then
		ok, name = oil.corba.idl.istype(value), "IDL type"
	elseif name == "idl" then
		ok, name = oil.corba.idl.isspec(value), "IDL specification"
	elseif luatype(value) == name then
		ok = true
	else
		ok = string.match(name, "^idl(%l+)")
		if ok and oil.corba.idl.istype(value)
			then ok, name = (value._type == ok), ("IDL "..ok.." type")
			else ok = false
		end
	end
	if not ok then
		exception({ except or "INTERNAL", minor_code_value = minor or 0,
			message = "invalid "..description.." ("..
								name.." expected, got "..luatype(value)..")",
			reason = "type",
			element = description,
			type = name,
			value = value,
		}, 2)
	end
end

function check(...)
	if not ... then error(select(2, ...), 2) end
	return ...
end

function illegal(value, description, except, minor)
	exception({ except or "INTERNAL", minor_code_value = minor or 0,
		message = "illegal "..description.." (got "..viewer:tostring(value)..")",
		reason = "value",
		element = description,
		value = value,
	}, 2)
end

function exception(ex_body, level)
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
