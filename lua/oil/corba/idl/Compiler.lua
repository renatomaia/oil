-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.6
-- Title  : Interface Definition Language (IDL) compiler
-- Authors: Renato Maia   <maia@inf.puc-rio.br>
--          Ricardo Cosme <rcosme@tecgraf.puc-rio.br>

local _G = require "_G"
local ipairs = _G.ipairs
local pairs = _G.pairs
local select = _G.select

local array = require "table"
local unpack = array.unpack or _G.unpack

local table  = require "loop.table"
local copy = table.copy

local luaidl = require "luaidl"
local parseidl = luaidl.parse
local parseidlfile = luaidl.parsefile

local oo  = require "oil.oo"
local class = oo.class
local rawnew = oo.rawnew

local idl = require "oil.corba.idl"
local idlinterface = idl.interface
local idlmodule = idl.module


local DefaultOptions = {
	callbacks = {
		VOID      = idl.void,
		SHORT     = idl.short,
		LONG      = idl.long,
		LLONG     = idl.longlong,
		USHORT    = idl.ushort,
		ULONG     = idl.ulong,
		ULLONG    = idl.ulonglong,
		FLOAT     = idl.float,
		DOUBLE    = idl.double,
		LDOUBLE   = idl.longdouble,
		BOOLEAN   = idl.boolean,
		CHAR      = idl.char,
		OCTET     = idl.octet,
		ANY       = idl.any,
		TYPECODE  = idl.TypeCode,
		STRING    = idl.string,
		OBJECT    = idl.object,
		VALUEBASE = idl.ValueBase,
		operation = idl.operation,
		attribute = idl.attribute,
		except    = idl.except,
		union     = idl.union,
		struct    = idl.struct,
		enum      = idl.enum,
		array     = idl.array,
		sequence  = idl.sequence,
		valuetype = idl.valuetype,
		valuebox  = idl.valuebox,
		typedef   = idl.typedef,
	},
}

function DefaultOptions.callbacks.interface(def)
	if def.definitions then -- not forward declarations
		return idlinterface(def)
	end
	return def
end

local Modules
function DefaultOptions.callbacks.module(def)
	Modules[def] = true
	return def
end

function DefaultOptions.callbacks.const(def)
	def.val, def.value = def.value, nil
	return def
end

function DefaultOptions.callbacks.start()
	Modules = {}
end

function DefaultOptions.callbacks.finish()
	for module in pairs(Modules) do idlmodule(module) end
	Modules = nil
end

--------------------------------------------------------------------------------

local Compiler = class{
	context = false,
	DefaultOptions = DefaultOptions,
}

function Compiler:__new(...)
	self = rawnew(self, ...)
	self.defaults = copy(DefaultOptions)
	return self
end

function Compiler:doresults(...)
	if ... then
		return self.context.__component:register(...)
	end
	return ...
end

function Compiler:options(idlpaths)
	local options = copy(self.defaults)
	if idlpaths 
	local incpath = copy(options.incpath) or {}
		for index, path in ipairs(idlpaths) do
			incpath[#incpath+1] = path
		end
		options.incpath = incpath
	end
	return options
end

function Compiler:loadfile(filepath, idlpaths)
	return self:doresults(parseidlfile(filepath, self:options(idlpaths)))
end

function Compiler:load(idlspec, idlpaths)
	return self:doresults(parseidl(idlspec, self:options(idlpaths)))
end

return Compiler
