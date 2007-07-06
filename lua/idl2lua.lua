local Options = {
	output = "compiled.lua",
	assembly = "require('oil')"
}

local Alias = {
	o = "output",
	a = "assembly",
}

function processargs(...)
	local i = 1
	local count = select("#", ...)
	while i <= count do
		local arg = select(i, ...)
		local opt = arg:match("^%-(.+)$")
		if not opt then
			return select(i, ...)
		end
		
		opt = Alias[opt] or opt
		local opkind = type(Options[opt])
		if opkind == "boolean" then
			Options[opt] = true
		elseif opkind == "number" then
			i = i + 1
			Options[opt] = tonumber(select(i, ...))
		elseif opkind == "string" then
			i = i + 1
			Options[opt] = select(i, ...)
		elseif opkind == "table" then
			i = i + 1
			table.insert(Options[opt], select(i, ...))
		else
			io.stderr:write("unknown option ", opt)
		end
		i = i + 1
	end
	
	io.stderr:write([[
Script for pre-compilation of IDL files
By Renato Maia <maia@tecgraf.puc-rio.br>

usage: lua idlprecomp.lua [options] <idl>
 
 options:
 
 -o, -output     Output file that should be generated. Its default is
                 'compiled.lua'.
 
 -a, -assembly   ORB assembly the IDL must be loaded to. Its default
                 is 'require("oil")' that denotes the assembly returned
                 by the 'oil' package.
]])
	os.exit(1)
end

--------------------------------------------------------------------------------

local luaidl       = require "luaidl"
local idl          = require "oil.corba.idl"
local Compiler     = require "oil.corba.idl.Compiler"
local StringStream = require "loop.serial.StringStream"

local file = processargs(...)

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
stream:put(luaidl.parsefile(file, Compiler.Options))

local CompiledFile = [=[
local StringStream = require "loop.serial.StringStream"
local stream = StringStream{
	environment = { idl = require "oil.corba.idl" },
	data = [[%s]]
}

local orb = %s
orb.TypeRepository.types:register(stream:get())
]=]

local file = assert(io.open(Options.output, "w"))
file:write(CompiledFile:format(stream:__tostring(), Options.assembly))
file:close()
