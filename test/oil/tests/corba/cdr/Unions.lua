local idl = require "oil.corba.idl"
local giop = require "oil.corba.giop"
local base = require "oil.tests.corba.cdr.base"

local suite = base.newsuite(...)
suite:add("AllValues"    , Struct, Value)
suite:add("StrangeValues", Struct, Strange, Expected)
return suite
