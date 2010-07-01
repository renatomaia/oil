local pairs = pairs

local idl  = require "oil.corba.idl"
local giop = require "oil.corba.giop"                                           --[[VERBOSE]] local verbose = require "oil.verbose"

module "oil.corba.idl.sysex"

--------------------------------------------------------------------------------

name = "CORBA"
repID = "IDL:omg.org/CORBA:1.0"
idl.module(_M)

--------------------------------------------------------------------------------

for name, repID in pairs(giop.SystemExceptionIDs) do
	definitions[name] = idl.except{
		{name = "minor" , type = idl.ulong },
		{name = "completed", type = giop.CompletionStatus },
	}
end
