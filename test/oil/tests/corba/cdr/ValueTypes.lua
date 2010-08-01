local idl = require "oil.corba.idl"
local giop = require "oil.corba.giop"
local base = require "oil.tests.corba.cdr.base"
local suite = base.newsuite(...)

--------------------------------------------------------------------------------

local AllValues = base.valuetype{
	{ name = "short_value"  , type = idl.short  , access = "private" },
	{ name = "ushort_value" , type = idl.ushort , access = "private" },
	{ name = "long_value"   , type = idl.long   , access = "private" },
	{ name = "ulong_value"  , type = idl.ulong  , access = "private" },
	{ name = "float_value"  , type = idl.float  , access = "private" },
	{ name = "double_value" , type = idl.double , access = "private" },
	{ name = "boolean_value", type = idl.boolean, access = "private" },
	{ name = "char_value"   , type = idl.char   , access = "private" },
	{ name = "octet_value"  , type = idl.octet  , access = "private" },
	{ name = "string_value" , type = idl.string , access = "private" },
	{ name = "any_value"    , type = idl.any    , access = "private" },
	{ name = "object_value" , type = idl.object , access = "private" },
}

local NormalValues = setmetatable({
	short_value   = 32767,
	ushort_value  = 65535,
	long_value    = 2147483647,
	ulong_value   = 4294967295,
	float_value   = 0,
	double_value  = 3.1415926535898,
	boolean_value = true,
	char_value    = "c",
	octet_value   = 255,
	string_value  = "string",
	any_value     = setmetatable({ _anyval = nil, _anytype = idl.null }, idl.null),
	object_value  = setmetatable({
		type_id = "IDL:omg.org/CORBA/Object:1.0",
		profiles = setmetatable({
			setmetatable({
				tag = 9999,
				profile_data = "Fake Profile",
			}, giop.IOR.fields[2].type.elementtype),
		}, giop.IOR.fields[2].type),
	}, giop.IOR),
}, AllValues)

suite:add("AllValues"    , Struct, NormalValues)

--------------------------------------------------------------------------------

local StrangeValues = {
	short_value   = 32768,
	ushort_value  = 65536,
	long_value    = 2147483648,
	ulong_value   = 4294967296,
	float_value   = -1/0,
	double_value  = -1/0,
	boolean_value = nil,
	char_value    = "\0",
	octet_value   = 256,
	string_value  = "\0\0\0",
	any_value     = nil,
	object_value  = nil,
}

local StrangeExpected = setmetatable({
	short_value   = -32768,
	ushort_value  = 0,
	long_value    = -2147483648,
	ulong_value   = 0,
	float_value   = -1/0,
	double_value  = -1/0,
	boolean_value = nil,
	char_value    = "\0",
	octet_value   = 0,
	string_value  = "\0\0\0",
	any_value     = nil,
	object_value  = nil,
}, AllValues)

suite:add("StrangeValues", Struct, StrangeValues, StrangeExpected)

--------------------------------------------------------------------------------

suite:add("nested_indirected_typecodes",
	function(self)
		local base = base.valuetype{
			{ name = "field1", type = idl.TypeCode, access = "private" },
			{ name = "field2", type = idl.TypeCode, access = "private" },
		}
		self.type = base
		return base
	end,
	function(self)
		local struct = base.struct{}
		return setmetatable({
			field1 = struct,
			field2 = struct,
		}, self.type)
	end)

--------------------------------------------------------------------------------

local function setupcodec(codec)
	if codec.types == nil then
		codec.types = {}
		function codec.types:resolve(repid)
			return self[repid]
		end
	end
end

suite:add("truncatable_with_nested_valuetypes",
	function(codec)
		setupcodec(codec)
		local base_value = base.valuetype{ name = "BaseValue" }
		base_value.members[1] = {
			name = "nested",
			type = base_value,
			access = "private",
		}
		base_value.members[2] = {
			name = "self",
			type = base_value,
			access = "private",
		}
		
		codec.base_value = base_value
		
		return base_value
	end,
	function(codec)
		local base_value = codec.base_value
		local type = base.valuetype{
			name = "MyValue",
			base_value = base_value,
			truncatable = true,
			{ name = "baseID" , type = idl.string, access = "private" },
			{ name = "nested2", type = base_value, access = "private" },
			{ name = "self2"  , type = base_value, access = "private" },
			{ name = "repID"  , type = idl.string, access = "private" },
		}
		
		codec.types[base_value.repID] = base_value
		codec.types[type.repID] = type
		
		local value = setmetatable({
			nested = setmetatable({
				baseID = "IDL:BaseValue:1.0",
				repID = "IDL:MyValue:1.0",
			}, type),
			baseID = "IDL:BaseValue:1.0",
			nested2 = setmetatable({}, base_value),
			repID = "IDL:MyValue:1.0",
		}, type)
		value.self = value
		value.self2 = value
		
		return value
	end)

--------------------------------------------------------------------------------

return suite
