local idl = require "oil.corba.idl"
local base = require "oil.tests.corba.cdr.base"

local suite = base.newsuite(...)

--------------------------------------------------------------------------------

for name in pairs(idl.BasicTypes) do
	suite:add(name, idl.TypeCode, idl[name])
end

--------------------------------------------------------------------------------

suite:add("string", idl.TypeCode, base.string{ maxlength = 2 }, idl.string)

--------------------------------------------------------------------------------

local values = {
	Object    = base.Object{},
	struct    = base.struct{
		{ name = "field1", type = idl.string },
		{ name = "field2", type = idl.string },
	},
	union     = base.union{
		switch = idl.ulong,
		options = {
			{ label = 1, name = "field1", type = idl.string },
			{ label = 2, name = "field2", type = idl.string },
		},
	},
	enum      = base.enum{ "a", "e", "i", "o", "u" },
	sequence  = base.sequence{ elementtype = idl.string, maxlength = 2 },
	array     = base.array{ elementtype = idl.string, length = 2 },
	typedef   = base.typedef{ original_type = idl.string },
	except    = base.except{
		{ name = "field1", type = idl.string },
		{ name = "field2", type = idl.string },
	},
	valuetype = base.valuetype{
		base_value = base.valuetype{
			name = "BaseValue",
			{ name = "base1", type = idl.string, access = "private" },
			{ name = "base2", type = idl.string, access = "private" },
		},
		{ name = "field1", type = idl.string, access = "private" },
		{ name = "field2", type = idl.string, access = "private" },
	},
}

for name, value in pairs(values) do
	suite:add(name, idl.TypeCode, value)
end

--------------------------------------------------------------------------------

suite:add("duplicated",
	function()
		return idl.TypeCode
	end,
	function()
		local person = base.struct{
			{ name = "name", type = idl.string },
			{ name = "age", type = idl.short },
			{ name = "gender", type = base.enum{ "male", "female" } },
		}
		return base.struct{
			{ name = "husband", type = person },
			{ name = "wife", type = person },
		}
	end)

--------------------------------------------------------------------------------

suite:add("recursive",
	function()
		return idl.TypeCode
	end,
	function()
		local treenode = base.struct{{ name = "value", type = idl.string }}
		local fields = treenode.fields
		fields[#fields+1] = setmetatable({ name = "leaves", type = treenode },
		                                 getmetatable(fields[#fields]))
		return treenode
	end)

--------------------------------------------------------------------------------

suite:add("nesting",
	function()
		return idl.TypeCode, idl.TypeCode
	end,
	function()
		local A = base.struct{
			name = "A",
			{ name = "field1", type = idl.null },
			{ name = "field2", type = idl.null },
		}
		local B = base.struct{
			name = "B",
			{ name = "field1", type = idl.null },
			{ name = "field2", type = A },
		}
		local C = base.struct{
			name = "C",
			{ name = "field1", type = A },
			{ name = "field2", type = B },
		}
		return C, B
	end)

--------------------------------------------------------------------------------

return suite
