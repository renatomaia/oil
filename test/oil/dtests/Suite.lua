local Suite = require "loop.test.Suite"
return Suite{
	MethodInvocation = require "oil.dtests.kernel.MethodInvocation",
	ExceptionCatch   = require "oil.dtests.kernel.ExceptionCatch",
	ObjectOperations = require "oil.dtests.corba.ObjectOperations",
}
