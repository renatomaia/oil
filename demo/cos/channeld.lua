#!/usr/bin/env lua
--------------------------------------------------------------------------------
-- @script  OiL Event Channel Daemon
-- @version 1.1
-- @author  Renato Maia <maia@tecgraf.puc-rio.br>
--
print("OiL Event Channel 1.1  Copyright (C) 2006-2008 Tecgraf, PUC-Rio")

local _G = require "_G"
local io = require "io"
local os = require "os"
local oil = require "oil"
local verbose = require "oil.verbose"
local event = require "oil.corba.services.event"
local Arguments = require "loop.compiler.Arguments"

local args = Arguments{
	_optpat = "^%-%-(%w+)(=?)(.-)$",
	_alias = { maxqueue = "oil.cos.event.max_queue_length" },
	verb = 0,
	port = 0,
	ior  = "",
	ir = "",
	ns = "",
	name = "",
}
function args.log(optlist, optname, optvalue)
	local file, errmsg = io.open(optvalue, "w")
	if file
		then verbose:output(file)
		else return errmsg
	end
end
args[args._alias.maxqueue] = 0

local argidx, errmsg = args(...)
if not argidx or argidx <= _G.select("#", ...) then
	if errmsg then io.stderr:write("ERROR: ", errmsg, "\n") end
	io.stderr:write([[
Usage:	channeld.lua [options]
Options:
	--verb <level>
	--log <file>
	--ior <file>
	--port <number>
	--maxqueue <number>
	--ir <objref>
	--ns <objref>
	--name <name>

]])
	os.exit(1)
end

oil.main(function()
	verbose:level(args.verb)
	local orb = (args.port > 0) and oil.init{port=args.port} or oil.init()
	
	if args.ir ~= ""
		then orb:setIR(orb:narrow(orb:newproxy(args.ir)))
		else orb:loadidlfile("CosEvent.idl")
	end
	
	local channel = orb:newservant(event.new(args))
	if args.ior ~= "" then oil.writeto(args.ior, tostring(channel)) end
	
	if args.name ~= "" then
		local ns = args.ns
		if ns ~= ""
			then ns = orb:narrow(orb:newproxy(ns))
			else ns = orb:narrow(orb:newproxy("corbaloc::/NameService"))
		end
		if ns ~= nil then
			ns:rebind({{id=args.name,kind="EventChannel"}}, channel)
		end
	end
	
	orb:run()
end)
