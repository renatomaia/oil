local Suite = require "loop.test.Suite"

return Suite{
	Primitive = require "oil.tests.corba.cdr.Primitive",
	Structs = require "oil.tests.corba.cdr.Structs",
	TypeCodes = require "oil.tests.corba.cdr.TypeCodes",
	Anys = require "oil.tests.corba.cdr.Anys",
}