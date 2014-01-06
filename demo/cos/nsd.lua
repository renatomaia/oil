#!/usr/bin/env lua
--------------------------------------------------------------------------------
-- @script  OiL Naming Service Daemon
-- @version 1.1
-- @author  Renato Maia <maia@tecgraf.puc-rio.br>
--
print("OiL Naming Service 1.1  Copyright (C) 2006-2008 Tecgraf, PUC-Rio")

local _G = require "_G"
local io = require "io"
local os = require "os"
local oil = require "oil"
local verbose = require "oil.verbose"
local naming = require "oil.corba.services.naming"
local Arguments = require "loop.compiler.Arguments"

local args = Arguments{
	_optpat = "^%-%-(%w+)(=?)(.-)$",
	verb = 0,
	port = 0,
	ior  = ",",
	ir = "",
}
function args.log(optlist, optname, optvalue)
	local file, errmsg = io.open(optvalue, "w")
	if file
		then verbose:output(file)
		else return errmsg
	end
end

local argidx, errmsg = args(...)
if not argidx or argidx <= _G.select("#", ...) then
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
	verbose:level(args.verb)
	local orb = (args.port > 0) and oil.init{port=args.port} or oil.init()
	if args.ir ~= ""
		then orb:setIR(orb:narrow(orb:newproxy(args.ir)))
		else orb:loadidlfile("CosNaming.idl")
	end
	local ns = orb:newservant(naming.new())
	if args.ior ~= "" then oil.writeto(args.ior, tostring(ns)) end
end)
