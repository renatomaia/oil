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
-- Release: 0.3.2 alpha                                                       --
-- Title  : Interface Definition Language (IDL) compiler                      --
-- Authors: Ricardo Cosme         <rcosme@tecgraf.puc-rio.br>                 --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--------------------------------------------------------------------------------

local assert  = assert
local require = require
local ipairs  = ipairs

local table   = require "table"

module("oil.idl.compiler")

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local luaidl         = require "luaidl"
local idl            = require "oil.idl"
local callbacks      = { }
local tab_interfaces = { }

--callbacks.null   = idl.null
callbacks.VOID     = idl.void
callbacks.SHORT    = idl.short
callbacks.LONG     = idl.long
callbacks.USHORT   = idl.ushort
callbacks.ULONG    = idl.ulong
callbacks.FLOAT    = idl.float
callbacks.DOUBLE   = idl.double
callbacks.BOOLEAN  = idl.boolean
callbacks.CHAR     = idl.char
callbacks.OCTET    = idl.OCTET
callbacks.ANY      = idl.any
callbacks.TYPECODE = idl.TypeCode
callbacks.STRING   = idl.string
callbacks.OBJECT   = idl.object
callbacks.interface = function (def)
  if def.definitions then -- not forward declarations
	  def = idl.interface(def)
	  table.insert(tab_interfaces,def)
	end
end
callbacks.operation = idl.operation
callbacks.attribute = idl.attribute
callbacks.module    = idl.module
callbacks.except    = idl.except
callbacks.union     = idl.union
callbacks.struct    = idl.struct
callbacks.enum      = idl.enum
callbacks.typedef   = idl.typedef
callbacks.array     = idl.array
callbacks.sequence  = idl.sequence

local options = { callbacks = callbacks }

function registerAll(manager)
	for _, interface in ipairs(tab_interfaces) do
		manager:putiface(interface)	
	end
	tab_interfaces = { }
end

function parsefile(filename,manager)
	assert(luaidl.parsefile(filename,options))
	registerAll(manager)
end

function parse(idlspec,manager)
	assert(luaidl.parse(idlspec, options))
	registerAll(manager)
end
