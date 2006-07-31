-- $Id$
--******************************************************************************
-- Copyright 2002 Noemi Rodriquez & Roberto Ierusalimschy. All rights reserved. 
--******************************************************************************

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
-- Release: 0.3 alpha                                                         --
-- Title  : Mapping of Lua values into Common Data Representation (CDR)       --
-- Authors: Noemi Rodriquez       <noemi@inf.puc-rio.br>                      --
--          Roberto Ierusalimschy <roberto@inf.puc-rio.br>                    --
--          Renato Cerqueira      <rcerq@inf.puc-rio.br>                      --
--          Pedro Miller          <miller@inf.puc-rio.br>                     --
--          Reinaldo Mello        <rmello@inf.puc-rio.br>                     --
--          Luiz Nogara           <nogara@inf.puc-rio.br>                     --
--          Renato Maia           <maia@inf.puc-rio.br>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   ReadBuffer      Buffer class for unmarshalling of CDR data from string   --
--   WriteBuffer     Buffer class for marshalling data into string in CDR     --
--                                                                            --
-- ReadBuffer interface:                                                      --
--   order(value)    Change or return the endianess of the buffer             --
--   jump(shift)     Places an empty space in the data of the buffer          --
--   getdata()       Returns the raw data stream of marshalled data           --
--   get(type)       Unmarhsall a value of the given type                     --
--                                                                            --
--   void()          Unmarshall a void type value                             --
--   short()         Unmarshall an integer type short value                   --
--   long()          Unmarshall an integer type long value                    --
--   ushort()        Unmarshall an integer type unsigned short value          --
--   ulong()         Unmarshall an integer type unsigned long value           --
--   float()         Unmarshall a floating-point numeric type value           --
--   double()        Unmarshall a double-precision floating-point num. value  --
--   boolean()       Unmarshall a boolean type value                          --
--   char()          Unmarshall a character type value                        --
--   octet()         Unmarshall a raw byte type value                         --
--   any()           Unmarshall a generic type value                          --
--   TypeCode()      Unmarshall a meta-type value                             --
--   string()        Unmarshall a string type value                           --
--                                                                            --
--   Object(type)    Unmarhsall an Object type value, given its type          --
--   struct(type)    Unmarhsall a struct type value, given its type           --
--   union(type)     Unmarhsall a union type value, given its type            --
--   enum(type)      Unmarhsall an enumeration type value, given its type     --
--   sequence(type)  Unmarhsall a sequence type value, given its type         --
--   array(type)     Unmarhsall an array type value, given its type           --
--   typedef(type)   Unmarhsall a type definition value, given its type       --
--   except(type)    Unmarhsall an expection value, given its type            --
--                                                                            --
--   interface(type) Unmarshall an object reference of a given interface      --
--   IOR()           Unmarhsall an interoperable object reference             --
--                                                                            --
-- WriteBuffer interface:                                                     --
--   order(value)         Change or return the endianess of the buffer        --
--   jump(shift)          Jump an empty space in the data of the buffer       --
--   getdata()            Returns the raw data stream of marshalled data      --
--   put(type)            Marhsall a value of the given type                  --
--                                                                            --
--   void(value)          Marshall a void type value                          --
--   short(value)         Marshall an integer type short value                --
--   long(value)          Marshall an integer type long value                 --
--   ushort(value)        Marshall an integer type unsigned short value       --
--   ulong(value)         Marshall an integer type unsigned long value        --
--   float(value)         Marshall a floating-point numeric type value        --
--   double(value)        Marshall a double-prec. floating-point num. value   --
--   boolean(value)       Marshall a boolean type value                       --
--   char(value)          Marshall a character type value                     --
--   octet(value)         Marshall a raw byte type value                      --
--   any(value)           Marshall a generic type value                       --
--   TypeCode(value)      Marshall a meta-type value                          --
--   string(value)        Marshall a string type value                        --
--                                                                            --
--   Object(value, type)  Marhsall an Object type value, given its type       --
--   struct(value, type)  Marhsall a struct type value, given its type        --
--   union(value, type)   Marhsall an union type value, given its type        --
--   enum(value, type)    Marhsall an enumeration type value, given its type  --
--   sequence(value, type)Marhsall a sequence type value, given its type      --
--   array(value, type)   Marhsall an array type value, given its type        --
--   typedef(value, type) Marhsall a type definition value, given its type    --
--   except(value, type)  Marhsall an expection value, given its type         --
--                                                                            --
--   interface(value,type)Marshall an object reference of a given interface   --
--   IOR(value)           Marhsall an interoperable object reference          --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--   See section 15.3 of CORBA 3.0 specification.                             --
--------------------------------------------------------------------------------

local type         = type
local pairs        = pairs
local ipairs       = ipairs
local tonumber     = tonumber
local setmetatable = setmetatable
local getmetatable = getmetatable
local require      = require
local unpack       = unpack

local math         = require "math"
local string       = require "string"
local table        = require "table"

module "oil.cdr"                                                                --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local oo     = require "oil.oo"
local assert = require "oil.assert"
local bit    = require "oil.bit"
local IDL    = require "oil.idl"
local tcode  = require "oil.tcode"
local giop   = require "oil.giop"

--------------------------------------------------------------------------------
-- Local module functions ------------------------------------------------------

local function alignbuffer(self, alignment)
	local extra = math.mod(self.cursor - 1, alignment)
	if extra > 0 then self:jump(alignment - extra) end
end

NativeEndianess = (bit.endianess() == "little")

--------------------------------------------------------------------------------
--##  ##  ##  ##  ##   ##   ####   #####    ####  ##  ##   ####   ##     ##   --
--##  ##  ### ##  ### ###  ##  ##  ##  ##  ##     ##  ##  ##  ##  ##     ##   --
--##  ##  ######  #######  ######  #####    ###   ######  ######  ##     ##   --
--##  ##  ## ###  ## # ##  ##  ##  ##  ##     ##  ##  ##  ##  ##  ##     ##   --
-- ####   ##  ##  ##   ##  ##  ##  ##  ##  ####   ##  ##  ##  ##  #####  #####--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Unmarshalling buffer class --------------------------------------------------

ReadBuffer = oo.class{
	start = 1,
	cursor = 1,
	unpack = bit.unpack, -- use current platform native endianess
}

-- NOTE: second parameter indicates an encasulated octet-stream, therefore
--       endianess must be read from stream.
function ReadBuffer:__init(octets, getorder, object)
	self = oo.rawnew(self, { data = octets, object = object })
	self.history = self
	if getorder then self:order(self:boolean()) end
	return self
end

function ReadBuffer:order(value)
	if value ~= NativeEndianess then
		self.unpack = bit.invunpack
	end
end

function ReadBuffer:jump(shift)
	self.cursor = self.cursor + shift
	if self.cursor - 1 > string.len(self.data) then
		assert.ilegal(self.data, "data stream, insufficient data", "MARSHALL")
	end
end

function ReadBuffer:get(idltype)
	local unmarshall = self[idltype._type]
	if not unmarshall then
		assert.ilegal(idltype._type, "supported type", "MARSHALL")
	end
	return unmarshall(self, idltype)
end

function ReadBuffer:getdata()
	return self.data
end

function ReadBuffer:pointto(buffer)
	self.start = buffer.start + buffer.cursor - string.len(self.data) - 1
	self.history = buffer.history
end

function ReadBuffer:indirection(unmarshall, ...)
	local pos = self.start + self.cursor - 1
	local tag = self:ulong()
	if tag == 4294967295 then -- indirection marker (0xffffffff)
		pos = self.start + self.cursor - 1
		return self.history[pos + self:long()]
	else
		local value = unmarshall(tag, self, unpack(arg))
		self.history[pos] = value
		return value
	end
end

--------------------------------------------------------------------------------
-- Unmarshalling functions -----------------------------------------------------
                                                                                --[[VERBOSE]] local VERBOSE_NumberTypeCode = {s=IDL.short,l=IDL.long,S=IDL.ushort,L=IDL.ulong,f=IDL.float,d=IDL.double}
local function numberunmarshaller(size, format)
	return function (self)
		alignbuffer(self, size)
		local value = self.unpack(format, self.data, nil, nil, self.cursor)         --[[VERBOSE]] verbose.unmarshallOf(VERBOSE_NumberTypeCode[format], value, self, true)
		self:jump(size)
		return value
	end
end

ReadBuffer.void     = function() end -- TODO:[maia] Should null be the same?
ReadBuffer.short    = numberunmarshaller(2, "s")
ReadBuffer.long     = numberunmarshaller(4, "l")
ReadBuffer.ushort   = numberunmarshaller(2, "S")
ReadBuffer.ulong    = numberunmarshaller(4, "L")
ReadBuffer.float    = numberunmarshaller(4, "f")
ReadBuffer.double   = numberunmarshaller(8, "d")
ReadBuffer.TypeCode = tcode.get

function ReadBuffer:boolean()                                                   --[[VERBOSE]] verbose.unmarshallOf(IDL.boolean, nil, self)
	return (self:octet() ~= 0)                                                    --[[VERBOSE]] , verbose.unmarshall()
end

function ReadBuffer:char()
	local value = string.sub(self.data, self.cursor, self.cursor)                 --[[VERBOSE]] verbose.unmarshallOf(IDL.char, value, self, true)
	self:jump(1)
	return value
end

function ReadBuffer:octet()
	local value = self.unpack("B", self.data, nil, nil, self.cursor)              --[[VERBOSE]] verbose.unmarshallOf(IDL.octet, value, self, true)
	self:jump(1)
	return value
end

function ReadBuffer:any()                                                       --[[VERBOSE]] verbose.unmarshallOf(IDL.any, nil, self)
	local idltype = self:TypeCode()                                               --[[VERBOSE]] verbose.unmarshall{"got any of type ", idltype._type, " ", idltype.repID or ""}
	local value = self:get(idltype)                                               --[[VERBOSE]] verbose.unmarshall()
	if type(value) == "table"
		then value._anyval = value
		else value = setmetatable({_anyval = value}, idltype)
	end
	return value
end

function ReadBuffer:Object(idltype)                                             --[[VERBOSE]] verbose.unmarshallOf(idltype, nil, self)
	local ior = self:IOR()                                                        --[[VERBOSE]] verbose.unmarshall{"got ", ior._type_id, " object"} verbose.unmarshall()
	if ior._type_id ~= "" then
		local object = self.object
		if object and object._manager then                                          --[[VERBOSE]] verbose.unmarshall("recovering object from IOR by a object manager", true)
			if idltype._type == "Object" then idltype = idltype.repID end
			ior = object._manager:resolve(ior, idltype)                               --[[VERBOSE]] verbose.unmarshall()
		end
		return ior
	end
end

function ReadBuffer:struct(idltype)                                             --[[VERBOSE]] verbose.unmarshallOf(idltype, nil, self)
	local value = {}
	for _, field in ipairs(idltype.fields) do                                     --[[VERBOSE]] verbose.unmarshall{"[field ", field.name, "]"}
		value[field.name] = self:get(field.type)
	end                                                                           --[[VERBOSE]] verbose.unmarshall()
	return setmetatable(value, idltype)
end

function ReadBuffer:union(idltype)                                              --[[VERBOSE]] verbose.unmarshallOf(idltype, nil, self) verbose.unmarshall "[union switch]"
	local switch = self:get(idltype.switch)
	local option = idltype.selection[switch]
	if option then                                                                --[[VERBOSE]] verbose.unmarshall "[union value]"
		local value = self:get(option.type)                                         --[[VERBOSE]] verbose.unmarshall()
		return setmetatable({
			_switch = switch,
			_value  = value,
			_field  = option.name,
		}, idltype)
	else
		return setmetatable({ _switch = switch }, idltype)
	end
end

function ReadBuffer:enum(idltype)                                               --[[VERBOSE]] verbose.unmarshallOf(idltype, nil, self)
	local value = self:ulong() + 1                                                --[[VERBOSE]] verbose.unmarshall()
	if value > table.getn(idltype.enumvalues) then
		assert.ilegal(value, "enumeration value", "MARSHAL")
	end
	return idltype.enumvalues[value]
end

function ReadBuffer:string()                                                    --[[VERBOSE]] verbose.unmarshallOf(IDL.string, nil, self)
	local length = self:ulong()
	local value = string.sub(self.data,
	                         self.cursor, -- take out the \0
	                         self.cursor + length - 2)                            --[[VERBOSE]] verbose.unmarshall{"string value is ", verbose.valueOf(value, "unmarshall")} verbose.unmarshall()
	self:jump(length)
	return value
end

function ReadBuffer:sequence(idltype)                                           --[[VERBOSE]] verbose.unmarshallOf(idltype, nil, self)
	local length      = self:ulong()
	local elementtype = idltype.elementtype
	local value
	if elementtype._type == "octet" or elementtype._type == "char" then
		value = string.sub(self.data,
		                   self.cursor,
		                   self.cursor + length - 1)                                --[[VERBOSE]] verbose.unmarshall{"sequence value is ", verbose.valueOf(value, "unmarshall")}
		self:jump(length)
	else
		value = setmetatable({ n = length }, idltype)
		for i = 1, length do                                                        --[[VERBOSE]] verbose.unmarshall{"[element ", i, "]"}
			value[i] = self:get(elementtype)
		end
	end                                                                           --[[VERBOSE]] verbose.unmarshall()
	return value
end

function ReadBuffer:array(idltype)                                              --[[VERBOSE]] verbose.unmarshallOf(idltype, nil, self)
	local length      = idltype.length
	local elementtype = idltype.elementtype
	local value
	if elementtype._type == "octet" or elementtype._type == "char" then
		value = string.sub(self.data,
		                   self.cursor,
		                   self.cursor + length - 1)                                --[[VERBOSE]] verbose.unmarshall{"array value is ", verbose.valueOf(value, "unmarshall")}
		self:jump(length)
	else
		value = setmetatable({ n = length }, idltype)
		for i = 1, length do                                                        --[[VERBOSE]] verbose.unmarshall{"[element ", i, "]"}
			value[i] = self:get(elementtype)
		end
	end                                                                           --[[VERBOSE]] verbose.unmarshall()
	return value
end

function ReadBuffer:typedef(idltype)                                            --[[VERBOSE]] verbose.unmarshallOf(idltype, nil, self)
	return self:get(idltype.type)                                                 --[[VERBOSE]] , verbose.unmarshall()
end

function ReadBuffer:except(idltype)                                             --[[VERBOSE]] verbose.unmarshallOf(idltype, nil, self)
	local value = {}
	for _, field in ipairs(idltype.members) do                                    --[[VERBOSE]] verbose.marshall{"[member ", field.name, "]"}
		value[field.name] = self:get(field.type)
	end                                                                           --[[VERBOSE]] verbose.unmarshall()
	return setmetatable(value, idltype)
end

function ReadBuffer:IOR() return self:struct(giop.IOR) end
ReadBuffer.interface = ReadBuffer.Object

--------------------------------------------------------------------------------
--   ##   ##   #####   ######    ######  ##   ##   #####   ##       ##        --
--   ### ###  ##   ##  ##   ##  ##       ##   ##  ##   ##  ##       ##        --
--   #######  #######  ######    #####   #######  #######  ##       ##        --
--   ## # ##  ##   ##  ##   ##       ##  ##   ##  ##   ##  ##       ##        --
--   ##   ##  ##   ##  ##   ##  ######   ##   ##  ##   ##  #######  #######   --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Unmarshalling buffer class --------------------------------------------------

WriteBuffer = oo.class {
	start = 1,
	cursor = 1,
	emptychar = '\255', -- character used in buffer alignment
	pack = bit.pack,    -- use current platform native endianess
}

-- NOTE: Presence of a parameter indicates an encapsulated octet-stream.
--       Parameter value indicates which endianess must be used.
--       (little = 0; big = 1)
function WriteBuffer:__init(putorder, object)
	self = oo.rawnew(self, { format = {}, object = object })
	self.history = self
	if putorder then
		self:boolean(NativeEndianess)
	end
	return self
end

function WriteBuffer:shift(shift)
	self.cursor = self.cursor + shift
end

function WriteBuffer:jump(shift)
	self:rawput('"', string.rep(self.emptychar, shift), shift)
end

function WriteBuffer:rawput(format, data, size)
	table.insert(self.format, format)
	table.insert(self, data)
	self.cursor = self.cursor + size
end

function WriteBuffer:put(value, idltype)
	local marshall = self[idltype._type]
	if not marshall then
		assert.ilegal(idltype._type, "supported type", "MARSHALL")
	end
	return marshall(self, value, idltype)
end

function WriteBuffer:getdata()
	return self.pack(table.concat(self.format), self)
end

function WriteBuffer:getlength()
	return self.cursor - 1
end

function WriteBuffer:pointto(buffer)
	self.start = buffer.start + buffer:getlength()
	self.history = buffer.history
end

function WriteBuffer:indirection(marshall, value, ...)
	local previous = self.history[value]
	if previous then
		self:ulong(4294967295) -- indirection marker (0xffffffff)
		self:long(previous - self.start + self:getlength()) -- offset
	else
		self.history[value] = self.start + self:getlength()
		marshall(self, value, unpack(arg))
	end
end

--------------------------------------------------------------------------------
-- Marshalling functions -------------------------------------------------------

local function numbermarshaller(size, format)
	return function (self, value)                                                 --[[VERBOSE]] verbose.marshallOf(VERBOSE_NumberTypeCode[format], value, self, true)
		assert.type(value, "number", "numeric value", "MARSHAL")
		alignbuffer(self, size)
		self:rawput(format, value, size)
	end
end

WriteBuffer.void     = function() end -- TODO:[maia] Should null be the same?
WriteBuffer.short    = numbermarshaller(2, "s")
WriteBuffer.long     = numbermarshaller(4, "l")
WriteBuffer.ushort   = numbermarshaller(2, "S")
WriteBuffer.ulong    = numbermarshaller(4, "L")
WriteBuffer.float    = numbermarshaller(4, "f")
WriteBuffer.double   = numbermarshaller(8, "d")
WriteBuffer.TypeCode = tcode.put

function WriteBuffer:boolean(value)                                             --[[VERBOSE]] verbose.marshallOf(IDL.boolean, nil, self)
	if value
		then self:octet(1)
		else self:octet(0)
	end                                                                           --[[VERBOSE]] verbose.marshall()
end

function WriteBuffer:char(value)                                                --[[VERBOSE]] verbose.marshallOf(IDL.char, value, self, true)
	assert.type(value, "string", "char value", "MARSHAL")
	if string.len(value) ~= 1 then
		assert.ilegal(value, "char value", "MARSHAL")
	end
	self:rawput('"', value, 1)
end

function WriteBuffer:octet(value)                                               --[[VERBOSE]] verbose.marshallOf(IDL.octet, value, self, true)
	assert.type(value, "number", "octet value", "MARSHAL")
	self:rawput("B", value, 1)
end

-- TODO:[maia] Garantee that every unmarshalled value can be used as an
--             CORBA's any value.
local DefaultMapping = {
	-- TODO:[maia] Should nil be mapped to something? an Object ref. maybe?
	number  = IDL.double,
	string  = IDL.string,
	boolean = IDL.boolean,
}
function WriteBuffer:any(value)                                                 --[[VERBOSE]] verbose.marshallOf(IDL.any, nil, self)
	local luatype = type(value)
	local idltype = DefaultMapping[luatype]
	if not idltype then
		local metatable = getmetatable(value)
		if metatable then
			if IDL.istype(metatable) then
				idltype = metatable                                                     --[[VERBOSE]] verbose.marshall{"value metatable is ", idltype._type}
			elseif IDL.istype(metatable.__idltype) then
				idltype = metatable.__idltype                                           --[[VERBOSE]] verbose.marshall{"metatable define type ", idltype._type}
			end
		end
		if luatype == "table" then
			if not idltype and IDL.istype(value._anytype) then
				idltype = value._anytype
			end
			if value._anyval ~= nil then
				value = value._anyval
			end
		end                                                                         --[[VERBOSE]] else verbose.marshall{"using default map to ", idltype._type}
	end
	if not idltype then
		assert.ilegal(value, "any, unable to map into an IDL type", "MARSHAL")
	end                                                                           --[[VERBOSE]] verbose.marshall "[type of any]"
	self:TypeCode(idltype)                                                        --[[VERBOSE]] verbose.marshall "[value of any]"
	self:put(value, idltype)                                                      --[[VERBOSE]] verbose.marshall()
end

local NullReference = { _type_id = "", _profiles = { n=0 } }
function WriteBuffer:Object(value, idltype)
	if value == nil then
		value = NullReference
	else
		assert.type(value, "table", "object reference", "MARSHAL")
		if not value._type_id or not value._profiles then
			local object = self.object
			if object and object._orb then                                            --[[VERBOSE]] verbose.marshall("implicit servant creation", true)
				if idltype._type == "Object" then idltype = idltype.repID end
				value = object._orb:object(value, idltype)                              --[[VERBOSE]] verbose.marshall()
			else
				assert.ilegal(value, "Object, unable to create from table", "MARHSALL")
			end
		end
	end
	self:IOR(value)
end

function WriteBuffer:struct(value, idltype)                                     --[[VERBOSE]] verbose.marshallOf(idltype, value, self)
	assert.type(value, "table", "struct value", "MARSHAL")
	for _, field in ipairs(idltype.fields) do
		local val = value[field.name]                                               --[[VERBOSE]] verbose.marshall{"[field ", field.name, "]"}
		-- TODO:[maia] Check out if fields can be Object references and
		--             hold nil values.
		if not val and field.type ~= IDL.boolean then
			assert.ilegal(value,
			              "struct value (no value for field "..field.name..")",
			              "MARSHAL")
		end
		self:put(val, field.type)
	end                                                                           --[[VERBOSE]] verbose.marshall()
end

function WriteBuffer:union(value, idltype)                                      --[[VERBOSE]] verbose.marshallOf(idltype, value, self)
	assert.type(value, "table", "union value", "MARSHAL")
	local switch = value._switch
	local unionvalue = value._value

	-- Marshal discriminator
	if switch == nil then
		switch = idltype.selector[value._field]
		if switch == nil then
			for _, option in ipairs(idltype.options) do
				if value[option.name] then
					switch = option.label
					unionvalue = value[option.name]
					break
				end
			end
			if switch == nil then
				switch = idltype.options[idltype.default+1]
				if switch == nil then
					assert.ilegal(value, "union (no discriminator)", "MARSHAL")
				end
			end
		end
	end                                                                           --[[VERBOSE]] verbose.marshall "[union switch]"
	self:put(switch, idltype.switch)
	
	local selection = idltype.selection[switch]
	if selection then
		-- Marshal union value
		if unionvalue == nil then
			unionvalue = value[selection.name]
			if unionvalue == nil then
				assert.ilegal(value, "union (no value)", "MARSHAL")
			end
		end                                                                         --[[VERBOSE]] verbose.marshall "[union value]"
		self:put(unionvalue, selection.type)
	end                                                                           --[[VERBOSE]] verbose.marshall()
end

function WriteBuffer:enum(value, idltype)                                       --[[VERBOSE]] verbose.marshallOf(idltype, value, self)
	value = tonumber(value) or idltype.labelvalue[value]
	if not value then assert.ilegal(value, "enum value", "MARSHAL") end
	self:ulong(value)                                                             --[[VERBOSE]] verbose.marshall()
end

function WriteBuffer:string(value)                                              --[[VERBOSE]] verbose.marshallOf(IDL.string, value, self)
	assert.type(value, "string", "string value", "MARSHAL")
	local length = string.len(value)
	self:ulong(length + 1)
	self:rawput('"', value, length)
	self:rawput('"', '\0', 1)                                                     --[[VERBOSE]] verbose.marshall()
end

function WriteBuffer:sequence(value, idltype)                                   --[[VERBOSE]] verbose.marshallOf(idltype, value, self)
	local elementtype = idltype.elementtype
	if
		type(value) == "string" and
		(elementtype == IDL.octet or elementtype == IDL.char)
	then
		local length = string.len(value)
		self:ulong(length)
		self:rawput('"', value, length)
	else
		assert.type(value, "table", "sequence value", "MARSHAL")
		local size = table.getn(value)
		self:ulong(size)
		for i = 1, size do                                                          --[[VERBOSE]] verbose.marshall{"[element ", i, "]"}
			self:put(value[i], elementtype) 
		end
	end                                                                           --[[VERBOSE]] verbose.marshall()
end

function WriteBuffer:array(value, idltype)                                      --[[VERBOSE]] verbose.marshallOf(idltype, value, self)
	local elementtype = idltype.elementtype
	local length -- TODO:[maia] In Lua 5.1 add: = #value
	if
		type(value) == "string" and
		(elementtype == IDL.octet or elementtype == IDL.char)
	then
		length = string.len(value)
		if length ~= idltype.length then
			assert.ilegal(value, "array value (wrong length)", "MARSHAL")
		end
		self:rawput('"', value, length)
	else
		assert.type(value, "table", "array value", "MARSHAL")
		length = table.getn(value)
		if length ~= idltype.length then
			assert.ilegal(value, "array value (wrong length)", "MARSHAL")
		end
		for i = 1, length do                                                        --[[VERBOSE]] verbose.marshall{"[element ", i, "]"}
			self:put(value[i], elementtype)
		end
	end                                                                           --[[VERBOSE]] verbose.marshall()
end

function WriteBuffer:typedef(value, idltype)                                    --[[VERBOSE]] verbose.marshallOf(idltype, value, self)
	self:put(value, idltype.type)                                                 --[[VERBOSE]] verbose.marshall()
end

function WriteBuffer:except(value, idltype)                                     --[[VERBOSE]] verbose.marshallOf(idltype, value, self)
	assert.type(value, "table", "except value", "MARSHAL")
	for _, field in ipairs(idltype.members) do                                    --[[VERBOSE]] verbose.marshall{"[member ", field.name, "]"}
		local val = value[field.name]
		-- TODO:[maia] Check out if fields can be Object references and
		--             hold nil values.
		if not val and field.type ~= IDL.boolean then
			assert.ilegal(value,
			              "except value (no value for field "..field.name..")",
			              "MARSHAL")
		end
		self:put(val, field.type)
	end                                                                           --[[VERBOSE]] verbose.marshall()
end

function WriteBuffer:IOR(value) return self:struct(value, giop.IOR) end
WriteBuffer.interface = WriteBuffer.Object
