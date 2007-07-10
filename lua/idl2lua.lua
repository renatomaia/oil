--------------------------------------------------------------------------------
-- Project: Library Generation Utilities                                      --
-- Release: 1.0 alpha                                                         --
-- Title  : Serializer of IDL Descriptions into Lua Scripts                   --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                 --
-- Date   : 2007-07-10                                                        --
--------------------------------------------------------------------------------

local assert  = assert
local pairs   = pairs
local select  = select

local io     = require "io"
local os     = require "os"
local string = require "string"

local luaidl       = require "luaidl"
local idl          = require "oil.corba.idl"
local Compiler     = require "oil.corba.idl.Compiler"
local StringStream = require "loop.serial.StringStream"

module("idl2lua", require "loop.compiler.Arguments")

output   = "idl.lua"
instance = "require('oil')"

local help = [[
Script for serialization of IDL files into Lua scripts.
Copyright (C) 2007 Renato Maia <maia@inf.puc-rio.br>

Usage: lua ]].._NAME..[[.lua [options] <idlfile>
 
 Options:
 
 -o, -output     Output file that should be generated. Its default is
                 ']],output,[['.
 
 -i, -instance   ORB instance the IDL must be loaded to. Its default
                 is ']],instance,[[' that denotes the instance returned
                 by the 'oil' package.
]]

_alias = {}
for name in pairs(_M) do
	_alias[name:sub(1, 1)] = name
end

local start, errmsg = _M(...)
local finish = select("#", ...)
if not start or start ~= finish then
	if errmsg then io.stderr:write("ERROR: ", errmsg, "\n") end
	io.stderr:write(help)
	os.exit(1)
end
local idlfile = select(start, ...)
--------------------------------------------------------------------------------

local stream = StringStream()
stream[idl]              = "idl"
stream[idl.void]         = "idl.void"
stream[idl.short]        = "idl.short"
stream[idl.long]         = "idl.long"
stream[idl.longlong]     = "idl.longlong"
stream[idl.ushort]       = "idl.ushort"
stream[idl.ulong]        = "idl.ulong"
stream[idl.ulonglong]    = "idl.ulonglong,"
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
stream:put(luaidl.parsefile(idlfile, Compiler.Options))

local file = assert(io.open(output, "w"))
file:write(
instance,[[.TypeRepository.types:register(
	setfenv(
		function()
			return ]],stream:__tostring(),[[ 
		end,
		{
			idl = require "oil.corba.idl",
			]],stream.namespace,[[ = require("loop.serial.Serializer")(),
		}
	)()
)
]])
file:close()
