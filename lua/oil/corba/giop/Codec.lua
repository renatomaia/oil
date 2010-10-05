--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua: An Object Request Broker in Lua                 --
-- Release: 0.5                                                               --
-- Title  : Mapping of Lua values into Common Data Representation (CDR)       --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------
-- decoder interface:                                                         --
--   order(value)    Change or return the endianess of the buffer             --
--   jump(shift)     Places an empty space in the data of the buffer          --
--   getdata()       Returns the raw data stream of marshalled data           --
--   get(type)       Unmarhsall a value of the given type                     --
--                                                                            --
--   void()          Unmarshal a void type value                              --
--   short()         Unmarshal an integer type short value                    --
--   long()          Unmarshal an integer type long value                     --
--   ushort()        Unmarshal an integer type unsigned short value           --
--   ulong()         Unmarshal an integer type unsigned long value            --
--   float()         Unmarshal a floating-point nxmeric type value            --
--   double()        Unmarshal a double-precision floating-point num. value   --
--   boolean()       Unmarshal a boolean type value                           --
--   char()          Unmarshal a character type value                         --
--   octet()         Unmarshal a raw byte type value                          --
--   any()           Unmarshal a generic type value                           --
--   TypeCode()      Unmarshal a meta-type value                              --
--   string()        Unmarshal a string type value                            --
--                                                                            --
--   Object(type)    Unmarhsal an Object type value, given its type           --
--   struct(type)    Unmarhsal a struct type value, given its type            --
--   union(type)     Unmarhsal a union type value, given its type             --
--   enum(type)      Unmarhsal an enumeration type value, given its type      --
--   sequence(type)  Unmarhsal a sequence type value, given its type          --
--   array(type)     Unmarhsal an array type value, given its type            --
--   typedef(type)   Unmarhsal a type definition value, given its type        --
--   except(type)    Unmarhsal an expection value, given its type             --
--                                                                            --
--   interface(type) Unmarshall an object reference of a given interface      --
--                                                                            --
-- encoder interface:                                                         --
--   order(value)         Change or return the endianess of the buffer        --
--   jump(shift)          Jump an empty space in the data of the buffer       --
--   getdata()            Returns the raw data stream of marshalled data      --
--   put(type)            Marhsall a value of the given type                  --
--                                                                            --
--   void(value)          Marshal a void type value                           --
--   short(value)         Marshal an integer type short value                 --
--   long(value)          Marshal an integer type long value                  --
--   ushort(value)        Marshal an integer type unsigned short value        --
--   ulong(value)         Marshal an integer type unsigned long value         --
--   float(value)         Marshal a floating-point numeric type value         --
--   double(value)        Marshal a double-prec. floating-point num. value    --
--   boolean(value)       Marshal a boolean type value                        --
--   char(value)          Marshal a character type value                      --
--   octet(value)         Marshal a raw byte type value                       --
--   any(value)           Marshal a generic type value                        --
--   TypeCode(value)      Marshal a meta-type value                           --
--   string(value)        Marshal a string type value                         --
--                                                                            --
--   Object(value, type)  Marhsal an Object type value, given its type        --
--   struct(value, type)  Marhsal a struct type value, given its type         --
--   union(value, type)   Marhsal an union type value, given its type         --
--   enum(value, type)    Marhsal an enumeration type value, given its type   --
--   sequence(value, type)Marhsal a sequence type value, given its type       --
--   array(value, type)   Marhsal an array type value, given its type         --
--   typedef(value, type) Marhsal a type definition value, given its type     --
--   except(value, type)  Marhsal an expection value, given its type          --
--                                                                            --
--   interface(value,type)Marshall an object reference of a given interface   --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--   See section 15.3 of CORBA 3.0 specification.                             --
--------------------------------------------------------------------------------
-- codec:Facet
-- 	encoder:object encoder()
-- 	decoder:object decoder(stream:string)
-- 
-- proxies:Receptacle
-- 	proxy:object proxyto(ior:table, iface:table|string)
-- 
-- servants:Receptacle
-- 	proxy:object register(implementation:object, iface:table|string)
--------------------------------------------------------------------------------

local getmetatable = getmetatable
local ipairs       = ipairs
local pairs        = pairs
local setmetatable = setmetatable
local tonumber     = tonumber
local type         = type

local math   = require "math"
local string = require "string"
local table  = require "table"

local oo     = require "oil.oo"
local assert = require "oil.assert"
local bit    = require "oil.bit"
local idl    = require "oil.corba.idl"
local giop   = require "oil.corba.giop"                                         --[[VERBOSE]] local verbose = require "oil.verbose"; local CURSOR, CODEC, verbose_marshal, verbose_unmarshal = {}

module("oil.corba.giop.Codec", oo.class)

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

UnionLabelInfo = { name = "label", type = idl.void }

--------------------------------------------------------------------------------
-- TypeCode information --------------------------------------------------------

-- NOTE: Description of type code categories, which is defined by field type
--	empty  : no further parameters are necessary to specify the associated
--           type.
--	simple : parameters that specify the associated type are defined as a
--           sequence of values.
--	complex: parameters that specify the associated type are defined as a
--           structure defined in idl that is stored in a encapsulated octet
--           sequence (i.e. which endianess may differ).

TypeCodeInfo = {
	[0]  = {name = "null"     , type = "empty", idl = idl.null     }, 
	[1]  = {name = "void"     , type = "empty", idl = idl.void     }, 
	[2]  = {name = "short"    , type = "empty", idl = idl.short    },
	[3]  = {name = "long"     , type = "empty", idl = idl.long     },
	[4]  = {name = "ushort"   , type = "empty", idl = idl.ushort   },
	[5]  = {name = "ulong"    , type = "empty", idl = idl.ulong    },
	[6]  = {name = "float"    , type = "empty", idl = idl.float    },
	[7]  = {name = "double"   , type = "empty", idl = idl.double   },
	[8]  = {name = "boolean"  , type = "empty", idl = idl.boolean  },
	[9]  = {name = "char"     , type = "empty", idl = idl.char     },
	[10] = {name = "octet"    , type = "empty", idl = idl.octet    },
	[11] = {name = "any"      , type = "empty", idl = idl.any      },
	[12] = {name = "TypeCode" , type = "empty", idl = idl.TypeCode },
	[13] = {name = "Principal", type = "empty", idl = idl.Principal, unhandled = true},

	[14] = {name = "Object", type = "complex",
		parameters = idl.struct{
			{name = "repID", type = idl.string},
			{name = "name" , type = idl.string},
		},
	},
	[15] = {name = "struct", type = "complex",
		parameters = idl.struct{
			{name = "repID" , type = idl.string},
			{name = "name"  , type = idl.string},
			{name = "fields", type = idl.sequence{
				idl.struct{
					{name = "name", type = idl.string},
					{name = "type", type = idl.TypeCode}
				},
			}},
		},
	},
	[16] = {name = "union", type = "complex",
		parameters = idl.struct{
			{name = "repID"  , type = idl.string  },
			{name = "name"   , type = idl.string  },
			{name = "switch" , type = idl.TypeCode},
			{name = "default", type = idl.long    },
		},
		mutable = {
			{name = "options", type = idl.sequence{
				idl.struct{
					UnionLabelInfo, -- NOTE: depends on field 'switch'.
					{name = "name" , type = idl.string  },
					{name = "type" , type = idl.TypeCode},
				},
			}},
			setup = function(self, union)
				UnionLabelInfo.type = union.switch
				return self
			end,
		},
	},
	[17] = {name = "enum", type = "complex",
		parameters = idl.struct{
			{name = "repID"     , type = idl.string              },
			{name = "name"      , type = idl.string              },
			{name = "enumvalues", type = idl.sequence{idl.string}},
		}
	},
	[18] = {name = "string", type = "simple", idl = idl.string,
		parameters = {
			{name = "maxlength", type = idl.ulong}
		},
	},
	[19] = {name = "sequence", type = "complex",
		parameters = idl.struct{
			{name = "elementtype", type = idl.TypeCode},
			{name = "maxlength"  , type = idl.ulong   },
		}
	},
	[20] = {name = "array", type = "complex",
		parameters = idl.struct{
			{name = "elementtype", type = idl.TypeCode},
			{name = "length"     , type = idl.ulong   },
		}
		},
	[21] = {name = "typedef", type = "complex",
		parameters = idl.struct{
			{name = "repID", type = idl.string  },
			{name = "name" , type = idl.string  },
			{name = "type" , type = idl.TypeCode},
		},
	},
	[22] = {name = "except", type = "complex",
		parameters = idl.struct{
			{name = "repID", type = idl.string},
			{name = "name",  type = idl.string},
			{name = "members", type = idl.sequence{
				idl.struct{
					{name = "name", type = idl.string  },
					{name = "type", type = idl.TypeCode},
				},
			}},
		},
	},
	
	[23] = {name = "longlong"  , type = "empty", idl = idl.longlong  }, 
	[24] = {name = "ulonglong" , type = "empty", idl = idl.ulonglong },
	[25] = {name = "longdouble", type = "empty", idl = idl.longdouble},
	[26] = {name = "wchar"     , type = "empty", unhandled = true},
	
	[27] = {name = "wstring", type = "simple", unhandled = true, kind = "wstring",
		parameters = {
			{name = "maxlength", type = idl.ulong},
		},
	},
	[28] = {name = "fixed", type = "simple", unhandled = true, kind = "fixed",
		parameters = {
			{name = "digits", type = idl.ushort},
			{name = "scale" , type = idl.short },
		},
	},
	
	[29] = {name = "value" , type = "complex", unhandled = true,
		parameters = {
			{name = "repID"     , type = idl.string  },
			{name = "name"      , type = idl.string  },
			{name = "kind"      , type = idl.short   },
			{name = "base_value", type = idl.TypeCode},
			{name = "members", type = idl.sequence{
				idl.struct{
					{name = "name"  , type = idl.string  },
					{name = "type"  , type = idl.TypeCode},
					{name = "access", type = idl.short   },
				},
			}},
		},
	},
	[30] = {name = "value_box", type = "complex", unhandled = true,
		parameters = {
			{name = "repID"            , type = idl.string  },
			{name = "name"             , type = idl.string  },
			{name = "original_type_def", type = idl.TypeCode},
		},
	},
	[31] = {name = "native"            , type = "complex", unhandled = true},
	[32] = {name = "abstract_interface", type = "complex", unhandled = true},
	
	[4294967295] = {name="none", type = "simple"}, -- indirection marker (0xffffffff)
}

--------------------------------------------------------------------------------
-- Local module functions ------------------------------------------------------

local function alignbuffer(self, alignment)
	local extra = math.mod(self.cursor - 1, alignment)
	if extra > 0 then self:jump(alignment - extra) end
end

NativeEndianess = (bit.endianess() == "little")

--------------------------------------------------------------------------------
--   ##   ##   #####   ######    ######  ##   ##   #####   ##       ##        --
--   ### ###  ##   ##  ##   ##  ##       ##   ##  ##   ##  ##       ##        --
--   #######  #######  ######    #####   #######  #######  ##       ##        --
--   ## # ##  ##   ##  ##   ##       ##  ##   ##  ##   ##  ##       ##        --
--   ##   ##  ##   ##  ##   ##  ######   ##   ##  ##   ##  #######  #######   --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Unmarshalling buffer class --------------------------------------------------

Encoder = oo.class {
	previousend = 0,
	cursor = 1,
	emptychar = '\255', -- character used in buffer alignment
	pack = bit.pack,    -- use current platform native endianess
}

function Encoder:__new(object)
	self = oo.rawnew(self, object)
	self.format = {}
	return self
end

function Encoder:shift(shift)
	self.cursor = self.cursor + shift
end

function Encoder:jump(shift)
	self.format[#self.format+1] = '"'
	self[#self+1] = string.rep(self.emptychar, shift)
	self.cursor = self.cursor + shift
end

function Encoder:rawput(format, data, size)
	self.format[#self.format+1] = format
	self[#self+1] = data                                                          --[[VERBOSE]] CURSOR[self.cursor] = true; if CODEC == nil then CODEC = self end
	self.cursor = self.cursor + size
end

function Encoder:put(value, idltype)
	local marshal = self[idltype._type]
	if not marshal then
		assert.illegal(idltype._type, "supported type", "MARSHAL")
	end
	return marshal(self, value, idltype)
end

function Encoder:getdata()
	return self.pack(table.concat(self.format), self)
end

function Encoder:getlength()
	return self.cursor - 1
end

local NilEnabledTypes = {
	any = true,
	boolean = true,
	Object = true,
	interface = true,
}

--------------------------------------------------------------------------------
-- Marshalling functions -------------------------------------------------------

local function numbermarshaller(size, format)
	return function (self, value)                                                 --[[VERBOSE]] verbose_marshal(self, format, value)
		assert.type(value, "number", "numeric value", "MARSHAL")
		alignbuffer(self, size)
		self:rawput(format, value, size)
	end
end

Encoder.null       = function() end
Encoder.void       = Encoder.null
Encoder.short      = numbermarshaller( 2, "s")
Encoder.long       = numbermarshaller( 4, "l")
Encoder.longlong   = numbermarshaller( 8, "g")
Encoder.ushort     = numbermarshaller( 2, "S")
Encoder.ulong      = numbermarshaller( 4, "L")
Encoder.ulonglong  = numbermarshaller( 8, "G")
Encoder.float      = numbermarshaller( 4, "f")
Encoder.double     = numbermarshaller( 8, "d")
Encoder.longdouble = numbermarshaller(16, "D")
	
function Encoder:boolean(value)                                                 --[[VERBOSE]] verbose_marshal(true, self, idl.boolean)
	if value
		then self:octet(1)
		else self:octet(0)
	end                                                                           --[[VERBOSE]] verbose_marshal(false)
end

function Encoder:char(value)                                                    --[[VERBOSE]] verbose_marshal(self, idl.char, value)
	assert.type(value, "string", "character", "MARSHAL")
	if #value ~= 1 then
		assert.illegal(value, "character", "MARSHAL")
	end
	self:rawput('"', value, 1)
end

function Encoder:octet(value)                                                   --[[VERBOSE]] verbose_marshal(self, idl.octet, value)
	assert.type(value, "number", "octet value", "MARSHAL")
	self:rawput("B", value, 1)
end

local DefaultMapping = {
	number  = idl.double,
	string  = idl.string,
	boolean = idl.boolean,
	["nil"] = idl.null,
}
function Encoder:any(value)                                                     --[[VERBOSE]] verbose_marshal(true, self, idl.any)
	local luatype = type(value)
	local idltype = DefaultMapping[luatype]
	if not idltype then
		local metatable = getmetatable(value)
		if metatable then
			if idl.istype(metatable) then
				idltype = metatable
			elseif idl.istype(metatable.__type) then
				idltype = metatable.__type
			end
		end
		if luatype == "table" then
			if not idltype then
				idltype = value._anytype
				if idl.istype(idltype) then
					if value._anyval ~= nil or NilEnabledTypes[idltype._type] then
						value = value._anyval
					end
				else
					idltype = nil
				end
			end
		end
	end
	if not idltype then
		assert.illegal(value, "any, unable to map to an idl type", "MARSHAL")
	end                                                                           --[[VERBOSE]] verbose_marshal "[type of any]"
	self:TypeCode(idltype)                                                        --[[VERBOSE]] verbose_marshal "[value of any]"
	self:put(value, idltype)                                                      --[[VERBOSE]] verbose_marshal(false)
end

local NullReference = { type_id = "", profiles = { n=0 } }
function Encoder:Object(value, idltype)                                         --[[VERBOSE]] verbose_marshal(true, self, idltype, value)
	local reference
	if value == nil then
		reference = NullReference
	else
		local metatable = getmetatable(value)
		if metatable == giop.IOR
		or metatable and metatable.__type == giop.IOR
		then
			reference = value
		else
			assert.type(value, "table", "object reference", "MARSHAL")
			reference = value.__reference
			if not reference then
				local servants = self.servants
				if servants then                                                        --[[VERBOSE]] verbose_marshal(true, "implicit servant creation")
					value = assert.results(servants:register{
						__servant = value,
						__type = servants.getfield(value, "__type") or idltype,
					})                                                                    --[[VERBOSE]] verbose_marshal(false)
					reference = value.__reference
				else
					assert.illegal(value, "Object, unable to create from value", "MARHSAL")
				end
			end
		end
	end
	self:struct(reference, giop.IOR)                                              --[[VERBOSE]] verbose_marshal(false)
end

function Encoder:struct(value, idltype)                                         --[[VERBOSE]] verbose_marshal(true, self, idltype)
	for _, field in ipairs(idltype.fields) do
		local val = value[field.name]                                               --[[VERBOSE]] verbose_marshal("[field ",field.name,"]")
		if val == nil and not NilEnabledTypes[field.type._type] then
			assert.illegal(value,
			              "struct value (no value for field "..field.name..")",
			              "MARSHAL")
		end
		self:put(val, field.type)
	end                                                                           --[[VERBOSE]] verbose_marshal(false)
end

function Encoder:union(value, idltype)                                          --[[VERBOSE]] verbose_marshal(true, self, idltype)
	assert.type(value, "table", "union value", "MARSHAL")
	local switch = value._switch

	-- Marshal discriminator
	if switch == nil then
		switch = idltype.selector[value._field]
		if switch == nil then
			for _, option in ipairs(idltype.options) do
				if value[option.name] ~= nil then
					switch = option.label
					break
				end
			end
			if switch == nil then
				switch = idltype.options[idltype.default+1]
				if switch == nil then
					assert.illegal(value, "union value (no discriminator)", "MARSHAL")
				end
			end
		end
	end                                                                           --[[VERBOSE]] verbose_marshal "[union switch]"
	self:put(switch, idltype.switch)
	
	local selection = idltype.selection[switch]
	if selection then
		-- Marshal union value
		local unionvalue = value._value
		if unionvalue == nil then
			unionvalue = value[selection.name]
			if unionvalue == nil then
				assert.illegal(value, "union value (none contents)", "MARSHAL")
			end
		end                                                                         --[[VERBOSE]] verbose_marshal("[field ",selection.name,"]")
		self:put(unionvalue, selection.type)
	end                                                                           --[[VERBOSE]] verbose_marshal(false)
end

function Encoder:enum(value, idltype)                                           --[[VERBOSE]] verbose_marshal(true, self, idltype, value)
	value = idltype.labelvalue[value] or tonumber(value)
	if not value then assert.illegal(value, "enum value", "MARSHAL") end
	self:ulong(value)                                                             --[[VERBOSE]] verbose_marshal(false)
end

function Encoder:string(value)                                                  --[[VERBOSE]] verbose_marshal(true, self, idl.string, value)
	assert.type(value, "string", "string value", "MARSHAL")
	local length = #value
	self:ulong(length + 1)
	self:rawput('"', value, length)
	self:rawput('"', '\0', 1)                                                     --[[VERBOSE]] verbose_marshal(false)
end

function Encoder:sequence(value, idltype)                                       --[[VERBOSE]] verbose_marshal(true, self, idltype, value)
	local elementtype = idltype.elementtype
	if type(value) == "string" then
		local length = #value
		self:ulong(length)
		while elementtype._type == "typedef" do elementtype = elementtype.type end
		if elementtype == idl.octet or elementtype == idl.char then
			self:rawput('"', value, length)
		else
			assert.illegal(value, "sequence value (table expected, got string)",
			                      "MARSHAL")
		end
	else
		assert.type(value, "table", "sequence value", "MARSHAL")
		local length = value.n or #value
		self:ulong(length)
		for i = 1, length do                                                        --[[VERBOSE]] verbose_marshal("[element ",i,"]")
			self:put(value[i], elementtype) 
		end
	end                                                                           --[[VERBOSE]] verbose_marshal(false)
end

function Encoder:array(value, idltype)                                          --[[VERBOSE]] verbose_marshal(true, self, idltype, value)
	local elementtype = idltype.elementtype
	if type(value) == "string" then
		while elementtype._type == "typedef" do elementtype = elementtype.type end
		if elementtype == idl.octet or elementtype == idl.char then
			local length = #value
			if length ~= idltype.length then
				assert.illegal(value, "array value (wrong length)", "MARSHAL")
			end
			self:rawput('"', value, length)
		else
			assert.illegal(value, "array value (table expected, got string)",
			                      "MARSHAL")
		end
	else
		assert.type(value, "table", "array value", "MARSHAL")
		for i = 1, idltype.length do                                                --[[VERBOSE]] verbose_marshal("[element ",i,"]")
			self:put(value[i], elementtype)
		end
	end                                                                           --[[VERBOSE]] verbose_marshal(false)
end

function Encoder:typedef(value, idltype)                                        --[[VERBOSE]] verbose_marshal(true, self, idltype, value)
	self:put(value, idltype.type)                                                 --[[VERBOSE]] verbose_marshal(false)
end

function Encoder:except(value, idltype)                                         --[[VERBOSE]] verbose_marshal(true, self, idltype, value)
	assert.type(value, "table", "except value", "MARSHAL")
	for _, member in ipairs(idltype.members) do                                   --[[VERBOSE]] verbose_marshal("[member ", member.name, "]")
		local val = value[member.name]
		if val == nil and not NilEnabledTypes[member.type._type] then
			assert.illegal(value,
			              "except value (no value for member "..member.name..")",
			              "MARSHAL")
		end
		self:put(val, member.type)
	end                                                                           --[[VERBOSE]] verbose_marshal(false)
end

Encoder.interface = Encoder.Object

--------------------------------------------------------------------------------

function Encoder:indirection(marshal, value, ...)
	marshal(self, value, ...)
end

local function indirection(self, marshal, value, ...)
	local history = self.history
	local previous = history[value]
	if previous then
		self:ulong(4294967295) -- indirection marker (0xffffffff)
		local pos = self.previousend + self.cursor                                  --[[VERBOSE]] verbose_marshal("indirection to "..(pos-previous).." bytes away (",pos,"-",previous,").")
		self:long(previous - pos) -- offset
	else
		history[#history+1] = value
		marshal(self, value, ...)
	end
end

local function rawput(self, format, data, size)
	local cursor = self.cursor
	local pos = self.previousend + cursor
	local history = self.history
	for index, value in ipairs(history) do                                        --[[VERBOSE]] verbose_marshal("registering position at ",pos," for future indirection")
		history[value] = pos
		history[index] = nil
	end
	self.format[#self.format+1] = format
	self[#self+1] = data                                                          --[[VERBOSE]] CURSOR[self.cursor] = true; if CODEC == nil then CODEC = self end
	self.cursor = cursor + size
end

function Encoder:encapsulate(value)
	local cursor = (self.previousend or 0) + self.cursor
	local Encoder = oo.getclass(self)
	local encoder = Encoder{
		servants = self.servants,
		proxies = self.proxies,
		history = self.history or { [value] = cursor-4 },
		previousend = cursor-1 + 4, -- adds the size of the OctetSeq count
		indirection = indirection,
		rawput = rawput,
	}
	encoder:boolean(NativeEndianess)
	return encoder
end

local function encodetypeinfo(self, value, kind, tcinfo)
	self:ulong(kind)
	local tcparams = value.tcparams
	if tcparams == nil then
		local temp = self:encapsulate(value)                                        --[[VERBOSE]] verbose_marshal "[parameters values]"
		temp:struct(value, tcinfo.parameters)
		if tcinfo.mutable then                                                      --[[VERBOSE]] verbose_marshal "[mutable parameters values]"
			for _, param in ipairs(tcinfo.mutable:setup(value)) do
				temp:put(value[param.name], param.type)
			end
		end                                                                         --[[VERBOSE]] verbose_marshal(true, "[parameters encapsulation]")
		tcparams = temp:getdata()
		if self.history == nil then
			value.tcparams = tcparams
		end                                                                         --[[VERBOSE]] verbose_marshal(false)
	end
	self:sequence(tcparams, idl.OctetSeq)
end

local TypeCodes = { interface = 14 }
for tcode, info in pairs(TypeCodeInfo) do TypeCodes[info.name] = tcode end

function Encoder:TypeCode(value)                                                --[[VERBOSE]] verbose_marshal(true, self, idl.TypeCode, value)
	assert.type(value, "idl type", "TypeCode value", "MARSHAL")
	local kind   = TypeCodes[value._type]
	local tcinfo = TypeCodeInfo[kind]

	if not kind then assert.illegal(value, "idl type", "MARSHAL") end
	
	if tcinfo.type == "empty" then
		self:ulong(kind)
	elseif tcinfo.type == "simple" then
		self:ulong(kind)
		for _, param in ipairs(tcinfo.parameters) do                                --[[VERBOSE]] verbose_marshal("[parameter ",param.name,"]")
			self:put(value[param.name], param.type)
		end
	else
		self:indirection(encodetypeinfo, value, kind, tcinfo)
	end                                                                           --[[VERBOSE]] verbose_marshal(false)
end

--------------------------------------------------------------------------------
--##  ##  ##  ##  ##   ##   ####   #####    ####  ##  ##   ####   ##     ##   --
--##  ##  ### ##  ### ###  ##  ##  ##  ##  ##     ##  ##  ##  ##  ##     ##   --
--##  ##  ######  #######  ######  #####    ###   ######  ######  ##     ##   --
--##  ##  ## ###  ## # ##  ##  ##  ##  ##     ##  ##  ##  ##  ##  ##     ##   --
-- ####   ##  ##  ##   ##  ##  ##  ##  ##  ####   ##  ##  ##  ##  #####  #####--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Unmarshalling buffer class --------------------------------------------------

Decoder = oo.class{
	previousend = 0,
	cursor = 1,
	unpack = bit.unpack, -- use current platform native endianess
}

function Decoder:__new(object)
	self = oo.rawnew(self, object)
	--if self.history == nil then self.history = {} end
	return self
end

function Decoder:order(value)
	if value ~= NativeEndianess then
		self.unpack = bit.invunpack
	end
end

function Decoder:jump(shift)                                                    --[[VERBOSE]] CURSOR[self.cursor] = true; if CODEC == nil then CODEC = self end
	local cursor = self.cursor
	self.cursor = cursor + shift
	if self.cursor - 1 > #self.data then
		assert.illegal(self.data, "data stream, insufficient data", "MARSHAL")
	end
	return cursor
end

function Decoder:get(idltype)
	local unmarshal = self[idltype._type]
	if not unmarshal then
		assert.illegal(idltype._type, "supported type", "MARSHAL")
	end
	return unmarshal(self, idltype)
end

function Decoder:append(data)
	self.data = self.data..data
end

function Decoder:getdata()
	return self.data
end

--------------------------------------------------------------------------------
-- Unmarshalling functions -----------------------------------------------------

local function numberunmarshaller(size, format)
	return function (self)
		alignbuffer(self, size)                                                     --[[VERBOSE]] verbose_unmarshal(self, format, self.unpack(format, self.data, nil, nil, self.cursor))
		local cursor = self:jump(size) -- check if there is enougth bytes
		return self.unpack(format, self.data, nil, nil, cursor)
	end
end

Decoder.null       = function() end
Decoder.void       = Decoder.null
Decoder.short      = numberunmarshaller( 2, "s")
Decoder.long       = numberunmarshaller( 4, "l")
Decoder.longlong   = numberunmarshaller( 8, "g")
Decoder.ushort     = numberunmarshaller( 2, "S")
Decoder.ulong      = numberunmarshaller( 4, "L")
Decoder.ulonglong  = numberunmarshaller( 8, "G")
Decoder.float      = numberunmarshaller( 4, "f")
Decoder.double     = numberunmarshaller( 8, "d")
Decoder.longdouble = numberunmarshaller(16, "D")

function Decoder:boolean()                                                      --[[VERBOSE]] verbose_unmarshal(true, self, idl.boolean)
	return (self:octet() ~= 0)                                                    --[[VERBOSE]],verbose_unmarshal(false)
end

function Decoder:char()
	local cursor = self:jump(1) --[[check if there is enougth bytes]]             --[[VERBOSE]] verbose_unmarshal(self, idl.char, self.data:sub(cursor, cursor))
	return self.data:sub(cursor, cursor)
end

function Decoder:octet()
	local cursor = self:jump(1) --[[check if there is enougth bytes]]             --[[VERBOSE]] verbose_unmarshal(self, idl.octet, self.unpack("B", self.data, nil, nil, cursor))
	return self.unpack("B", self.data, nil, nil, cursor)
end

function Decoder:any()                                                          --[[VERBOSE]] verbose_unmarshal(true, self, idl.any) verbose:unmarshal "[type of any]"
	local idltype = self:TypeCode()                                               --[[VERBOSE]] verbose_unmarshal "[value of any]"
	local value = self:get(idltype)
	if type(value) == "table" then
		value._anyval = value
		value._anytype = idltype
	else
		value = setmetatable({
			_anyval = value,
			_anytype = idltype,
		}, idltype)
	end                                                                           --[[VERBOSE]] verbose_unmarshal(false)
	return value
end

function Decoder:Object(idltype)                                                --[[VERBOSE]] verbose_unmarshal(true, self, idltype)
	local ior = self:struct(giop.IOR)
	if ior.type_id == "" then                                                     --[[VERBOSE]] verbose_unmarshal "got a null reference"
		ior = nil
	else
		local servants = self.servants
		if servants ~= nil and self.localrefs == "implementation" then
			local entry = servants:islocal(ior)
			if entry ~= nil then                                                      --[[VERBOSE]] verbose_unmarshal("local object with key '",objkey,"' restored") verbose_unmarshal(false)
				return entry.__servant
			end
		end
		local proxies = self.proxies
		if proxies ~= nil then                                                      --[[VERBOSE]] verbose_unmarshal(true, "retrieve proxy for referenced object")
			if idltype._type == "Object" then idltype = idltype.repID end
			ior = assert.results(proxies:newproxy{
				__reference = ior,
				__type = idltype,
			}, "MARSHAL")                                                             --[[VERBOSE]] verbose_unmarshal(false)
		end
	end                                                                           --[[VERBOSE]] verbose_unmarshal(false)
	return ior
end

function Decoder:struct(idltype)                                                --[[VERBOSE]] verbose_unmarshal(true, self, idltype)
	local value = {}
	for _, field in ipairs(idltype.fields) do                                     --[[VERBOSE]] verbose_unmarshal("[field ",field.name,"]")
		value[field.name] = self:get(field.type)
	end                                                                           --[[VERBOSE]] verbose_unmarshal(false)
	return setmetatable(value, idltype)
end

function Decoder:union(idltype)                                                 --[[VERBOSE]] verbose_unmarshal(true, self, idltype) verbose:unmarshal "[union switch]"
	local switch = self:get(idltype.switch)
	local value = { _switch = switch }
	local option = idltype.selection[switch] or
	               idltype.options[idltype.default+1]
	if option then                                                                --[[VERBOSE]] verbose_unmarshal("[field ",option.name,"]")
		value._field = option.name
		value._value = self:get(option.type)
	end                                                                           --[[VERBOSE]] verbose_unmarshal(false)
	return setmetatable(value, idltype)
end

function Decoder:enum(idltype)                                                  --[[VERBOSE]] verbose_unmarshal(true, self, idltype)
	local value = self:ulong() + 1
	if value > #idltype.enumvalues then
		assert.illegal(value, "enumeration value", "MARSHAL")
	end                                                                           --[[VERBOSE]] verbose_unmarshal(false, "got ",idltype.enumvalues[value])
	return idltype.enumvalues[value]
end

function Decoder:string()                                                       --[[VERBOSE]] verbose_unmarshal(true, self, idl.string)
	local length = self:ulong()
	local cursor = self:jump(length) -- check if there is enougth bytes
	local value = self.data:sub(cursor, cursor + length - 2)                      --[[VERBOSE]] verbose_unmarshal(false, "got ",verbose.viewer:tostring(value))
	return value
end

function Decoder:sequence(idltype)                                              --[[VERBOSE]] verbose_unmarshal(true, self, idltype)
	local length      = self:ulong()
	local elementtype = idltype.elementtype
	local value
	while elementtype._type == "typecode" do elementtype = elementtype.type end
	if elementtype == idl.octet or elementtype == idl.char then
		local cursor = self:jump(length) -- check if there is enougth bytes
		value = self.data:sub(cursor, cursor + length - 1)                          --[[VERBOSE]] verbose_unmarshal("got ", verbose.viewer:tostring(value))
	else
		value = setmetatable({ n = length }, idltype)
		for i = 1, length do                                                        --[[VERBOSE]] verbose_unmarshal("[element ",i,"]")
			value[i] = self:get(elementtype)
		end
	end                                                                           --[[VERBOSE]] verbose_unmarshal(false)
	return value
end

function Decoder:array(idltype)                                                 --[[VERBOSE]] verbose_unmarshal(true, self, idltype)
	local length      = idltype.length
	local elementtype = idltype.elementtype
	local value
	while elementtype._type == "typecode" do elementtype = elementtype.type end
	if elementtype == idl.octet or elementtype == idl.char then
		local cursor = self:jump(length) -- check if there is enougth bytes
		value = self.data:sub(cursor, cursor + length - 1)                          --[[VERBOSE]] verbose_unmarshal("got ",verbose.viewer:tostring(value))
	else
		value = setmetatable({}, idltype)
		for i = 1, length do                                                        --[[VERBOSE]] verbose_unmarshal("[element ",i,"]")
			value[i] = self:get(elementtype)
		end
	end                                                                           --[[VERBOSE]] verbose_unmarshal(false)
	return value
end

function Decoder:typedef(idltype)                                               --[[VERBOSE]] verbose_unmarshal(true, self, idltype)
	return self:get(idltype.type)                                                 --[[VERBOSE]],verbose_unmarshal(false)
end

function Decoder:except(idltype)                                                --[[VERBOSE]] verbose_unmarshal(true, self, idltype)
	local value = {}
	for _, member in ipairs(idltype.members) do                                   --[[VERBOSE]] verbose_unmarshal("[member ",member.name,"]")
		value[member.name] = self:get(member.type)
	end                                                                           --[[VERBOSE]] verbose_unmarshal(false)
	return setmetatable(value, idltype)
end

Decoder.interface = Decoder.Object

--------------------------------------------------------------------------------

function Decoder:indirection(unmarshal, value, tag, ...)
	if value == nil then value = {} end
	return unmarshal(self, value, tag, ...)
end

local function indirection(self, unmarshal, value, tag, ...)
	local history = self.history
	if tag == 4294967295 then -- indirection marker (0xffffffff)
		local pos = self.previousend + self.cursor
		local offset = self:long()                                                  --[[VERBOSE]] verbose_unmarshal("got indirection to previously unmarshaled value (at ",pos+offset,", current ",pos,").")
		value = history[pos+offset]
		if value == nil then
			assert.illegal(nil, "indirection offset", "MARSHAL")
		end
	else
		if value == nil then value = {} end
		local pos = self.previousend + self.cursor -4 -- size of tag (a ulong)
		history[pos] = value                                                        --[[VERBOSE]] verbose_unmarshal("registering position at ",pos," for future indirection")
		value = unmarshal(self, value, tag, ...)
	end
	return value
end

function Decoder:encapsulate(stream, value)
	local cursor = (self.previousend or 0) + self.cursor
	local Decoder = oo.getclass(self)
	local decoder = Decoder{
		servants = self.servants,
		proxies = self.proxies,
		data = stream,
		history = self.history or { [cursor -#stream -4 -4] = value },
		previousend = cursor-1 - #stream,
		indirection = indirection,
	}
	decoder:order(decoder:boolean())
	return decoder
end

local function decodetypeinfo(self, value, kind, tcinfo)
	if tcinfo.type == "simple" then
		-- NOTE: The string type is the only simple type being handled,
		--       therefore parameters are ignored.
		for _, param in ipairs(tcinfo.parameters) do                                --[[VERBOSE]] verbose_unmarshal("[parameter ",param.name,"]")
			self:get(param.type)
		end
	elseif tcinfo.type == "complex" then                                          --[[VERBOSE]] verbose_unmarshal(true, "[parameters encapsulation]")
		local tcparams = self:sequence(idl.OctetSeq)
		value._type = tcinfo.name
		if self.history == nil then
			value.tcparams = tcparams
		end
		local temp = self:encapsulate(tcparams, value)                              --[[VERBOSE]] verbose_unmarshal "[parameters values]"
		for _, field in ipairs(tcinfo.parameters.fields) do                         --[[VERBOSE]] verbose_unmarshal("[field ",field.name,"]")
			value[field.name] = temp:get(field.type)
		end
		if tcinfo.mutable then                                                      --[[VERBOSE]] verbose_unmarshal "[mutable parameters values]"
			for _, param in ipairs(tcinfo.mutable:setup(value)) do
				value[param.name] = temp:get(param.type)
			end
		end                                                                         --[[VERBOSE]] verbose_unmarshal(false)
		value = idl[tcinfo.name](value)
	end
	return value
end

function Decoder:TypeCode()                                                     --[[VERBOSE]] verbose_unmarshal(true, self, idl.TypeCode)
	local kind = self:ulong()
	local tcinfo = TypeCodeInfo[kind]
	if tcinfo == nil then assert.illegal(kind, "type code", "MARSHAL") end        --[[VERBOSE]] verbose_unmarshal("TypeCode defines a ",tcinfo.name)
	if tcinfo.unhandled then
		assert.illegal(tcinfo.name, "supported type code", "MARSHAL")
	end
	local value = tcinfo.idl
	if tcinfo.type ~= "empty" then
		value = self:indirection(decodetypeinfo, value, kind, tcinfo)
	end                                                                           --[[VERBOSE]] verbose_unmarshal(false)
	return value
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- NOTE: second parameter indicates an encasulated octet-stream, therefore
--       endianess must be read from stream.
function decoder(self, octets, getorder)
	local decoder = self.Decoder{
		data = octets,
		servants = self.servants,
		proxies = self.proxies,
	}
	if getorder then decoder:order(decoder:boolean()) end
	return decoder
end

-- NOTE: Presence of a parameter indicates an encapsulated octet-stream.
function encoder(self, putorder)
	local encoder = self.Encoder{
		servants = self.servants,
		proxies = self.proxies,
	}
	if putorder then encoder:boolean(NativeEndianess) end
	return encoder
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--[[VERBOSE]] local numtype = {
--[[VERBOSE]] 	s = idl.short,
--[[VERBOSE]] 	l = idl.long,
--[[VERBOSE]] 	g = idl.longlong,
--[[VERBOSE]] 	S = idl.ushort,
--[[VERBOSE]] 	L = idl.ulong,
--[[VERBOSE]] 	G = idl.ulonglong,
--[[VERBOSE]] 	f = idl.float,
--[[VERBOSE]] 	d = idl.double,
--[[VERBOSE]] 	D = idl.longdouble,
--[[VERBOSE]] }
--[[VERBOSE]] verbose.codecop = {
--[[VERBOSE]] 	[Encoder] = "marshal",
--[[VERBOSE]] 	[Decoder] = "unmarshal",
--[[VERBOSE]] }
--[[VERBOSE]] local luatype = type
--[[VERBOSE]] function verbose.custom:marshal(codec, type, value)
--[[VERBOSE]] 	if CODEC and self.flags.hexastream then
--[[VERBOSE]] 		self.custom.hexastream(self, CODEC, CURSOR)
--[[VERBOSE]] 		CURSOR, CODEC = {}, nil
--[[VERBOSE]] 	end
--[[VERBOSE]] 	local viewer = self.viewer
--[[VERBOSE]] 	local output = viewer.output
--[[VERBOSE]] 	local op = self.codecop[oo.getclass(codec)]
--[[VERBOSE]] 	if op then
--[[VERBOSE]] 		type = numtype[type] or type
--[[VERBOSE]] 		output:write(op," of ",type._type)
--[[VERBOSE]] 		type = type.name or type.repID
--[[VERBOSE]] 		if type then
--[[VERBOSE]] 			output:write(" ",type)
--[[VERBOSE]] 		end
--[[VERBOSE]] 		if value ~= nil then
--[[VERBOSE]] 			if luatype(value) == "string" then
--[[VERBOSE]] 				value = value:gsub("[^%w%p%s]", "?")
--[[VERBOSE]] 			end
--[[VERBOSE]] 			output:write(" (got ")
--[[VERBOSE]] 			viewer:write(value)
--[[VERBOSE]] 			output:write(")")
--[[VERBOSE]] 		end
--[[VERBOSE]] 	else
--[[VERBOSE]] 		return true -- cancel custom message
--[[VERBOSE]] 	end
--[[VERBOSE]] end
--[[VERBOSE]] verbose.custom.unmarshal = verbose.custom.marshal
--[[VERBOSE]] 
--[[VERBOSE]] function verbose_marshal(...)
--[[VERBOSE]] 	if CODEC and verbose.flags.hexastream then
--[[VERBOSE]] 		verbose:hexastream(CODEC, CURSOR)
--[[VERBOSE]] 		CURSOR, CODEC = {}, nil
--[[VERBOSE]] 	end
--[[VERBOSE]] 	verbose:marshal(...)
--[[VERBOSE]] end
--[[VERBOSE]] function verbose_unmarshal(...)
--[[VERBOSE]] 	if CODEC and verbose.flags.hexastream then
--[[VERBOSE]] 		verbose:hexastream(CODEC, CURSOR)
--[[VERBOSE]] 		CURSOR, CODEC = {}, nil
--[[VERBOSE]] 	end
--[[VERBOSE]] 	verbose:unmarshal(...)
--[[VERBOSE]] end
