local socket   = require "socket"
local Suite    = require "loop.test.Suite"
local Results  = require "loop.test.Results"
local Reporter = require "loop.test.Reporter"

local suite = Suite{
	LuaIDL = require "luaidl.tests.Suite",
--OiL    = require "oil.tests.Suite",
}

local results = Results{
	reporter = Reporter{
		time = socket.gettime,
	},
}
results:test(nil, suite, results)
