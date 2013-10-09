local socket   = require "socket"
local Suite    = require "loop.test.Suite"
local Results  = require "loop.test.Results"
local Reporter = require "loop.test.Reporter"

local LuaIDL = require "luaidl.tests.Suite"
local OiL = Suite{
	["Kernel.Timeout"] = require "oil.tests.kernel.Timeout",
	["CORBA.CDR"] = require "oil.tests.corba.cdr.Suite",
	["CORBA.IDL"] = require "oil.tests.corba.idl.TypedefInheritance",
}

local results = Results{
	reporter = Reporter{
		time = socket.gettime,
	},
}
results:test("LuaIDL", LuaIDL, results) -- must be testes before because LuaIDL
                                        -- gets "dirty" when used with callbacks
                                        -- as when OiL uses it.
results:test("OiL", OiL, results)
