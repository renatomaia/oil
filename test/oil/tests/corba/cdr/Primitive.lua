local idl = require "oil.corba.idl"
local base = require "oil.tests.corba.cdr.base"

local Values = {
	void    = { nil },
	short   = { 0, 12345, 32767, -32768 },
	ushort  = { 0, 12345, 65535 },
	long    = { 0, 1234567890, 2147483647, -2147483648 },
	ulong   = { 0, 1234567890, 4294967295 },
	float   = { 0, -0, 12345 },
	double  = { 0, -0, 3.1415926535898 },
	boolean = { true, false, nil },
	char    = { "a", "Z", "1", "0", "\n", "\t", "\0" },
	octet   = { 0, 123, 255 },
	string  = { "\n\t\0aZ10" },
}

local suite = base.newsuite(...)
for name, values in pairs(Values) do
	for index, value in ipairs(values) do
		local tid = name..":"..tostring(value):gsub("\n","\\n")
		                                      :gsub("\t","\\t")
		                                      :gsub("%z","\\0")
		suite:add(tid, idl[name], value)
	end
end
return suite