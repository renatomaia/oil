local _G = require "_G"
local pairs = _G.pairs

local idl  = require "oil.corba.idl"
local giop = require "oil.corba.giop"

local CORBA = idl.module{
	name = "CORBA",
	repID = "IDL:omg.org/CORBA:1.0",
}

for name in pairs(giop.SystemExceptionIDs) do
	CORBA.definitions[name] = idl.except{
		{name = "minor" , type = idl.ulong },
		{name = "completed", type = giop.CompletionStatus },
	}
end

return CORBA
