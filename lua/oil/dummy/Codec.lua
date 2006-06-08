
local type         = type
local pairs        = pairs
local ipairs       = ipairs
local tonumber     = tonumber
local setmetatable = setmetatable
local getmetatable = getmetatable
local require      = require
local print        = print

local math         = require "math"
local string       = require "string"
local table        = require "table"

module "oil.dummy.Codec"                                                                --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local oo     = require "oil.oo"
local assert = require "oil.assert"
local bit    = require "oil.bit"
local IDL    = require "oil.idl"
local tcode  = require "oil.corba.tcode"
local giop   = require "oil.corba.giop"

--------------------------------------------------------------------------------
-- Local module functions ------------------------------------------------------

local function alignbuffer(self, alignment)
	local extra = math.mod(self.cursor - 1, alignment)
	if extra > 0 then self:jump(alignment - extra) end
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

local ReadBuffer = oo.class{}

function ReadBuffer:__init(octets, getorder, object)
	local buffer = oo.rawnew(self, { data = octets, object = object })
	return buffer
end

function ReadBuffer:get(idltype)
	local unmarshall = self[idltype._type]
	if not unmarshall then
		assert.illegal(idltype._type, "supported type", "MARSHALL")
	end
	return unmarshall(self, idltype)
end

function ReadBuffer:getdata()
	return self.data
end

--------------------------------------------------------------------------------
-- Unmarshalling functions -----------------------------------------------------
																																								

function ReadBuffer:boolean()                                                   
	return (self:octet() ~= 0)                                                    
end

function ReadBuffer:char()
	local value = string.sub(self.data, self.cursor, self.cursor)                 
	self:jump(1)
	return value
end

function ReadBuffer:octet()
	local value = bit.unpack("B", self.data, self.cursor)                         
	self:jump(1)
	return value
end

function ReadBuffer:any()                                                       
	local idltype = self:TypeCode()                                               
	local value = self:get(idltype)                                               
	if type(value) == "table"
		then value._anyval = value
		else value = setmetatable({_anyval = value}, idltype)
	end
	return value
end

function ReadBuffer:Object(idltype)                                             
	local ior = self:IOR()                                                        
	if ior._type_id ~= "" then
		local object = self.object
		if object and object._manager then                                          
			if idltype._type == "Object" then idltype = idltype.repID end
			ior = object._manager:resolve(ior, idltype)                               
		end
		return ior
	end
end

function ReadBuffer:struct(idltype)                                             
	local value = {}
	for _, field in ipairs(idltype.fields) do                                     
		value[field.name] = self:get(field.type)
	end                                                                           
	return setmetatable(value, idltype)
end

function ReadBuffer:union(idltype)                                              
	local switch = self:get(idltype.switch)
	local option = idltype.selection[switch]
	if option then                                                                
		local value = self:get(option.type)                                         
		return setmetatable({
			_switch = switch,
			_value  = value,
			_field  = option.name,
		}, idltype)
	else
		return setmetatable({ _switch = switch }, idltype)
	end
end

function ReadBuffer:enum(idltype)                                               
	local value = self:ulong() + 1                                                
	if value > table.getn(idltype.enumvalues) then
		assert.illegal(value, "enumeration value", "MARSHAL")
	end
	return idltype.enumvalues[value]
end

function ReadBuffer:string()                                                    
	local length = self:ulong()
	local value = string.sub(self.data,
														self.cursor, -- take out the \0
														self.cursor + length - 2)                            
	self:jump(length)
	return value
end

function ReadBuffer:sequence(idltype)                                           
	local length      = self:ulong()
	local elementtype = idltype.elementtype
	local value
	if elementtype._type == "octet" or elementtype._type == "char" then
		value = string.sub(self.data,
												self.cursor,
												self.cursor + length - 1)                                
		self:jump(length)
	else
		value = setmetatable({ n = length }, idltype)
		for i = 1, length do                                                        
			value[i] = self:get(elementtype)
		end
	end                                                                           
	return value
end

function ReadBuffer:array(idltype)                                              
	local length      = idltype.length
	local elementtype = idltype.elementtype
	local value
	if elementtype._type == "octet" or elementtype._type == "char" then
		value = string.sub(self.data,
												self.cursor,
												self.cursor + length - 1)                                
		self:jump(length)
	else
		value = setmetatable({ n = length }, idltype)
		for i = 1, length do                                                        
			value[i] = self:get(elementtype)
		end
	end                                                                           
	return value
end

function ReadBuffer:typedef(idltype)                                            
	return self:get(idltype.type)                                                 
end

function ReadBuffer:except(idltype)                                             
	local value = {}
	for _, field in ipairs(idltype.members) do                                    
		value[field.name] = self:get(field.type)
	end                                                                           
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

local WriteBuffer = oo.class {
	cursor = 1,
	emptychar = '\255', -- character used in buffer alignment
	endianess = '>',    -- TODO:[maia] use current platform native endianess
}

-- NOTE: Presence of a parameter indicates an encapsulated octet-stream.
--       Parameter value indicates which endianess must be used.
--       (little = 0; big = 1)
function WriteBuffer:__init(order, object)
	if not order then
		return oo.rawnew(self, { object = object, n = 0})
	elseif order == "little" then
		return oo.rawnew(self, { object = object, '\1', n=1,
			cursor = 2,
			endianess = '<',
		})
	-- TODO:[maia] use current platform native endianess
	elseif order == "big" or order == true then
		return oo.rawnew(self, { object = object, '\0', n=1,
			cursor = 2,
			endianess = '>',
		})
	end
	assert.illegal(order, "buffer order")
end

function WriteBuffer:shift(shift)
	self.cursor = self.cursor + shift
end

function WriteBuffer:jump(shift)
	table.insert(self, string.rep(self.emptychar, shift))
	self:shift(shift)
end

function WriteBuffer:rawput(data)
	self.cursor = self.cursor + string.len(data)
	table.insert(self, data)
end

function WriteBuffer:put(value, idltype)
	local marshall = self[idltype._type]
	if not marshall then
		assert.illegal(idltype._type, "supported type", "MARSHALL")
	end
	return marshall(self, value, idltype)
end

function WriteBuffer:getdata()
	return table.concat(self)
end

function WriteBuffer:getlength()
	return self.cursor - 1
end

--------------------------------------------------------------------------------
-- Marshalling functions -------------------------------------------------------

local function numbermarshaller(size, format)
	return function (self, value)                                                 
		assert.type(value, "number", "numeric value", "MARSHAL")
		alignbuffer(self, size)
		self:rawput(bit.pack(self.endianess..format, value))
	end
end

WriteBuffer.void     = function() end -- TODO:[maia] Should null be the same?
WriteBuffer.short    = numbermarshaller(2, "s")
WriteBuffer.long     = numbermarshaller(4, "l")
WriteBuffer.ushort   = numbermarshaller(2, "S")
WriteBuffer.ulong    = numbermarshaller(4, "L")
WriteBuffer.float    = numbermarshaller(4, "f")
WriteBuffer.double   = numbermarshaller(8, "d")
WriteBuffer.TypeCode = tcode.marshall

function WriteBuffer:boolean(value)                                             
	if value
		then self:octet(1)
		else self:octet(0)
	end                                                                           
end

function WriteBuffer:char(value)                                                
	assert.type(value, "string", "char value", "MARSHAL")
	if string.len(value) ~= 1 then
		assert.illegal(value, "char value", "MARSHAL")
	end
	self:rawput(value)
end

function WriteBuffer:octet(value)                                               
	assert.type(value, "number", "octet value", "MARSHAL")
	self:rawput(bit.pack("B", value))
end

-- TODO:[maia] Garantee that every unmarshalled value can be used as an
--             CORBA's any value.
local DefaultMapping = {
	-- TODO:[maia] Should nil be mapped to something? an Object ref. maybe?
	number  = IDL.double,
	string  = IDL.string,
	boolean = IDL.boolean,
}
function WriteBuffer:any(value)                                                 
	local luatype = type(value)
	local idltype = DefaultMapping[luatype]
	if not idltype then
		local metatable = getmetatable(value)
		if metatable then
			if IDL.istype(metatable) then
				idltype = metatable                                                     
			elseif IDL.istype(metatable.__idltype) then
				idltype = metatable.__idltype                                           
			end
		end
		if luatype == "table" then
			if not idltype and IDL.istype(value._anytype) then
				idltype = value._anytype
			end
			if value._anyval ~= nil then
				value = value._anyval
			end
		end                                                                         
	end
	if not idltype then
		assert.illegal(value, "any, unable to map into an IDL type", "MARSHAL")
	end                                                                           
	self:TypeCode(idltype)                                                        
	self:put(value, idltype)                                                      
end

local NullReference = { _type_id = "", _profiles = { n=0 } }
function WriteBuffer:Object(value, idltype)
	if value == nil then
		value = NullReference
	else
		assert.type(value, "table", "object reference", "MARSHAL")
		if not value._type_id or not value._profiles then
			local object = self.object
			if object and object._orb then                                            
				if idltype._type == "Object" then idltype = idltype.repID end
				value = object._orb:object(value, idltype)                              
			else
				assert.illegal(value, "Object, unable to create from table", "MARHSALL")
			end
		end
	end
	self:IOR(value)
end

function WriteBuffer:struct(value, idltype)                                     
	assert.type(value, "table", "struct value", "MARSHAL")
		for _, field in ipairs(idltype.fields) do
		local val = value[field.name]                                               
		-- TODO:[maia] Check out if fields can be Object references and
		--             hold nil values.
		if not val and field.type ~= IDL.boolean then
			assert.illegal(value,
										"struct value (no value for field "..field.name..")",
										"MARSHAL")
		end
		self:put(val, field.type)
	end                                                                           
end

function WriteBuffer:union(value, idltype)                                      
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
					assert.illegal(value, "union (no discriminator)", "MARSHAL")
				end
			end
		end
	end                                                                           
	self:put(switch, idltype.switch)
	
	local selection = idltype.selection[switch]
	if selection then
		-- Marshal union value
		if unionvalue == nil then
			unionvalue = value[selection.name]
			if unionvalue == nil then
				assert.illegal(value, "union (no value)", "MARSHAL")
			end
		end                                                                         
		self:put(unionvalue, selection.type)
	end                                                                           
end

function WriteBuffer:enum(value, idltype)                                       
if not idltype.labelvalue then verbose.Viewer:print(idltype) end
	value = tonumber(value) or idltype.labelvalue[value]
	if not value then assert.illegal(value, "enum value", "MARSHAL") end
	self:ulong(value)                                                             
end

function WriteBuffer:string(value)                                              
	assert.type(value, "string", "string value", "MARSHAL")
	self:ulong(string.len(value) + 1)
	self:rawput(value)
	self:rawput('\0')                                                             
end

function WriteBuffer:sequence(value, idltype)                                   
	local elementtype = idltype.elementtype
	if
		type(value) == "string" and
		(elementtype == IDL.octet or elementtype == IDL.char)
	then
		self:ulong(string.len(value))
		self:rawput(value)
	else
		assert.type(value, "table", "sequence value", "MARSHAL")
		local size = table.getn(value)
		self:ulong(size)
		for i = 1, size do                                                          
			self:put(value[i], elementtype) 
		end
	end                                                                           
end

function WriteBuffer:array(value, idltype)                                      
	local elementtype = idltype.elementtype
	if
		type(value) == "string" and
		(elementtype == IDL.octet or elementtype == IDL.char)
	then
		if string.len(value) ~= idltype.length then
			assert.illegal(value, "array value (wrong length)", "MARSHAL")
		end
		self:rawput(value)
	else
		assert.type(value, "table", "array value", "MARSHAL")
		if table.getn(value) ~= idltype.length then
			assert.illegal(value, "array value (wrong length)", "MARSHAL")
		end
		for i = 1, idltype.length do                                                
			self:put(value[i], elementtype)
		end
	end                                                                           
end

function WriteBuffer:typedef(value, idltype)                                    
	self:put(value, idltype.type)                                                 
end

function WriteBuffer:except(value, idltype)                                     
	assert.type(value, "table", "except value", "MARSHAL")
	for _, field in ipairs(idltype.members) do                                    
		local val = value[field.name]
		-- TODO:[maia] Check out if fields can be Object references and
		--             hold nil values.
		if not val and field.type ~= IDL.boolean then
			assert.illegal(value,
										"except value (no value for field "..field.name..")",
										"MARSHAL")
		end
		self:put(val, field.type)
	end                                                                           
end

function WriteBuffer:IOR(value) return self:struct(value, giop.IOR) end
WriteBuffer.interface = WriteBuffer.Object


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function newEncoder(self, ...)
	return WriteBuffer(...)
end

function newDecoder(self, stream, ...)
	return ReadBuffer(stream, ...)
end

Codec = oo.class{}
Codec.newEncoder = newEncoder
Codec.newDecoder = newDecoder
return Codec
