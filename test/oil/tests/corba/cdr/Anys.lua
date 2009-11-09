local idl = require "oil.corba.idl"
local base = require "oil.tests.corba.cdr.base"

--------------------------------------------------------------------------------

local function anywithstruct(fields, type)
	local value = setmetatable(fields, type)
	value._anyval = value
	value._anytype = type
	return value
end

local StructType = function()
	return base.struct{
		{ name = "number", type = idl.double },
		{ name = "text"  , type = idl.string },
	}
end

local ExpectedValue = function()
	return anywithstruct({number=123, text="text"}, StructType())
end

--------------------------------------------------------------------------------

local suite = base.newsuite(...)

--------------------------------------------------------------------------------

suite:add("Nil"   , idl.any, nil  , setmetatable({ _anyval = nil  , _anytype = idl.null    }, idl.null   ))
suite:add("True"  , idl.any, true , setmetatable({ _anyval = true , _anytype = idl.boolean }, idl.boolean))
suite:add("False" , idl.any, false, setmetatable({ _anyval = false, _anytype = idl.boolean }, idl.boolean))
suite:add("Number", idl.any, 123  , setmetatable({ _anyval = 123  , _anytype = idl.double  }, idl.double ))
suite:add("String", idl.any, "s"  , setmetatable({ _anyval = "s"  , _anytype = idl.string  }, idl.string ))

suite:add("ExplicitFalse" , idl.any, { _anyval = nil, _anytype = idl.boolean }, setmetatable({ _anyval = false, _anytype = idl.boolean }, idl.boolean))
suite:add("ExplicitTrue"  , idl.any, { _anyval = 0  , _anytype = idl.boolean }, setmetatable({ _anyval = true , _anytype = idl.boolean }, idl.boolean))
suite:add("ExplicitUShort", idl.any, { _anyval = 123, _anytype = idl.ushort } , setmetatable({ _anyval = 123  , _anytype = idl.ushort  }, idl.ushort ))
suite:add("ExplicitChar"  , idl.any, { _anyval = "c", _anytype = idl.char }   , setmetatable({ _anyval = "c"  , _anytype = idl.char    }, idl.char   ))

--------------------------------------------------------------------------------

suite:add("TypeAsField",
	function() return idl.any end,
	function() return {number=123, text="text", _anytype=StructType()} end,
	ExpectedValue)

suite:add("TypeAsMetatable",
	function() return idl.any end,
	function() return setmetatable({number=123, text="text"}, StructType()) end,
	ExpectedValue)

suite:add("TypeAsMetaField",
	function() return idl.any end,
	function() return setmetatable({number=123, text="text"}, {__type=StructType()}) end,
	ExpectedValue)

--------------------------------------------------------------------------------

suite:add("Userdata",
	function()
		return idl.any
	end,
	function()
		local Userdata = newproxy(true)
		local Metatable = getmetatable(Userdata)
		Metatable.__index = {number=123, text="text"}
		Metatable.__type = StructType()
		return Userdata
	end,
	ExpectedValue)

--------------------------------------------------------------------------------

local SequenceOfAnys

suite:add("AnysWithSharedType",
	function()
		SequenceOfAnys = base.sequence{elementtype=idl.any}
		return SequenceOfAnys, idl.any
	end,
	function()
		local AStructType = StructType()
		local TopMostStruct = anywithstruct({number=1, text="topmost"}, AStructType)
		local AnyWithNestedStruct = anywithstruct(
			{
				field1 = "text",
				field2 = setmetatable({number=2, text="nested"}, AStructType),
			},
			base.struct{
				{ name = "field1", type = idl.string },
				{ name = "field2", type = AStructType },
			}
		)
		return {TopMostStruct, AnyWithNestedStruct}, AnyWithNestedStruct
	end,
	function()
		local AStructType = StructType()
		local TopMostStruct = anywithstruct({number=1, text="topmost"}, AStructType)
		local OtherStructType = StructType() -- other struct similar to the first
		local AnyWithNestedStruct = anywithstruct(
			{
				field1 = "text",
				field2 = setmetatable({number=2, text="nested"}, OtherStructType),
			},
			base.struct{
				{ name = "field1", type = idl.string },
				{ name = "field2", type = OtherStructType },
			}
		)
		local TwoAnys = setmetatable({TopMostStruct, AnyWithNestedStruct, n=2},
		                             SequenceOfAnys)
		return TwoAnys, AnyWithNestedStruct
	end)

--------------------------------------------------------------------------------

return suite
