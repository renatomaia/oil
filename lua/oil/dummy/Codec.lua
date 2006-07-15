
local type         = type
local pairs        = pairs
local ipairs       = ipairs
local tonumber     = tonumber
local require      = require
local print        = print
local string       = string

module "oil.dummy.Codec"                                                                --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local oo         = require "oil.oo"
local assert     = require "oil.assert"
--------------------------------------------------------------------------------
-- Local module functions ------------------------------------------------------

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

function ReadBuffer:__init()
	return oo.rawnew(self)
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

function ReadBuffer:number()
	local value = bit.unpack("B", self.data, self.cursor)                         
	self:jump(1)
	return value
end

function ReadBuffer:table(idltype)                                             
	local value = {}
	for _, field in ipairs(idltype.fields) do                                     
		value[field.name] = self:get(field.type)
	end                                                                           
	return setmetatable(value, idltype)
end


function ReadBuffer:string()                                                    
	local length = self:ulong()
	local value = string.sub(self.data,
														self.cursor, -- take out the \0
														self.cursor + length - 2)                            
	self:jump(length)
	return value
end

--------------------------------------------------------------------------------
--   ##   ##   #####   ######    ######  ##   ##   #####   ##       ##        --
--   ### ###  ##   ##  ##   ##  ##       ##   ##  ##   ##  ##       ##        --
--   #######  #######  ######    #####   #######  #######  ##       ##        --
--   ## # ##  ##   ##  ##   ##       ##  ##   ##  ##   ##  ##       ##        --
--   ##   ##  ##   ##  ##   ##  ######   ##   ##  ##   ##  #######  #######   --
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- Unmarshalling buffer class --------------------------------------------------

local WriteBuffer = oo.class {}

function WriteBuffer:__init()
	return oo.rawnew(self)
end


function WriteBuffer:put(value)
	local marshall = self[type(value)]
	if not marshall then
		assert.illegal(type(value), "supported type", "MARSHALL")
	end
	return marshall(self, value)
end

function WriteBuffer:getdata()
	return table.concat(self)
end

--------------------------------------------------------------------------------
-- Marshalling functions -------------------------------------------------------


function WriteBuffer:boolean(value)                                             
	if value
		then self:octet(1)
		else self:octet(0)
	end                                                                           
end

function WriteBuffer:number(value)                                                
	assert.type(value, "string", "char value", "MARSHAL")
	if string.len(value) ~= 1 then
		assert.illegal(value, "char value", "MARSHAL")
	end
	self:rawput(value)
end


function WriteBuffer:table(value, idltype)                                     
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


function WriteBuffer:string(value)                                              
	assert.type(value, "string", "string value", "MARSHAL")
	self:ulong(string.len(value) + 1)
	self:rawput(value)
	self:rawput('\0')                                                             
end


function table2str(tbl, tab)
	if not tab then tab = 1 end
	if tab == 0 then tab = -1 end
	local out = ''

	local stringifier = {
		['nil'] = function (TT, tab)
			return tostring(TT)
		end,

		['boolean'] = function (TT, tab)
			return tostring(TT)
		end,

		['string'] = function (TT, tab)
			return ( TT == '__nil__' and 'nil' ) or string.format( '%q', TT )
		end,

		['number'] = function (TT, tab)
			return TT..''
		end,

		['function'] = function (TT, tab)
			return 'function'
		end,

		['table'] = function (TT, tab)
			local sorted = {}
			table.foreach( TT, function(k,_) table.insert(sorted, k) end )
			local out = '{\n'
			for _,k in ipairs(sorted) do
				assert( table.contains( { 'string', 'number', 'boolean' }, type(k) ), 'Invalid key type: '..type(k)..'.' )
				v = TT[k]
				out = out .. string.rep('    ',tab) ..string.format("%-8s = ", '['..table.tostring(k)..']') .. table.tostring(v, tab+1) .. ',\n'
			end
			out = out .. string.rep('    ',tab-1) .. '}'
			if tab == -1 then out = string.gsub(out, '\n', '') out = string.gsub(out, ' +', ' ') end
				return out
		end,
	}
	setmetatable( stringifier, { __index = function(t, id) error("Invalid type: "..id..".") end } )
	return stringifier[type(TT)]( TT, tab )
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function newEncoder(self, ...)
	print("new encoder")
	local buffer = WriteBuffer(...)
	for k, v in pairs(buffer) do
		print(k, v)
	end

	return WriteBuffer(...)
end

function newDecoder(self, stream, ...)
	return ReadBuffer(stream, ...)
end

Codec = oo.class{}
Codec.newEncoder = newEncoder
Codec.newDecoder = newDecoder
return Codec
