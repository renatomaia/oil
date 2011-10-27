local socket   = require "socket"
local Suite    = require "loop.test.Suite"
local Results  = require "loop.test.Results"
local Reporter = require "loop.test.Reporter"

local OiL = Suite{
	LuaIDL = require "luaidl.tests.Suite",
	["CORBA.CDR"] = require "oil.tests.corba.cdr.Suite",
	["CORBA.IDL"] = require "oil.tests.corba.idl.TypedefInheritance",
}

local results = Results{
	reporter = Reporter{
		time = socket.gettime,
	},
}
results.viewer.maxdepth = nil
results:test("OiL", OiL, results)
