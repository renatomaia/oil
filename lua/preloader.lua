#!/usr/local/bin/lua
--------------------------------------------------------------------------------
-- @script  Lua Module Pre-Loader
-- @version 1.1
-- @author  Renato Maia <maia@tecgraf.puc-rio.br>
--

local assert = assert
local ipairs = ipairs
local pairs  = pairs
local select = select
local io     = require "io"
local os     = require "os"

module("preloader", require "loop.compiler.Arguments")

local FILE_SEP = "/"
local FUNC_SEP = "_"
local PACK_SEP = "."
local PATH_PAT = FILE_SEP.."$"
local OPEN_PAT = "int%s+luaopen_([%w_]+)%s*%(%s*lua_State%s*%*[%w_]*%);"

directory = "."
filename  = "preload"
prefix    = "LUAPRELOAD_API"
include   = {}

_alias = { I = "include" }
for name in pairs(_M) do
	_alias[name:sub(1, 1)] = name
end

local start, errmsg = _M(...)
local finish = select("#", ...)
if not start or start > finish then
	if errmsg then io.stderr:write("ERROR: ", errmsg, "\n") end
	io.stderr:write([[
Lua Module Pre-Loader 1.1  Copyright (C) 2006-2007 Tecgraf, PUC-Rio
Usage: ]],_NAME,[[.lua [options] <headers>
Options:
  
  -d, -directory    Directory where the output files should be generated. Its
                    default is the current directory.
  
  -f, -filename     Name used to form the name of the files generated. Two files
                    are generated: a source code file with the sufix '.c' with
                    the pre-loading code and a header file with the suffix '.h'
                    with the function that pre-loads the scripts. Its default is
                    ']],filename,[['.
  
  -i, -I, -include  Adds a directory to the list of paths where the header files
                    of pre-compiled libraries are searched.
  
  -p, -prefix       Prefix added to the signature of the functions generated.
                    Its default is ']],prefix,[['.
  
]])
	os.exit(1)
end

--------------------------------------------------------------------------------

function adjustpath(path)
	if path:find(PATH_PAT)
		then return path
		else return path..FILE_SEP
	end
end

function openfile(name)
	local file, errmsg = io.open(name)
	if not file then
		for _, path in ipairs(include) do
			path = adjustpath(path)
			file, errmsg = io.open(path..name)
			if file then break end
		end
	end
	return file, errmsg
end

--------------------------------------------------------------------------------

directory = adjustpath(directory)
local filepath = directory..filename

--------------------------------------------------------------------------------

local outh = assert(io.open(filepath..".h", "w"))
outh:write([[
#ifndef __]],filename:upper(),[[__
#define __]],filename:upper(),[[__

#ifndef ]],prefix,[[ 
#define ]],prefix,[[ 
#endif

]],prefix,[[ int luapreload_]],filename,[[(lua_State *L);

#endif /* __]],filename:upper(),[[__ */
]])
outh:close()

--------------------------------------------------------------------------------

local outc = assert(io.open(filepath..".c", "w"))
outc:write([[
#include <lua.h>
#include <lauxlib.h>

]])

for i = start, finish do local file = select(i, ...)
	outc:write('#include "',file,'"\n')
end

outc:write([[
#include "]],filename,[[.h"

]],prefix,[[ int luapreload_]],filename,[[(lua_State *L) {
	luaL_findtable(L, LUA_GLOBALSINDEX, "package.preload", ]], finish-start+1, [[);
	
]])

for i = start, finish do local file = select(i, ...)
	local input = assert(openfile(file))
	local header = input:read("*a")
	input:close()
	for func in header:gmatch(OPEN_PAT) do
		local pack = func:gsub(FUNC_SEP, PACK_SEP)
		outc:write([[
	lua_pushcfunction(L, luaopen_]],func,[[);
	lua_setfield(L, -2, "]],pack,[[");
]])
	end
end

outc:write([[
	
	lua_pop(L, 1);
	return 0;
}
]])

outc:close()
