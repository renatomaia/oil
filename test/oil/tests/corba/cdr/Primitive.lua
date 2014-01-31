local vararg = require "vararg"
local idl = require "oil.corba.idl"
local base = require "oil.tests.corba.cdr.base"

local Values = {
	void    = vararg.pack( nil ),
	short   = vararg.pack( 0, 12345, 32767, -32768 ),
	ushort  = vararg.pack( 0, 12345, 65535 ),
	long    = vararg.pack( 0, 1234567890, 2147483647, -2147483648 ),
	ulong   = vararg.pack( 0, 1234567890, 4294967295 ),
	float   = vararg.pack( 0, -0, 12345 ),
	double  = vararg.pack( 0, -0, 3.1415926535898 ),
	boolean = vararg.pack( true, false ),
	char    = vararg.pack( "a", "Z", "1", "0", "\n", "\t", "\0" ),
	octet   = vararg.pack( 0, 123, 255 ),
	string  = vararg.pack( "\n\t\0aZ10" ),
}

local suite = base.newsuite(...)
for name, values in pairs(Values) do
	for index, value in values do
		local tid = name..":"..tostring(value):gsub("\n","\\n")
		                                      :gsub("\t","\\t")
		                                      :gsub("%z","\\0")
		suite:add(tid, idl[name], value)
	end
end
suite:add("boolean:nil", idl.boolean, nil, false)
return suite