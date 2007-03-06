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
-- Release: 0.4                                                               --
-- Title  : Interface Definition Language (IDL) compiler                      --
-- Authors: Renato Maia   <maia@inf.puc-rio.br>                               --
--          Ricardo Cosme <rcosme@tecgraf.puc-rio.br>                         --
--------------------------------------------------------------------------------
-- compiler:Facet
-- 	success:boolean, [except:table] load(idl:string)
-- 	success:boolean, [except:table] loadfile(filepath:string)
-- 
-- types:Receptacle
-- 	types:table register(definition:table)
--------------------------------------------------------------------------------

local select = select
local unpack = unpack

local luaidl = require "luaidl"

local oo  = require "oil.oo"
local idl = require "oil.corba.idl"                                             --[[VERBOSE]] local verbose = require "oil.verbose"

module("oil.corba.idl.Compiler", oo.class)

context = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local Options = {
	callbacks = {
	--null      = idl.null,
		VOID      = idl.void,
		SHORT     = idl.short,
		LONG      = idl.long,
		USHORT    = idl.ushort,
		ULONG     = idl.ulong,
		FLOAT     = idl.float,
		DOUBLE    = idl.double,
		BOOLEAN   = idl.boolean,
		CHAR      = idl.char,
		OCTET     = idl.octet,
		ANY       = idl.any,
		TYPECODE  = idl.TypeCode,
		STRING    = idl.string,
		OBJECT    = idl.object,
		operation = idl.operation,
		attribute = idl.attribute,
		module    = idl.module,
		except    = idl.except,
		union     = idl.union,
		struct    = idl.struct,
		enum      = idl.enum,
		typedef   = idl.typedef,
		array     = idl.array,
		sequence  = idl.sequence,
	},
}
function Options.callbacks.interface(def)
	if def.definitions then -- not forward declarations
		idl.interface(def)
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function doresults(self, ...)
	if ... then
		return self.context.types:register(...)
	end
	return ...
end

function loadfile(self, filepath)
	return self:doresults(luaidl.parsefile(filepath, Options))
end

function load(self, idlspec)
	return self:doresults(luaidl.parse(idlspec, Options))
end
