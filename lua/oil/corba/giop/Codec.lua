-- Project: OiL - ORB in Lua
-- Release: 0.5
-- Title  : Mapping of Lua values into Common Data Representation (CDR)
-- Authors: Renato Maia <maia@inf.puc-rio.br>

local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"; local CURSOR, CODEC, PREFIXSHIFT, SIZEINDEXPOS = {}, nil, 0
local getmetatable = _G.getmetatable
local ipairs = _G.ipairs
local pairs = _G.pairs
local pcall = _G.pcall
local rawget = _G.rawget
local setmetatable = _G.setmetatable
local tonumber = _G.tonumber
local type = _G.type

local math = require "math"
local huge = math.huge

local table = require "table"
local concat = table.concat
local unpack = table.unpack or _G.unpack

local struct = require "struct"
local binpack = struct.pack
local binunpack = struct.unpack

local oo = require "oil.oo"
local class = oo.class

local assertions = require "oil.assert"
local checktype = assertions.type
local illegal = assertions.illegal
local assert = assertions.results

local idl = require "oil.corba.idl"
local istype = idl.istype
local OctetSeq = idl.OctetSeq
local ValueBase = idl.ValueBase
local abstract = idl.ValueKind.abstract
local truncatable = idl.ValueKind.truncatable

local giop = require "oil.corba.giop"
local IOR = giop.IOR

module("oil.corba.giop.Codec", class)

local IndirectionTag = 0xffffffff

--------------------------------------------------------------------------------
-- TypeCode information --------------------------------------------------------
--
-- Description of type code categories, which is defined by field type
--	empty  : no further parameters are necessary to specify the type.
--	simple : parameters that specify the associated type have fixed size.
--	complex: parameters that specify the associated type have variable size and
--           are defined as a structure in idl that is stored in a encapsulated
--           octet sequence (i.e. which endianess may differ).

local UnionLabelInfo = {
	name = "label",
	type = idl.void, -- this field is changed at run-time
}
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
					UnionLabelInfo, -- this value depends on field 'switch'.
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
		parameters = idl.struct{
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
			{name = "repID"        , type = idl.string  },
			{name = "name"         , type = idl.string  },
			{name = "original_type", type = idl.TypeCode},
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
	
	[27] = {name = "wstring", type = "simple", unhandled = true,
		parameters = idl.struct{
			{name = "maxlength", type = idl.ulong},
		},
	},
	[28] = {name = "fixed", type = "simple", unhandled = true,
		parameters = idl.struct{
			{name = "digits", type = idl.ushort},
			{name = "scale" , type = idl.short },
		},
	},
	
	[29] = {name = "valuetype", type = "complex",
		parameters = idl.struct{
			{name = "repID"     , type = idl.string  },
			{name = "name"      , type = idl.string  },
			{name = "kind"      , type = idl.short   },
			{name = "base_value", type = idl.TypeCode},
			{name = "members"   , type = idl.sequence{
				idl.struct{
					{name = "name"  , type = idl.string  },
					{name = "type"  , type = idl.TypeCode},
					{name = "access", type = idl.short   },
				},
			}},
		},
	},
	[30] = {name = "valuebox", type = "complex",
		parameters = idl.struct{
			{name = "repID"        , type = idl.string  },
			{name = "name"         , type = idl.string  },
			{name = "original_type", type = idl.TypeCode},
		},
	},
	[31] = {name = "native", type = "complex", unhandled = true,
		parameters = idl.struct{
			{name = "repID", type = idl.string  },
			{name = "name" , type = idl.string  },
		},
	},
	[32] = {name = "abstract_interface", type = "complex",
		parameters = idl.struct{
			{name = "repID", type = idl.string  },
			{name = "name" , type = idl.string  },
		},
	},
	[33] = {name = "local_interface", type = "complex",
		parameters = idl.struct{
			{name = "repID", type = idl.string  },
			{name = "name" , type = idl.string  },
		},
	},
	
	[IndirectionTag] = {name = "indirection marker", type = "fake"},
}

PrimitiveSizes = {
	boolean    =  1,
	char       =  1,
	octet      =  1,
	short      =  2,
	long       =  4,
	longlong   =  8,
	ushort     =  2,
	ulong      =  4,
	ulonglong  =  8,
	float      =  4,
	double     =  8,
	longdouble = 16,
	enum       =  4,
}

--------------------------------------------------------------------------------
-- Local module functions ------------------------------------------------------

local function alignment(self, size)
	local extra = (self.cursor-1)%size
	if extra > 0 then return size-extra end
	return 0
end

local NativeEndianess = (binunpack("B", binpack("I2", 1)) == 1)

--------------------------------------------------------------------------------
--   ##   ##   #####   ######    ######  ##   ##   #####   ##       ##        --
--   ### ###  ##   ##  ##   ##  ##       ##   ##  ##   ##  ##       ##        --
--   #######  #######  ######    #####   #######  #######  ##       ##        --
--   ## # ##  ##   ##  ##   ##       ##  ##   ##  ##   ##  ##       ##        --
--   ##   ##  ##   ##  ##   ##  ######   ##   ##  ##   ##  #######  #######   --
--------------------------------------------------------------------------------

local History = class()
function History:__index(field)
	local value = {}
	self[field] = value
	return value
end

--------------------------------------------------------------------------------
-- Unmarshalling buffer class --------------------------------------------------

Encoder = class {
	previousend = 0,
	index = 1,
	cursor = 1,
	emptychar = '\255', -- character used in buffer alignment
	pack = binpack,    -- use current platform native endianess
}

function Encoder:__init()
	if self.history == nil then self.history = History() end
	if self.format == nil then self.format = {} end
end

function Encoder:shift(shift)                                                   --[[VERBOSE]] PREFIXSHIFT = shift
	self.cursor = self.cursor + shift
end

function Encoder:jump(shift)
	if shift > 0 then self:rawput('c'..shift, self.emptychar:rep(shift), shift) end
end

function Encoder:align(size)
	local shift = alignment(self, size)
	if shift > 0 then self:jump(shift) end
end

function Encoder:rawput(format, data, size)                                     --[[VERBOSE]] verbose:SET_VERB_VARS(self, self.cursor, true)
	local index = self.index
	self.format[index] = format
	self[index] = data
	self.index = index+1
	self.cursor = self.cursor + size
end

function Encoder:put(value, idltype)
	local marshal = self[idltype._type]
	if not marshal then
		illegal(idltype._type, "supported type")
	end
	return marshal(self, value, idltype)
end

function Encoder:indirection(marshal, value, ...)
	local history = self.history
	local previous = history[marshal][value]
	if previous then
		self:ulong(IndirectionTag)
		self:long(previous - (self.previousend+self.cursor))                        --[[VERBOSE]] verbose:marshal("indirection to "..((self.previousend+self.cursor)-previous).." bytes away (",(self.previousend+self.cursor),"-",previous,").")
	else
		local shift = alignment(self, PrimitiveSizes.ulong)
		history[marshal][value] = (self.previousend+self.cursor+shift)              --[[VERBOSE]] verbose:marshal("registering position at ",history[marshal][value]," for future indirection")
		marshal(self, value, ...)
	end
end

function Encoder:getdata()
	return self.pack(concat(self.format), unpack(self))
end

function Encoder:getlength()
	return self.cursor - 1
end

local NilEnabledTypes = {
	any = true,
	boolean = true,
	Object = true,
	interface = true,
	valuetype = true,
}

--------------------------------------------------------------------------------
-- Marshalling functions -------------------------------------------------------

local function numbermarshaller(format, size, align)
	if align == nil then align = size end
	return function (self, value)
		checktype(value, "number", "numeric value")
		self:align(align)
		self:rawput(format, value, size)                                            --[[VERBOSE]] verbose:marshal(self, format, value)
	end
end

Encoder.null       = function() end
Encoder.void       = Encoder.null
Encoder.short      = numbermarshaller("i2", PrimitiveSizes.short     )
Encoder.long       = numbermarshaller("i4", PrimitiveSizes.long      )
Encoder.longlong   = numbermarshaller("i8", PrimitiveSizes.longlong  )
Encoder.ushort     = numbermarshaller("I2", PrimitiveSizes.ushort    )
Encoder.ulong      = numbermarshaller("I4", PrimitiveSizes.ulong     )
Encoder.ulonglong  = numbermarshaller("I8", PrimitiveSizes.ulonglong )
Encoder.float      = numbermarshaller("f" , PrimitiveSizes.float     )
Encoder.double     = numbermarshaller("d" , PrimitiveSizes.double    )
Encoder.longdouble = numbermarshaller("D" , PrimitiveSizes.longdouble, 8)
	
function Encoder:boolean(value)                                                 --[[VERBOSE]] verbose:marshal(true, self, idl.boolean)
	if value
		then self:octet(1)
		else self:octet(0)
	end                                                                           --[[VERBOSE]] verbose:marshal(false)
end

function Encoder:char(value)
	checktype(value, "string", "character")
	if #value ~= 1 then
		illegal(value, "character")
	end
	self:rawput('c', value, 1)                                                    --[[VERBOSE]] verbose:marshal(self, idl.char, value)
end

function Encoder:octet(value)
	checktype(value, "number", "octet value")
	self:rawput("B", value, 1)                                                    --[[VERBOSE]] verbose:marshal(self, idl.octet, value)
end

local DefaultMapping = {
	number  = idl.double,
	string  = idl.string,
	boolean = idl.boolean,
	["nil"] = idl.null,
}
function Encoder:any(value)                                                     --[[VERBOSE]] verbose:marshal(true, self, idl.any)
	local luatype = type(value)
	local idltype = DefaultMapping[luatype]
	if not idltype then
		local metatable = getmetatable(value)
		if metatable then
			if istype(metatable) then
				idltype = metatable
			elseif istype(metatable.__type) then
				idltype = metatable.__type
			end
		end
		if luatype == "table" then
			if not idltype then
				idltype = value._anytype
				if not istype(idltype) then
					idltype = nil
				end
			end
			if idltype then
				if (value._anyval ~= nil or NilEnabledTypes[idltype._type]) then
					value = value._anyval
				end
			end
		end
	end
	if not idltype then
		checktype(value, "any, unable to map to an idl type")
	end                                                                           --[[VERBOSE]] verbose:marshal "[type of any]"
	self:TypeCode(idltype)                                                        --[[VERBOSE]] verbose:marshal "[value of any]"
	self:put(value, idltype)                                                      --[[VERBOSE]] verbose:marshal(false)
end

local NullReference = { type_id = "", profiles = { n=0 } }
function Encoder:Object(value, idltype)                                         --[[VERBOSE]] verbose:marshal(true, self, idltype, value)
	local reference
	if value == nil then
		reference = NullReference
	else
		local metatable = getmetatable(value)
		if metatable == IOR
		or metatable and metatable.__type == IOR
		then                                                                        --[[VERBOSE]] verbose:marshal("using IOR provided by the application")
			reference = value
		else
			reference = (type(value)=="table") and value.__reference or nil
			if not reference then
				local servants = self.context.servants
				if servants then                                                        --[[VERBOSE]] verbose:marshal(true, "implicit servant creation")
					value = assert(servants:register{__servant=value,__type=idltype})     --[[VERBOSE]] verbose:marshal(false)
					if not value.__type:is_a(idltype.repID) then
						illegal(value, idltype.repID..", got a "..objtype.repID,"BAD_PARAM")
					end
					reference = value.__reference
				else
					illegal(value, "Object, unable to create from value", "MARHSAL")
				end                                                                     --[[VERBOSE]] else verbose:marshal("using proxy or servant object")
			end
		end
	end
	self:struct(reference, IOR)                                                   --[[VERBOSE]] verbose:marshal(false)
end

function Encoder:struct(value, idltype)                                         --[[VERBOSE]] verbose:marshal(true, self, idltype)
	for _, field in ipairs(idltype.fields) do
		local val = value[field.name]                                               --[[VERBOSE]] verbose:marshal("[field ",field.name,"]")
		if val == nil and not NilEnabledTypes[field.type._type] then
			illegal(value, "struct value (no value for field "..field.name..")")
		end
		self:put(val, field.type)
	end                                                                           --[[VERBOSE]] verbose:marshal(false)
end

function Encoder:union(value, idltype)                                          --[[VERBOSE]] verbose:marshal(true, self, idltype)
	checktype(value, "table", "union value")
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
					illegal(value, "union value (no discriminator)")
				end
			end
		end
	end                                                                           --[[VERBOSE]] verbose:marshal "[union switch]"
	self:put(switch, idltype.switch)
	
	local selection = idltype.selection[switch]
	if selection then
		-- Marshal union value
		local unionvalue = value._value
		if unionvalue == nil then
			unionvalue = value[selection.name]
			if unionvalue == nil then
				illegal(value, "union value (none contents)")
			end
		end                                                                         --[[VERBOSE]] verbose:marshal("[field ",selection.name,"]")
		self:put(unionvalue, selection.type)
	end                                                                           --[[VERBOSE]] verbose:marshal(false)
end

function Encoder:enum(value, idltype)                                           --[[VERBOSE]] verbose:marshal(true, self, idltype, value)
	value = idltype.labelvalue[value] or tonumber(value)
	if not value then illegal(value, "enum value") end
	self:ulong(value)                                                             --[[VERBOSE]] verbose:marshal(false)
end

function Encoder:string(value)                                                  --[[VERBOSE]] verbose:marshal(true, self, idl.string, value)
	checktype(value, "string", "string value")
	local length = #value
	self:ulong(length + 1)
	self:rawput('s', value, length+1)                                             --[[VERBOSE]] verbose:marshal(false)
end

function Encoder:sequence(value, idltype)                                       --[[VERBOSE]] verbose:marshal(true, self, idltype, value)
	local elementtype = idltype.elementtype
	if type(value) == "string" then
		local length = #value
		self:ulong(length)
		while elementtype._type == "typedef" do
			elementtype = elementtype.original_type
		end
		if elementtype == idl.octet or elementtype == idl.char then
			self:rawput('c'..length, value, length)
		else
			illegal(value, "sequence value (table expected, got string)")
		end
	else
		checktype(value, "table", "sequence value")
		local length = value.n or #value
		self:ulong(length)
		for i = 1, length do                                                        --[[VERBOSE]] verbose:marshal("[element ",i,"]")
			self:put(value[i], elementtype) 
		end
	end                                                                           --[[VERBOSE]] verbose:marshal(false)
end

function Encoder:array(value, idltype)                                          --[[VERBOSE]] verbose:marshal(true, self, idltype, value)
	local elementtype = idltype.elementtype
	if type(value) == "string" then
		while elementtype._type == "typedef" do
			elementtype = elementtype.original_type
		end
		if elementtype == idl.octet or elementtype == idl.char then
			local length = #value
			if length ~= idltype.length then
				illegal(value, "array value (wrong length)")
			end
			self:rawput('c'..length, value, length)
		else
			illegal(value, "array value (table expected, got string)")
		end
	else
		checktype(value, "table", "array value")
		for i = 1, idltype.length do                                                --[[VERBOSE]] verbose:marshal("[element ",i,"]")
			self:put(value[i], elementtype)
		end
	end                                                                           --[[VERBOSE]] verbose:marshal(false)
end

function Encoder:typedef(value, idltype)                                        --[[VERBOSE]] verbose:marshal(true, self, idltype, value)
	self:put(value, idltype.original_type)                                        --[[VERBOSE]] verbose:marshal(false)
end

function Encoder:except(value, idltype)                                         --[[VERBOSE]] verbose:marshal(true, self, idltype, value)
	checktype(value, "table", "except value")
	for _, member in ipairs(idltype.members) do                                   --[[VERBOSE]] verbose:marshal("[member ", member.name, "]")
		local val = value[member.name]
		if val == nil and not NilEnabledTypes[member.type._type] then
			illegal(value, "except value (no value for member "..member.name..")")
		end
		self:put(val, member.type)
	end                                                                           --[[VERBOSE]] verbose:marshal(false)
end

Encoder.interface = Encoder.Object

-- Abstract Interfaces ---------------------------------------------------------

local function index(indexable, field)
	return indexable[field]
end
local function pindex(indexable, field)
	local ok, value = pcall(index, indexable, field)
	if ok then return value end
end

function Encoder:abstract_interface(value, idltype)                             --[[VERBOSE]] verbose:marshal(true, self, idltype, value)
	local isvalue = true
	if value ~= nil then
		-- get type of the value
		local actualtype = getmetatable(value)
		if not istype(actualtype) then
			actualtype = pindex(actualtype, "__type")
			          or pindex(value, "__type")
			if not istype(actualtype) then
				illegal(value, "abstract interface, unable to figure out actual type",
				               "BAD_PARAM")
			end
		end
		isvalue = (actualtype._type == "valuetype")
	end
	self:boolean(not isvalue)
	if isvalue then                                                               --[[VERBOSE]] verbose:marshal("value encoded as copied value")
		self:valuetype(value, ValueBase)
	else                                                                          --[[VERBOSE]] verbose:marshal("value encoded as object reference")
		self:interface(value, idltype)
	end                                                                           --[[VERBOSE]] verbose:marshal(false)
end

-- ValueTypes ------------------------------------------------------------------

local MinValueTag = 0x7fffff00
local MaxValueTag = 0x7fffffff
local HasCodeBase = 0x00000001
local SingleRepID = 0x00000002
local ListOfRepID = 0x00000006
local ChunkedFlag = 0x00000008

local function reserve(self, size, noupdate)
	local sizeindex = self.ChunkSizeIndex
	if sizeindex then
		local newsize = size + (self[sizeindex] or MinValueTag)
		if newsize >= MinValueTag then -- update current chunk size
			if size >= MinValueTag then
				illegal(data, "value too large")
			end                                                                       --[[VERBOSE]] verbose:marshal("[new encoding chunk]")
			self.ChunkSizeIndex = nil -- disable chunk encoding
			self:long(0) --[[start a new chunk (size is initially 0)]]
			sizeindex = self.index-1
			newsize = size
			self.ChunkSizeIndex = sizeindex                                           --[[VERBOSE]] SIZEINDEXPOS = self.cursor-PrimitiveSizes.long
		end
		if not noupdate then
			self[sizeindex] = newsize                                                 --[[VERBOSE]] verbose:SET_VERB_VARS(self, SIZEINDEXPOS, true)
		end
	end
end

local function reservedalign(self, size)
	reserve(self, 0)
	return Encoder.align(self, size)
end

local function reservedrawput(self, format, data, size)
	reserve(self, size)
	return Encoder.rawput(self, format, data, size)
end

local ulongsize = PrimitiveSizes.ulong
local function reservedstring(self, value)
	reserve(self, alignment(self, ulongsize) -- alignment for the stating ulong
	            + ulongsize                  -- size of ulong with the string size
	            + #value                     -- number of bytes in the string
	            + 1,                         -- terminating '\0' of the string
	        "no update")
	return Encoder.string(self, value)
end

local function reservedsequence(self, value, idltype)
	local itemsize = PrimitiveSizes[idltype.elementtype._type]
	if itemsize then
		local count = (type(value) == "string") and #value or (value.n or #value)
		reserve(self, alignment(self, ulongsize) -- alignment for the ulong
		            + ulongsize                  -- size of ulong with item count
		            + count * itemsize,          -- size of the contents
		       "no update")
	end
	return Encoder.sequence(self, value, idltype)
end

local function reservedarray(self, value, idltype)
	local itemsize = PrimitiveSizes[idltype.elementtype._type]
	if itemsize then
		local count = (type(value) == "string") and #value or (value.n or #value)
		reserve(self, count * itemsize, "no update") -- size of the contents
	end
	return Encoder.array(self, value, idltype)
end

Encoder.ValueTypeNesting = 0

local function encodevaluetype(self, value, idltype)
	-- get type of the value
	local actualtype = getmetatable(value)
	if not istype(actualtype) then
		actualtype = pindex(actualtype, "__type")
		          or pindex(value, "__type")
		          or (idltype.kind ~= abstract and idltype or nil)
	end
	checktype(actualtype, "idl valuetype", "value type")
	-- collect typing information and check the type of the value
	local types = {}
	local type = actualtype
	local argidx -- index of the formal pararameter type
	local lstidx -- index of the last truncatable type
	for i = 1, huge do
		types[i] = type
		if type == idltype then argidx = i end
		if type.kind ~= truncatable then lstidx = i end
		type = type.inherited
		if type == nil then break end
	end
	local truncatable = (lstidx > 1)
	if argidx == nil then
		if idltype ~= ValueBase then
			local found
			-- check whether it inherits from an abstract value
			if idltype.is_abstract then
				for _, type in ipairs(types) do
					if type:is_a(idltype.repID) then
						found = true
						break
					end
				end
			end
			if not found then
				illegal(value, "value of type "..idltype.repID)
			end
		end
	elseif argidx < lstidx then
		lstidx = argidx -- can terminate the repID list at a well known type (param)
	end
	-- encode tag and typing information
	local nesting = self.ValueTypeNesting
	self.ChunkSizeIndex = nil -- end current chunk, if any
	local chunked = nesting > 0 or truncatable
	local tag = MinValueTag + (chunked and ChunkedFlag or 0)
	if actualtype == idltype and nesting == 0 then                                --[[VERBOSE]] verbose:marshal("[value tag: no truncatable bases]")
		self:ulong(tag)
	elseif chunked then --[[nesting > 0 or truncatable]]                          --[[VERBOSE]] verbose:marshal("[value tag: lists of ",lstidx," truncatable bases]")
		self:ulong(tag+ListOfRepID)
		self:long(lstidx)
		for i = 1, lstidx do                                                        --[[VERBOSE]] verbose:marshal("[repID of truncatable base ",i,"]")
			self:indirection(self.string, types[i].repID)
		end
	else -- non-truncatable
		self:ulong(tag+SingleRepID)                                                 --[[VERBOSE]] verbose:marshal("[value tag: single truncatable base]")
		self:indirection(self.string, types[1].repID)
	end
	-- check if chunked encoding is necessary
	if chunked then
		self.ValueTypeNesting = nesting+1  -- increase value nesting level
		if nesting == 0 then               -- enable chunked encoding if not nested
			self.history[reservedstring] = self.history[self.string]
			self.align = reservedalign
			self.rawput = reservedrawput
			self.string = reservedstring
			self.sequence = reservedsequence
			self.array = reservedarray
		end
		self.ChunkSizeIndex = "fake"       -- get prepared to start a new chunk
	end
	-- encode value state
	local membertype, membervalue
	for i = #types, 1, -1 do                                                      --[[VERBOSE]] verbose:marshal("[base value ",types[i].name,"]")
		local members = types[i].members
		local count = #members
		for j = 1, count do
			local member = members[j]                                                 --[[VERBOSE]] verbose:marshal("[field ",member.name,"]")
			membertype = member.type         -- used in optimization below
			membervalue = value[member.name]
			self:put(membervalue, membertype)
		end
	end
	-- finalize encoding of value
	if chunked then
		-- encode chunk end tag
		local endtag = -(nesting+1)
		if membertype
		and membertype._type == "valuetype"
		and membervalue ~= nil
		and self.ChunkSizeIndex == nil then
			self[self.index-1] = endtag      --[[last member was a ValueType]]        --[[VERBOSE]] verbose:marshal("[end tag of nested value updated to ",endtag,"] (optimized encoding)")
		else                                                                        --[[VERBOSE]] verbose:marshal("[end tag of encoded value]")
			self.ChunkSizeIndex = nil        -- terminate current chunk
			self:long(endtag)
		end
		self.ValueTypeNesting = nesting    -- restore value nesting level
		if nesting == 0 then               -- disable chunked encoding if not nested
			self.align = nil
			self.rawput = nil
			self.string = nil
			self.sequence = nil
			self.array = nil
			self.ChunkSizeIndex = nil
		else
			self.ChunkSizeIndex = "fake"     -- get prepared to start a new chunk
		end
	end
end

function Encoder:valuetype(value, idltype)                                      --[[VERBOSE]] verbose:marshal(true, self, idltype, value)
	if value == nil then
		self:ulong(0) -- null tag
	else
		checktype(value, "table", "value")
		self:indirection(encodevaluetype, value, idltype)
	end                                                                           --[[VERBOSE]] verbose:marshal(false)
end

-- ValueBox --------------------------------------------------------------------

local function encodevaluebox(self, value, idltype)                             --[[VERBOSE]] verbose:marshal("[value tag: boxed]")
	local nesting = self.ValueTypeNesting
	-- encode tag
	self.ChunkSizeIndex = nil -- end current chunk, if any
	self:ulong(MinValueTag + (nesting==0 and 0 or ChunkedFlag))
	-- check if chunked encoding is necessary
	if nesting > 0 then
		self.ValueTypeNesting = nesting+1 -- increase value nesting level
		self.ChunkSizeIndex = "fake"      -- get prepared to start a new chunk
	end
	-- encode value
	self:put(value, idltype.original_type)
	-- finalize encoding of value
	if nesting > 0 then                                                           --[[VERBOSE]] verbose:marshal("[end tag of encoded value]")
		self.ChunkSizeIndex = nil         -- terminate current chunk
		self:long(-(nesting+1))           -- encode chunk end tag
		self.ValueTypeNesting = nesting-1 -- decrease value nesting level
		self.ChunkSizeIndex = "fake"      -- get prepared to start a new chunk
	end
end

function Encoder:valuebox(value, idltype)                                       --[[VERBOSE]] verbose:marshal(true, self, idltype, value)
	if value == nil then
		self:ulong(0) -- null tag
	else
		self:indirection(encodevaluebox, value, idltype)
	end                                                                           --[[VERBOSE]] verbose:marshal(false)
end

-- TypeCodes -------------------------------------------------------------------

local function encodetypeinfo(self, value, kind, tcinfo)
	self:ulong(kind)
	local tcparams = value.tcparams
	if tcparams == nil then                                                       --[[VERBOSE]] verbose:marshal "[parameters values]"
		-- create encoder for encapsulated stream
		local cursor = self.previousend+self.cursor
		local history
		if self.encodingTypeCode then
			history = self.history
		else
			history = History()
			history[encodetypeinfo][value] = self.history[encodetypeinfo][value]
		end
		local encoder = Encoder{
			context = self,
			history = history,
			previousend = cursor-1 + 4, -- adds the size of the OctetSeq count
			encodingTypeCode = true,
		}
		encoder:boolean(NativeEndianess) -- encapsulated stream includes endianess
		-- encode parameters using the encapsulated encoder
		encoder:struct(value, tcinfo.parameters)
		if tcinfo.mutable then                                                      --[[VERBOSE]] verbose:marshal "[mutable parameters values]"
			for _, param in ipairs(tcinfo.mutable:setup(value)) do
				encoder:put(value[param.name], param.type)
			end
		end                                                                         --[[VERBOSE]] verbose:marshal(true, "[parameters encapsulation]")
		-- get encapsulated stream and save for future reuse
		tcparams = encoder:getdata()
		if not self.encodingTypeCode then
			value.tcparams = tcparams
		end                                                                         --[[VERBOSE]] verbose:marshal(false)
	end
	self:sequence(tcparams, OctetSeq)
end

local TypeCodes = { interface = 14 }
for tcode, info in pairs(TypeCodeInfo) do TypeCodes[info.name] = tcode end

function Encoder:TypeCode(value)                                                --[[VERBOSE]] verbose:marshal(true, self, idl.TypeCode, value)
	checktype(value, "idl type", "TypeCode value")
	local kind   = TypeCodes[value._type]
	local tcinfo = TypeCodeInfo[kind]

	if not kind then illegal(value, "idl type") end
	
	if tcinfo.type == "empty" then
		self:ulong(kind)
	elseif tcinfo.type == "simple" then
		self:ulong(kind)
		for _, param in ipairs(tcinfo.parameters) do                                --[[VERBOSE]] verbose:marshal("[parameter ",param.name,"]")
			self:put(value[param.name], param.type)
		end
	else
		self:indirection(encodetypeinfo, value, kind, tcinfo)
	end                                                                           --[[VERBOSE]] verbose:marshal(false)
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

Decoder = class{
	localrefs = "implementation",
	previousend = 0,
	cursor = 1,
	align = Encoder.align,
	unpack = binunpack, -- use current platform native endianess
}

function Decoder:__init()
	if self.history == nil then self.history = {} end
end

local prefix = NativeEndianess and ">" or "<"
local function invunpack(format, ...)
	return binunpack(prefix..format, ...)
end
function Decoder:order(value)
	if value ~= NativeEndianess then
		self.unpack = invunpack
	end
end

function Decoder:jump(shift)
	local cursor = self.cursor
	if shift > 0 then                                                             --[[VERBOSE]] verbose:SET_VERB_VARS(self, self.cursor, true)
		self.cursor = cursor + shift                                                --[[VERBOSE]] verbose:SET_VERB_VARS(self, self.cursor, false)
		if self.cursor - 1 > #self.data then
			illegal(self.data, "data stream, insufficient data", "badstream")
		end
	end
	return cursor
end

function Decoder:indirection(unmarshal, ...)
	local value
	local tag = self:ulong()
	if tag == IndirectionTag then                                                 --[[VERBOSE]] verbose:unmarshal("indirection tag found")
		local pos = self.previousend+self.cursor
		local offset = self:long()
		value = self.history[pos+offset]                                            --[[VERBOSE]] verbose:unmarshal(value == nil and "no " or "","previous value found at position ",pos+offset," (current: ",pos,")")
		if value == nil then
			illegal(offset, "indirection offset", "badstream")
		end
	else
		local pos = self.previousend+self.cursor - PrimitiveSizes.ulong             --[[VERBOSE]] verbose:unmarshal("calculating position of value for indirections, got ",pos)
		value = unmarshal(self, pos, tag, ...)
	end
	return value
end

function Decoder:get(idltype)
	local unmarshal = self[idltype._type]
	if not unmarshal then
		illegal(idltype._type, "supported type", "badstream")
	end
	return unmarshal(self, idltype)
end

function Decoder:append(data)
	self.data = self.data..data
end

function Decoder:getdata()
	return self.data
end

function Decoder:remains()
	return self.data:sub(self.cursor)
end

--------------------------------------------------------------------------------
-- Unmarshalling functions -----------------------------------------------------

local function numberunmarshaller(format, size, align)
	if align == nil then align = size end
	return function(self)
		self:align(align)
		local cursor = self:jump(size)                                              --[[VERBOSE]] verbose:unmarshal(self, format, self.unpack(format, self.data, cursor))
		return self.unpack(format, self.data, cursor)
	end
end

Decoder.null       = function() end
Decoder.void       = Decoder.null
Decoder.short      = numberunmarshaller("i2", PrimitiveSizes.short     )
Decoder.long       = numberunmarshaller("i4", PrimitiveSizes.long      )
Decoder.longlong   = numberunmarshaller("i8", PrimitiveSizes.longlong  )
Decoder.ushort     = numberunmarshaller("I2", PrimitiveSizes.ushort    )
Decoder.ulong      = numberunmarshaller("I4", PrimitiveSizes.ulong     )
Decoder.ulonglong  = numberunmarshaller("I8", PrimitiveSizes.ulonglong )
Decoder.float      = numberunmarshaller("f" , PrimitiveSizes.float     )
Decoder.double     = numberunmarshaller("d" , PrimitiveSizes.double    )
Decoder.longdouble = numberunmarshaller("D" , PrimitiveSizes.longdouble, 8)

function Decoder:boolean()                                                      --[[VERBOSE]] verbose:unmarshal(true, self, idl.boolean)
	return (self:octet() ~= 0)                                                    --[[VERBOSE]],verbose:unmarshal(false)
end

function Decoder:char()
	local cursor = self:jump(1) --[[check if there is enougth bytes]]             --[[VERBOSE]] verbose:unmarshal(self, idl.char, self.data:sub(cursor, cursor))
	return self.data:sub(cursor, cursor)
end

function Decoder:octet()
	local cursor = self:jump(1) --[[check if there is enougth bytes]]             --[[VERBOSE]] verbose:unmarshal(self, idl.octet, self.unpack("B", self.data, cursor))
	return self.unpack("B", self.data, cursor)
end

function Decoder:any()                                                          --[[VERBOSE]] verbose:unmarshal(true, self, idl.any) verbose:unmarshal "[type of any]"
	local idltype = self:TypeCode()                                               --[[VERBOSE]] verbose:unmarshal "[value of any]"
	local value = self:get(idltype)
	if type(value) == "table" then
		value._anyval = value
		value._anytype = idltype
	else
		value = setmetatable({
			_anyval = value,
			_anytype = idltype,
		}, idltype)
	end                                                                           --[[VERBOSE]] verbose:unmarshal(false)
	return value
end

function Decoder:IOR()
	local ior = self:struct(IOR)
	ior.referrer = self.context.references
	return ior
end

function Decoder:Object(idltype)                                                --[[VERBOSE]] verbose:unmarshal(true, self, idltype)
	local ior = self:IOR()
	if ior.type_id == "" then                                                     --[[VERBOSE]] verbose:unmarshal "got a null reference"
		ior = nil
	else
		if self.localrefs ~= "proxy" then
			local servants = self.context.servants
			if servants ~= nil then
				local entry = servants:localref(ior)
				if entry ~= nil then                                                      --[[VERBOSE]] verbose:unmarshal("reference to local object with key '",objkey,"' resolved")
					if self.localrefs == "implementation" then
						entry = entry.__servant
					end
					return entry
				end
			end
		end
		local proxies = self.context.proxies
		if proxies ~= nil then                                                        --[[VERBOSE]] verbose:unmarshal("retrieve proxy for referenced object")
			if idltype._type == "Object" then idltype = idltype.repID end
			return assert(proxies:newproxy{ __reference=ior, __type=idltype })
		end
	end                                                                           --[[VERBOSE]] verbose:unmarshal(false)
	return ior
end

function Decoder:struct(idltype)                                                --[[VERBOSE]] verbose:unmarshal(true, self, idltype)
	local value = {}
	for _, field in ipairs(idltype.fields) do                                     --[[VERBOSE]] verbose:unmarshal("[field ",field.name,"]")
		value[field.name] = self:get(field.type)
	end                                                                           --[[VERBOSE]] verbose:unmarshal(false)
	return setmetatable(value, idltype)
end

function Decoder:union(idltype)                                                 --[[VERBOSE]] verbose:unmarshal(true, self, idltype) verbose:unmarshal "[union switch]"
	local switch = self:get(idltype.switch)
	local value = { _switch = switch }
	local option = idltype.selection[switch] or
	               idltype.options[idltype.default+1]
	if option then                                                                --[[VERBOSE]] verbose:unmarshal("[field ",option.name,"]")
		value._field = option.name
		value._value = self:get(option.type)
	end                                                                           --[[VERBOSE]] verbose:unmarshal(false)
	return setmetatable(value, idltype)
end

function Decoder:enum(idltype)                                                  --[[VERBOSE]] verbose:unmarshal(true, self, idltype)
	local value = self:ulong() + 1
	if value > #idltype.enumvalues then
		illegal(value, "enumeration value", "badstream")
	end                                                                           --[[VERBOSE]] verbose:unmarshal(false, "got ",idltype.enumvalues[value])
	return idltype.enumvalues[value]
end

function Decoder:indirectstring(pos, length)
	local cursor = self:jump(length) -- check if there is enougth bytes
	local value = self.data:sub(cursor, cursor + length - 2)
	if pos then self.history[pos] = value end                                     --[[VERBOSE]] verbose:unmarshal("got ",verbose.viewer:tostring(value))
	return value
end

function Decoder:string()                                                       --[[VERBOSE]] verbose:unmarshal(true, self, idl.string)
	return self:indirectstring(nil, self:ulong())                                 --[[VERBOSE]],verbose:unmarshal(false)
end

function Decoder:sequence(idltype)                                              --[[VERBOSE]] verbose:unmarshal(true, self, idltype)
	local length      = self:ulong()
	local elementtype = idltype.elementtype
	local value
	while elementtype._type == "typecode" do elementtype = elementtype.type end
	if elementtype == idl.octet or elementtype == idl.char then
		local cursor = self:jump(length) -- check if there is enougth bytes
		value = self.data:sub(cursor, cursor + length - 1)                          --[[VERBOSE]] verbose:unmarshal("got ", verbose.viewer:tostring(value))
	else
		value = setmetatable({ n = length }, idltype)
		for i = 1, length do                                                        --[[VERBOSE]] verbose:unmarshal("[element ",i,"]")
			value[i] = self:get(elementtype)
		end
	end                                                                           --[[VERBOSE]] verbose:unmarshal(false)
	return value
end

function Decoder:array(idltype)                                                 --[[VERBOSE]] verbose:unmarshal(true, self, idltype)
	local length      = idltype.length
	local elementtype = idltype.elementtype
	local value
	while elementtype._type == "typecode" do elementtype = elementtype.type end
	if elementtype == idl.octet or elementtype == idl.char then
		local cursor = self:jump(length) -- check if there is enougth bytes
		value = self.data:sub(cursor, cursor + length - 1)                          --[[VERBOSE]] verbose:unmarshal("got ",verbose.viewer:tostring(value))
	else
		value = setmetatable({}, idltype)
		for i = 1, length do                                                        --[[VERBOSE]] verbose:unmarshal("[element ",i,"]")
			value[i] = self:get(elementtype)
		end
	end                                                                           --[[VERBOSE]] verbose:unmarshal(false)
	return value
end

function Decoder:typedef(idltype)                                               --[[VERBOSE]] verbose:unmarshal(true, self, idltype)
	return self:get(idltype.original_type)                                        --[[VERBOSE]],verbose:unmarshal(false)
end

function Decoder:except(idltype)                                                --[[VERBOSE]] verbose:unmarshal(true, self, idltype)
	local value = {}
	for _, member in ipairs(idltype.members) do                                   --[[VERBOSE]] verbose:unmarshal("[member ",member.name,"]")
		value[member.name] = self:get(member.type)
	end                                                                           --[[VERBOSE]] verbose:unmarshal(false)
	return setmetatable(value, idltype)
end

Decoder.interface = Decoder.Object

function Decoder:abstract_interface(idltype)                                    --[[VERBOSE]] verbose:unmarshal(true, self, idltype)
	local value
	if self:boolean() then                                                        --[[VERBOSE]] verbose:unmarshal("value is a copied value")
		value = self:interface(idltype)
	else                                                                          --[[VERBOSE]] verbose:unmarshal("value is an object reference")
		value = self:valuetype(ValueBase)
	end                                                                           --[[VERBOSE]] verbose:unmarshal(false)
	return value
end

-- ValueTypes ------------------------------------------------------------------

Decoder.ValueTypeNesting = 0

local decodevaluetype

local function reservedjump(self, shift)
	self.jump = nil -- disable chunk decoding
	local chunkend = self.ChunkEnd
	if chunkend == nil then
		local cursor = self.cursor
		local value = self:long()
		if value >= MinValueTag then                                                --[[VERBOSE]] verbose:unmarshal("found nested value in chunked encoding")
			self.cursor = cursor+shift -- rollback the cursor
			return cursor -- return with chunk decoding disabled 
		elseif value > 0 then
			chunkend = self.cursor + value -- calculate new chunk end
			self.ChunkEnd = chunkend                                                  --[[VERBOSE]] verbose:unmarshal("value encoding chunk started (end at ",chunkend,")")
		else -- end tag
			illegal(self.data,
				"data stream, chunked value encoding ended prematurely", "badstream")
		end
	end
	local result = self:jump(shift)
	if self.cursor == chunkend then                                               --[[VERBOSE]] verbose:unmarshal("value encoding chunk finished")
		self.ChunkEnd = nil
	elseif chunkend and self.cursor > chunkend then
		illegal(self.data,
			"data stream, value chunk ended prematurely", "badstream")
	end
	self.jump = reservedjump -- re-enable chunk decoding
	return result
end

local function skipchunks(self, nesting)
	self.jump = nil
	local chunkend = self.ChunkEnd
	if chunkend then                                                              --[[VERBOSE]] verbose:unmarshal("skipping the remains of current chunk")
		self:jump(chunkend - self.cursor)
		self.ChunkEnd = nil
	end
	repeat
		local value = self:long()
		if value >= MinValueTag then                                                --[[VERBOSE]] verbose:unmarshal(true, "skipping nested value")
			local pos = self.previousend+self.cursor - PrimitiveSizes.ulong           --[[VERBOSE]] verbose:unmarshal("calculating position of value for indirections, got ",pos)
			value = decodevaluetype(self, pos, value)                                 --[[VERBOSE]] verbose:unmarshal(false)
			self.jump = nil
		elseif value > 0 then                                                       --[[VERBOSE]] verbose:unmarshal("skipping an entire chunk")
			self:jump(value)
		else -- end tag
			self.ValueTypeNesting = -(value+1)                                        --[[VERBOSE]] verbose:unmarshal("found the end tag of a nested value, restoring to nesting level ",self.ValueTypeNesting)
		end
	until self.ValueTypeNesting <= nesting
	if self.ValueTypeNesting > 0 then self.jump = reservedjump end
end

local function decodevaluestate(self, value, idltype, repidlist, chunked)
	-- check if chunked decoding is necessary
	local nesting
	if chunked then
		-- increase value nesting level
		nesting = self.ValueTypeNesting
		self.ValueTypeNesting = nesting+1
		-- enable chunked decoding
		self:align(PrimitiveSizes.long)
		self.jump = reservedjump
	end
	-- find value's type description
	local type
	if repidlist == 0 then
		type = idltype
	else
		local types = self.context.types
		if types then
			for i = 1, #repidlist do
				local repID = repidlist[i]
				type = types:resolve(repID)
				if type ~= nil then break end                                           --[[VERBOSE]] verbose:unmarshal("skipping unknown truncatable base ",repID)
			end
		end
		if type == nil then
			illegal(value, "value, all truncatable bases are unknown", "badstream")
		end
		checktype(type, "idl valuetype", "type of received value", "badstream")
	end                                                                           --[[VERBOSE]] verbose:unmarshal("decoding value as a ",type.name)
	setmetatable(value, type)
	-- collect all base types
	local types = {}
	for i = 1, huge do
		types[i] = type
		type = type.inherited
		if type == nil then break end
	end
	-- decode value state
	for i = #types, 1, -1 do                                                      --[[VERBOSE]] verbose:unmarshal("[base value ",types[i].name,"]")
		local members = types[i].members
		for j = 1, #members do
			local member = members[j]                                                 --[[VERBOSE]] verbose:unmarshal("[field ",member.name,"]")
			value[member.name] = self:get(member.type)
		end
	end
	-- finalize decoding of value
	if chunked then
		skipchunks(self, nesting) -- skip the remains of this value
	end
	-- construct the value using the factory
	local factory = self.context.factories
	if factory then
		factory = factory[types[1].repID]
		if factory then                                                             --[[VERBOSE]] verbose:unmarshal(true, "building value using factory of ",types[1].repID)
			factory(value)                                                            --[[VERBOSE]] verbose:unmarshal(false) else verbose:unmarshal("no factory found for ",types[1].repID)
		end
	end
end

function decodevaluetype(self, pos, tag, idltype)
	-- check for null tag
	if tag == 0 then
		return nil                                                                  --[[VERBOSE]],verbose:unmarshal("got a null")
	end
	-- check tag value
	if tag < MinValueTag or tag > MaxValueTag then
		illegal(tag, "value tag", "badstream")
	end
	-- decode flags contained in the tag
	local codebase = tag%2
	tag = tag-codebase
	local repidlist = tag%8
	tag = tag-repidlist
	local chunked = (tag%16 == ChunkedFlag)
	-- ignore CodeBaseURL string if present
	if codebase == HasCodeBase then                                               --[[VERBOSE]] verbose:unmarshal("[CodeBaseURL: ignored]")
		self:indirection(self.indirectstring)
	end
	-- decode typing information
	if repidlist == SingleRepID then                                              --[[VERBOSE]] verbose:unmarshal("[single truncatable base]")
		repidlist = { self:indirection(self.indirectstring) }
	elseif repidlist == ListOfRepID then                                          --[[VERBOSE]] verbose:unmarshal("[list of truncatable bases]")
		repidlist = {}
		for i = 1, self:long() do
			repidlist[i] = self:indirection(self.indirectstring)
		end
	elseif repidlist ~= 0 then
		illegal(repidlist,
			"type information bit pattern in value tag (only 0, "
			..SingleRepID.." and "..ListOfRepID.." are valid)", "badstream")
	end
	-- create value
	local value = {}
	self.history[pos] = value
	if idltype == nil then                                                        --[[VERBOSE]] verbose:unmarshal(true, "skipping chunks of a nested value inside a chunked value")
		-- skipping chunks of a nested value
		local cursor = self.cursor
		local nesting = self.ValueTypeNesting
		function value._complete(_, idltype)                                        --[[VERBOSE]] verbose:unmarshal(true, "resuming decoding of previously skipped nested value")
			value._complete = nil
			local cursor_back = self.cursor
			local nesting_back = self.ValueTypeNesting
			local chunkend_back = self.ChunkEnd
			local jump_back = rawget(self, "jump")
			self.cursor = cursor
			self.ValueTypeNesting = nesting
			self.ChunkEnd = nil
			self.jump = nil
			decodevaluestate(self, value, idltype, repidlist, chunked)
			self.cursor = cursor_back
			self.ValueTypeNesting = nesting_back                                      --[[VERBOSE]] verbose:unmarshal(false)
			self.ChunkEnd = chunkend_back
			self.jump = jump_back
		end
		self.ValueTypeNesting = nesting+1
		skipchunks(self, nesting)                                                   --[[VERBOSE]] verbose:unmarshal(false)
	else
		decodevaluestate(self, value, idltype, repidlist, chunked)
	end
	return value
end

function Decoder:valuetype(idltype)                                             --[[VERBOSE]] verbose:unmarshal(true, self, idltype)
	local value = self:indirection(decodevaluetype, idltype)
	if value and value._complete then value:_complete() end                       --[[VERBOSE]] verbose:unmarshal(false)
	return value
end

-- ValueBox --------------------------------------------------------------------

local function decodevaluebox(self, pos, tag, idltype)
	-- check for null tag
	if tag == 0 then
		return nil                                                                  --[[VERBOSE]],verbose:unmarshal("got a null")
	end
	-- check tag value
	local chunked = (tag == MinValueTag+ChunkedFlag)
	if not chunked and tag ~= MinValueTag then
		illegal(tag, "value box tag", "badstream")
	end
	-- check if chunked decoding is necessary
	local nesting
	if chunked then
		-- increase value nesting level
		nesting = self.ValueTypeNesting
		self.ValueTypeNesting = nesting+1
		-- enable chunked decoding
		self:align(PrimitiveSizes.long)
		self.jump = reservedjump
	end
	-- decode value state
	local value = self:get(idltype.original_type)
	self.history[pos] = value
	-- finalize decoding of value
	if chunked then
		skipchunks(self, nesting) -- skip the remains of this value
	end
	return value
end

function Decoder:valuebox(idltype)                                              --[[VERBOSE]] verbose:unmarshal(true, self, idltype)
	return self:indirection(decodevaluebox, idltype)                              --[[VERBOSE]],verbose:unmarshal(false)
end

--------------------------------------------------------------------------------

local function decodetypeinfo(self, pos, kind)
	local tcinfo = TypeCodeInfo[kind]
	if tcinfo == nil then illegal(kind, "type code", "badstream") end        --[[VERBOSE]] verbose:unmarshal("TypeCode defines a ",tcinfo.name)
	if tcinfo.unhandled then
		illegal(tcinfo.name, "supported type code", "badstream")
	end
	if tcinfo.type == "empty" then
		return tcinfo.idl
	elseif tcinfo.type == "simple" then
		-- NOTE: The string type is the only simple type being handled,
		--       therefore parameters are ignored.
		for _, param in ipairs(tcinfo.parameters) do                                --[[VERBOSE]] verbose:unmarshal("[parameter ",param.name,"]")
			self:get(param.type)
		end
		return tcinfo.idl
	elseif tcinfo.type == "complex" then                                          --[[VERBOSE]] verbose:unmarshal(true, "[parameters encapsulation]")
		local tcparams = self:sequence(OctetSeq)
		local value = { _type = tcinfo.name }
		local history = self.history
		history[pos] = value
		if not self.encodingTypeCode then
			history = { [pos] = value } -- do not inherit history, as it is standalone
			value.tcparams = tcparams
		end
		-- create decoder for encapsulated stream
		local cursor = self.previousend+self.cursor
		local decoder = Decoder{
			data = tcparams,
			context = self.context,
			history = history,
			previousend = cursor-1 - #tcparams, -- rolls back before the OctetSeq read
			encodingTypeCode = true,
		}
		decoder:order(decoder:boolean()) -- encapsulated stream includes endianess
		-- encode parameters using the encapsulated encoder
		for _, field in ipairs(tcinfo.parameters.fields) do                         --[[VERBOSE]] verbose:unmarshal("[field ",field.name,"]")
			value[field.name] = decoder:get(field.type)
		end
		if tcinfo.mutable then                                                      --[[VERBOSE]] verbose:unmarshal "[mutable parameters values]"
			for _, param in ipairs(tcinfo.mutable:setup(value)) do
				value[param.name] = decoder:get(param.type)
			end
		end                                                                         --[[VERBOSE]] verbose:unmarshal(false)
		-- build local TypeCode value
		return idl[tcinfo.name](value)
	end
end

function Decoder:TypeCode()                                                     --[[VERBOSE]] verbose:unmarshal(true, self, idl.TypeCode)
	return self:indirection(decodetypeinfo)                                       --[[VERBOSE]],verbose:unmarshal(false)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- NOTE: second parameter indicates an encasulated octet-stream, therefore
--       endianess must be read from stream.
function decoder(self, octets, getorder)
	local decoder = self.Decoder{
		data = octets,
		context = self,
	}
	if getorder then decoder:order(decoder:boolean()) end
	return decoder
end

-- NOTE: Presence of a parameter indicates an encapsulated octet-stream.
function encoder(self, putorder)
	local encoder = self.Encoder{
		context = self, 
	}
	if putorder then encoder:boolean(NativeEndianess) end
	return encoder
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--[[VERBOSE]] local getclass = oo.getclass
--[[VERBOSE]] local numtype = {
--[[VERBOSE]] 	i2 = idl.short,
--[[VERBOSE]] 	i4 = idl.long,
--[[VERBOSE]] 	i8 = idl.longlong,
--[[VERBOSE]] 	I2 = idl.ushort,
--[[VERBOSE]] 	I4 = idl.ulong,
--[[VERBOSE]] 	I8 = idl.ulonglong,
--[[VERBOSE]] 	f  = idl.float,
--[[VERBOSE]] 	d  = idl.double,
--[[VERBOSE]] 	D  = idl.longdouble,
--[[VERBOSE]] }
--[[VERBOSE]] verbose.codecop = {
--[[VERBOSE]] 	[Encoder] = "marshal",
--[[VERBOSE]] 	[Decoder] = "unmarshal",
--[[VERBOSE]] }
--[[VERBOSE]] local luatype = type
--[[VERBOSE]] function verbose.custom:marshal(codec, type, value)
--[[VERBOSE]] 	local viewer = self.viewer
--[[VERBOSE]] 	local output = viewer.output
--[[VERBOSE]] 	local op = self.codecop[getclass(codec)]
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
--[[VERBOSE]] 	if CODEC and self.flags.hexastream then
--[[VERBOSE]] 		if CURSOR[SIZEINDEXPOS] and CODEC.ChunkSizeIndex then
--[[VERBOSE]] 			self:marshal("[chunk size updated to ",CODEC[CODEC.ChunkSizeIndex],"]")
--[[VERBOSE]] 		end
--[[VERBOSE]] 		self:hexastream(CODEC, CURSOR, PREFIXSHIFT)
--[[VERBOSE]] 		CURSOR, CODEC = {}, nil
--[[VERBOSE]] 	end
--[[VERBOSE]] end
--[[VERBOSE]] verbose.custom.unmarshal = verbose.custom.marshal
--[[VERBOSE]] function verbose:SET_VERB_VARS(codec, cursor, value)
--[[VERBOSE]] 	if self.flags.hexastream then
--[[VERBOSE]] 		if value == nil then value = true end
--[[VERBOSE]] 		if CODEC == nil then CODEC = codec end
--[[VERBOSE]] 		if CURSOR == nil then CURSOR = {} end
--[[VERBOSE]] 		CURSOR[cursor] = value
--[[VERBOSE]] 	end
--[[VERBOSE]] end
