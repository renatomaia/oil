local idl = require "oil.corba.idl"
local giop = require "oil.corba.giop"
local base = require "oil.tests.corba.cdr.base"

local Struct = base.struct{
	{ name = "short_value"  , type = idl.short   },
	{ name = "ushort_value" , type = idl.ushort  },
	{ name = "long_value"   , type = idl.long    },
	{ name = "ulong_value"  , type = idl.ulong   },
	{ name = "float_value"  , type = idl.float   },
	{ name = "double_value" , type = idl.double  },
	{ name = "boolean_value", type = idl.boolean },
	{ name = "char_value"   , type = idl.char    },
	{ name = "octet_value"  , type = idl.octet   },
	{ name = "string_value" , type = idl.string  },
	{ name = "any_value"    , type = idl.any     },
	{ name = "object_value" , type = idl.object  },
}

local Value = setmetatable({
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
}, Struct)

local Strange = {
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

local Expected = setmetatable({
	short_value   = -32768,
	ushort_value  = 0,
	long_value    = -2147483648,
	ulong_value   = 4294967295, -- due to 'struct' (should be 0 due to overflow)
	float_value   = -1/0,
	double_value  = -1/0,
	boolean_value = nil,
	char_value    = "\0",
	octet_value   = 0,
	string_value  = "\0\0\0",
	any_value     = setmetatable({_anytype=idl.null}, idl.null),
	object_value  = nil,
}, Struct)

local suite = base.newsuite(...)
suite:add("AllValues"    , Struct, Value)
suite:add("StrangeValues", Struct, Strange, Expected)
return suite
