local streampath = (os.getenv("OIL_HOME") or "..")..
                   "/test/oil/tests/corba/cdr/streams/"

local oo = require "loop.base"
local Suite = require "loop.test.Suite"
local bit = require "oil.bit"
local idl = require "oil.corba.idl"
local Codec = require "oil.corba.giop.Codec"
local CodecGen = require "oil.corba.giop.CodecGen"

local SequenceTestKey = {}

local function hexdump(stream, expected)
	local lines = string.format("%%0%dx:", math.ceil(math.log10(math.ceil(#stream/16))+1))
	local count = 0
	local pos = cursor
	local dump = {}
	local chars = {}
	local wasdiff
	for char in stream:gmatch("(.)") do
		column = math.mod(count, 16)
		if column == 0 then
			dump[#dump+1] = lines:format(count)
		elseif column == 8 then
			dump[#dump+1] = " "
		end
		local isdiff = (expected ~= nil and expected:sub(count+1,count+1) ~= char)
		if not wasdiff and isdiff then
			dump[#dump+1] = "["
		elseif wasdiff and not isdiff then
			dump[#dump+1] = "]"
		else
			dump[#dump+1] = " "
		end
		wasdiff = isdiff
		local byte = string.byte(char)
		dump[#dump+1] = string.format("%02x", byte)
		if byte < 32 then
			chars[#chars+1] = "?"
		elseif byte > 126 then
			chars[#chars+1] = "."
		else
			chars[#chars+1] = char
		end
		count = count + 1
		if count == #stream then
			dump[#dump+1] = string.rep("   ", 15-column)
			if column < 8 then dump[#dump+1] = " " end
			column = 15
		end
		if column == 15 then
			local next = count+1
			local willdiff = expected ~= nil and
			                 expected:sub(next, next) ~= stream:sub(next, next)
			if wasdiff and not willdiff then
				dump[#dump+1] = "]"
				wasdiff = nil
			else
				dump[#dump+1] = " "
			end
			dump[#dump+1] = " |"..table.concat(chars).."|\n"
			chars = {}
		end
	end
	if wasdiff then
		dump[#dump+1] = "]"
	end
	return table.concat(dump)
end

local function newcase(suite, testID, codec, byteorder, shift, idltype, value, expected)
	local fileID = string.gsub(suite.ID..testID..byteorder..shift, "%W", "_")
	return function(checks)
		if type(idltype) == "function" then
			idltype = {idltype(codec)}
			value = {value(codec)}
			expected = {expected(codec)}
		elseif getmetatable(idltype) ~= SequenceTestKey then
			idltype = {idltype}
			value = {value}
			expected = {expected}
		end
		
		local streams = {}
		for i, idltype in ipairs(idltype) do
			local encoder = codec:encoder(byteorder == "Encapsulated")
			if byteorder == "Inverted" then
				encoder.pack = oil.bit.invpack
			end
			encoder:jump(shift)
			encoder:put(value[i], idltype)
			local stream = encoder:getdata()
			
			streams[i] = stream
			
			local decoder = codec:decoder(stream, byteorder == "Encapsulated")
			if byteorder == "Inverted" then
				decoder:order(not Codec.NativeEndianess)
			end
			decoder:jump(shift)
			local actual = decoder:get(idltype)
			checks:assert(actual, checks.similar(expected[i], nil, {metatable = true}))
		end
		
		streams = table.concat(streams)
		local filename = streampath..fileID..".stream"
		local file = io.open(filename, "rb")
		if file == nil then
			file = assert(io.open(filename, "wb"))
			file:write(streams)
		else
			local previous = file:read("*a")
			if streams ~= previous then
				checks:assert(false, "wrong stream\nGot:\n"..
					hexdump(streams, previous)..
					"\nExpected:\n"..
					hexdump(previous, streams))
			end
		end
		file:close()
	end
end

local function addcases(suite, testID, type, value, ...)
	local expected = ...
	if select("#", ...) == 0 then
		expected = value
	end
	local impls = Suite()
	--for implname, factory in pairs{ Codec = Codec, CodecGen = CodecGen } do
	for implname, factory in pairs{ Codec = Codec, --[[CodecGen = CodecGen]] } do
		local codec = factory()
		codec.context = codec
		codec.__component = codec
		local case = Suite()
		for _, byteorder in ipairs{"Normal","Inverted","Encapsulated"} do
			local tests = Suite()
			for shift = 0, 8, 2 do
				shift = math.max(0, shift-1)
				tests["Shift"..shift] = newcase(suite, testID,
				                                codec, byteorder, shift,
				                                type, value, expected)
			end
			case[byteorder.."ByteOrder"] = tests
		end
		impls[implname] = case
	end
	suite[testID] = impls
end

local StructFieldsType = Codec.TypeCodeInfo[15].parameters.fields[3].type
local UnionOptionsType = Codec.TypeCodeInfo[16].mutable[1].type
local EnumValuesType = Codec.TypeCodeInfo[17].parameters.fields[3].type
local ExceptMembersType = Codec.TypeCodeInfo[22].parameters.fields[3].type
local ValueMembersType = Codec.TypeCodeInfo[29].parameters.fields[5].type

local function takefield(def, field)
	local value = def[field]
	if value ~= nil then
		def[field] = nil
		return value
	end
end

return {
	newsuite = function(suiteID)
		suiteID = suiteID:match("^oil%.tests%.corba%.cdr%.(.+)$") or suiteID
		local class = oo.class{
			__call = Suite.__call,
			ID = suiteID,
			add = addcases,
		}
		return class()
	end,
	
	seqtest = function(...)
		return setmetatable({...}, SequenceTestKey)
	end,
	
	Object = function(def)
		def.name = def.name or "ObjectType"
		return idl.Object(def)
	end,
	
	valuetype = function(members)
		setmetatable(members, ValueMembersType)
		for _, member in ipairs(members) do
			setmetatable(member, ValueMembersType.elementtype)
		end
		return idl.valuetype{
			name = takefield(members, "name") or "ValueType",
			base_value = takefield(members, "base_value"),
			members = members,
		}
	end,
	
	struct = function(fields)
		setmetatable(fields, StructFieldsType)
		for _, field in ipairs(fields) do
			setmetatable(field, StructFieldsType.elementtype)
		end
		return idl.struct{
			name = takefield(fields, "name") or "Structure",
			fields = fields,
		}
	end,
	union = function(def)
		setmetatable(def.options, UnionOptionsType)
		for _, option in ipairs(def.options) do
			setmetatable(option, UnionOptionsType.elementtype)
		end
		def.name = def.name or "ValueUnion"
		return idl.union(def)
	end,
	string = function(def)
		def._type = "string"
		return def
	end,
	enum = function(values)
		setmetatable(values, EnumValuesType)
		return idl.enum{
			name = takefield(values, "name") or "Enumeration",
			enumvalues = values,
		}
	end,
	sequence = idl.sequence,
	array = idl.array,
	typedef = function(def)
		def.name = def.name or "TypeDefinition"
		return idl.typedef(def)
	end,
	except = function(members)
		setmetatable(members, ExceptMembersType)
		for _, field in ipairs(members) do
			setmetatable(field, ExceptMembersType.elementtype)
		end
		return idl.except{
			name = takefield(members, "name") or "Exception",
			members = members,
		}
	end,
}
