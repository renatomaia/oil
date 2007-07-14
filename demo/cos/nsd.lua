#!/usr/local/bin/lua
print("OiL Naming Service 1.0  Copyright (C) 2006-2007 Tecgraf, PUC-Rio")

local select = select
local io     = require "io"
local os     = require "os"
local oil    = require "oil"
local naming = require "oil.corba.services.naming"

module("oil.corba.services.nsd", require "loop.compiler.Arguments")
_optpat = "^%-%-(%w+)(=?)(.-)$"
verb = 0
port = 0
ior  = ""
ir = ""
function log(optlist, optname, optvalue)
	local file, errmsg = io.open(optvalue, "w")
	if file
		then oil.verbose:output(file)
		else return errmsg
	end
end

local argidx, errmsg = _M(...)
if not argidx or argidx <= select("#", ...) then
	if errmsg then io.stderr:write("ERROR: ", errmsg, "\n") end
	io.stderr:write([[
Usage:	nsd.lua [options]
Options:
	--verb <level>
	--log <file>
	--ior <file>
	--port <number>
	--ir <objref>

]])
	os.exit(1)
end

oil.main(function()
	oil.verbose:level(verb)
	if port > 0 then oil.init{ port = port } end
	if ir ~= ""
		then oil.setIR(oil.narrow(oil.newproxy(ir)))
		else oil.loadidlfile("CosNaming.idl")
	end
	ns = oil.newservant(naming.new())
	if ior ~= "" then oil.writeto(ior, oil.tostring(ns)) end
	oil.run()
end)
