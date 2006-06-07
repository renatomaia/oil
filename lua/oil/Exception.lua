local type         = type
local error        = error
local pairs        = pairs
local tostring     = tostring
local getmetatable = getmetatable                                               --[[VERBOSE]] local require = require

local table = require "table"
local debug = require "debug"
local oo    = require "oil.oo"

module("oil.Exception", oo.class)                                               --[[VERBOSE]] local verbose = require "oil.verbose"

local Exception = _M

function Exception:__init(except)
	local idltype = getmetatable(except)
	if (not except[1]) and idltype and idltype.repID then
		except[1] = idltype.repID
	end
	if not except.traceback then
		except.traceback = debug.traceback()
	end
	return oo.rawnew(self, except)
end

function Exception.__concat(op1, op2)
	if oo.instanceof(op1, Exception) then
		op1 = op1:__tostring()
	elseif type(op1) ~= "string" then
		error("attempt to concatenate a "..type(op1).." value")
	end
	if oo.instanceof(op2, Exception) then
		op2 = op2:__tostring()
	elseif type(op2) ~= "string" then
		error("attempt to concatenate a "..type(op2).." value")
	end
	return op1 .. op2
end

function Exception:__tostring()
	local message = { "Exception ", self[1], " raised" }
	if self.message then
		table.insert(message, ": ")
		table.insert(message, self.message)
	end
	for field, value in pairs(self) do
		if
			type(field) == "string" and
			field ~= "message" and
			value ~= self
		then
			table.insert(message, "\n  ")
			table.insert(message, field)
			table.insert(message, ": ")
			table.insert(message, tostring(value))
		end
	end
	return table.concat(message)
end
