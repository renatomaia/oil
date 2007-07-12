#!/usr/local/bin/lua
print("OiL Interface Repository 2.0  Copyright (C) 2005-2007 Tecgraf, PUC-Rio")

local ipairs = ipairs
local select = select
local io     = require "io"
local os     = require "os"
local oil    = require "oil"

module("oil.corba.services.ird", require "loop.compiler.Arguments")
_optpat = "^%-%-(%w+)(=?)(.-)$"
verb = 0
port = 0
ior  = ""
function log(optlist, optname, optvalue)
	local file, errmsg = io.open(optvalue, "w")
	if file
		then oil.verbose:output(file)
		else return errmsg
	end
end

local argidx, errmsg = _M(...)
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

local files = { select(argidx, ...) }
oil.main(function()
	oil.verbose:level(verb)
	if port > 0 then oil.init{ port = port } end
	local ir = oil.getLIR()
	if ior ~= "" then oil.writeto(ior, oil.tostring(ir)) end
	for _, file in ipairs(files) do
		oil.loadidlfile(file)
	end
	oil.run()
end)
