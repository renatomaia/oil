local socket   = require "socket"
local Suite    = require "loop.test.Suite"
local Results  = require "loop.test.Results"
local Reporter = require "loop.test.Reporter"

local runner = Results{
	reporter = Reporter{
		time = socket.gettime,
	},
}

runner("LuaIDL", require "luaidl.tests.Suite") -- must be testes before because
                                               -- LuaIDL gets "dirty" when used with
                                               -- callbacks as when OiL uses it.

require("oil").main(function()
	runner("OiL", Suite{
		CDR = require "oil.tests.corba.cdr.Suite",
		IDL = require "oil.tests.corba.idl.TypedefInheritance",
	})
end)
