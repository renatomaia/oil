#!/usr/bin/env lua
--------------------------------------------------------------------------------
-- @script  OiL Interface Repository Daemon
-- @version 1.2
-- @author  Renato Maia <maia@tecgraf.puc-rio.br>
--
print("OiL Interface Repository 1.2  Copyright (C) 2005-2008 Tecgraf, PUC-Rio")

local _G = require "_G"
local io = require "io"
local os = require "os"
local oil = require "oil"
local verbose = require "oil.verbose"
local Arguments = require "loop.compiler.Arguments"

local args = Arguments{
	_optpat = "^%-%-(%w+)(=?)(.-)$",
	verb = 0,
	port = 0,
	ior  = "",
}
function args.log(optlist, optname, optvalue)
	local file, errmsg = io.open(optvalue, "w")
	if file
		then verbose:output(file)
		else return errmsg
	end
end

local argidx, errmsg = args(...)
if not argidx then
	io.stderr:write([[
ERROR: ]],errmsg,[[ 
Usage:	ird.lua [options] <idlfiles>
Options:
	--verb <level>
	--log <file>
	--ior <file>
	--port <number>

]])
	os.exit(1)
end

local files = { _G.select(argidx, ...) }
oil.main(function()
	verbose:level(args.verb)
	local orb = (args.port > 0) and oil.init{port=args.port} or oil.init()
	local ir = orb:getLIR()
	if args.ior ~= "" then oil.writeto(args.ior, tostring(ir)) end
	for _, file in _G.ipairs(files) do
		orb:loadidlfile(file)
	end
	orb:run()
end)
