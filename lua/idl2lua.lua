#!/usr/bin/env lua
--------------------------------------------------------------------------------
-- @script  IDL Descriptor Pre-Loader
-- @version 1.0
-- @author  Renato Maia <maia@tecgraf.puc-rio.br>

local _G = require "_G"
local arg = _G.arg
local assert = _G.assert
local ipairs = _G.ipairs
local pairs = _G.pairs
local select = _G.select

local array = require "table"
local concat = array.concat

local io = require "io"
local stderr = io.stderr
local open = io.open

local os = require "os"
local exit = os.exit

local string = require "string"

local luaidl = require "luaidl"
local parsefile = luaidl.parsefile

local Arguments = require "loop.compiler.Arguments"
local Serializer = require "loop.serial.Serializer"

local idl = require "oil.corba.idl"
local Compiler = require "oil.corba.idl.Compiler"

local _ENV = Arguments{
	output  = "idl.lua",
	include = {},
}
_G.pcall(_G.setfenv, 2, _ENV) -- Lua 5.1 compatbility

_alias = { I = "include" }
for name in pairs(_M) do
	_alias[name:sub(1, 1)] = name
end

local start, errmsg = _ENV(...)
local finish = select("#", ...)

if not start or start ~= finish then
	if errmsg then stderr:write("ERROR: ", errmsg, "\n") end
	stderr:write([[
IDL Descriptor Pre-Parser 1.1  Copyright (C) 2006-2008 Tecgraf, PUC-Rio
Usage: ]]..arg[0]..[[.lua [options] <idlfile>
Options:
  
  -o, -output       Output file that should be generated. Its default is
                    ']],output,[['.
  
  -I, i, -include   Adds a directory to the list of paths where the IDL files
                    are searched.

]])
	exit(1)
end

--------------------------------------------------------------------------------

local file = assert(open(output, "w"))

local stream = Serializer{ ["function"] = false, varprefix = "local " }
function stream:write(...)
	return file:write(...)
end

stream[idl]              = "idl"
stream[idl.void]         = "idl.void"
stream[idl.short]        = "idl.short"
stream[idl.long]         = "idl.long"
stream[idl.longlong]     = "idl.longlong"
stream[idl.ushort]       = "idl.ushort"
stream[idl.ulong]        = "idl.ulong"
stream[idl.ulonglong]    = "idl.ulonglong"
stream[idl.float]        = "idl.float"
stream[idl.double]       = "idl.double"
stream[idl.longdouble]   = "idl.longdouble"
stream[idl.boolean]      = "idl.boolean"
stream[idl.char]         = "idl.char"
stream[idl.octet]        = "idl.octet"
stream[idl.any]          = "idl.any"
stream[idl.TypeCode]     = "idl.TypeCode"
stream[idl.string]       = "idl.string"
stream[idl.object]       = "idl.object"
stream[idl.basesof]      = "idl.basesof"
stream[idl.Contents]     = "idl.Contents"
stream[idl.ContainerKey] = "idl.ContainerKey"

local compiler = Compiler()
local options = compiler.defaults
options.incpath = include
local values = { assert(parsefile(select(start, ...), options)) }

file:write([[
local _G = require "_G"
local _ENV = {
	idl = require "oil.corba.idl",
	setmetatable = _G.setmetatable,
}
_G.pcall(_G.setfenv, 2, _ENV) -- Lua 5.1 compatibility
]])
for i, value in ipairs(values) do
	values[i] = stream:serialize(value)
end
file:write([[
return ]],concat(values, ", "),[[
]])
file:close()
