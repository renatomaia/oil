--------------------------------------------------------------------------------
-- Project: Library Generation Utilities                                      --
-- Release: 1.0 alpha                                                         --
-- Title  : Pre-Compiler of Lua Script Files                                  --
-- Author : Renato Maia <maia@inf.puc-rio.br>                                 --
-- Date   : 13/12/2004 13:51                                                  --
--------------------------------------------------------------------------------

local assert   = assert
local loadfile = loadfile
local pairs    = pairs
local select   = select

local io     = require "io"
local os     = require "os"
local string = require "string"

local FILE_SEP = "/"
local FUNC_SEP = "_"
local PACK_SEP = "."
local INIT_PAT = "init$"
local PATH_PAT = FILE_SEP.."$"

module("precompiler", require "loop.compiler.Arguments")

luapath   = "."
directory = "."
filename  = "precompiled"
prefix    = "LUAOPEN_API"

local help = [[
Script for pre-compilation of Lua script files
Copyright (C) 2005-2007 Renato Maia <maia@inf.puc-rio.br>

Usage: lua ]].._NAME..[[.lua [options] <scripts>

Options:

-d, -directory  Directory where the output files should be generated. Its
                default is the current directory.

-f, -filename   Name used to form the name of the files generated. Two files
                are generates: a source code file with the sufix '.c' with
                the pre-compiled scripts and a header file with the sufix
                '.h' with function signatures. Its default is ']]..filename..[['.

-l, -luapath    Root directory of the script files to be compiled.
                The script files must follow the same hierarchy of the
                packages they implement, similarly to the hierarchy imposed
                by the value of the 'package.path' defined in the standard
                Lua distribution. Its default is the current directory.

-p, -prefix     Prefix added to the signature of the functions generated.
                Its default is ']]..prefix..[['.

]]

_alias = {}
for name in pairs(_M) do
	_alias[name:sub(1, 1)] = name
end

local start, errmsg = _M(...)
local finish = select("#", ...)
if not start or start > finish then
	if errmsg then io.stderr:write("ERROR: ", errmsg, "\n") end
	io.stderr:write(help)
	os.exit(1)
end

--------------------------------------------------------------------------------

local function adjustpath(path)
	if path:find(PATH_PAT)
		then return path
		else return path..FILE_SEP
	end
end

local function getname(file)
	local name = file:match("(.+)%..+")
	if name:find(INIT_PAT) then
		name = name:sub(1, -6)
	end
	return name:gsub(FILE_SEP, FUNC_SEP)
end

--------------------------------------------------------------------------------

luapath   = adjustpath(luapath)
directory = adjustpath(directory)
local filepath    = directory..filename

local outc = assert(io.open(filepath..".c", "w"))
local outh = assert(io.open(filepath..".h", "w"))

outh:write([[
#ifndef __]],filename:upper(),[[__
#define __]],filename:upper(),[[__

#include <lua.h>

#ifndef ]],prefix,[[ 
#define ]],prefix,[[ 
#endif

]])

outc:write([[
#include <lua.h>
#include <lauxlib.h>
#include "]],filename,[[.h"

]])

for index = start, finish do local file = select(index, ...)
	local i = index - start
	local bytecodes = string.dump(assert(loadfile(luapath..file)))
	outc:write("static const unsigned char B",i,"[]={\n")
	for j = 1, #bytecodes do
		outc:write(string.format("%3u,", bytecodes:byte(j)))
		if j % 20 == 0 then outc:write("\n") end
	end
	outc:write("\n};\n\n")
end

for index = start, finish do local file = select(index, ...)
	local i = index - start
	local func = getname(file)

	outh:write(prefix," int luaopen_",func,"(lua_State *L);\n")

	outc:write(
prefix,[[ int luaopen_]],func,[[(lua_State *L) {
	int arg = lua_gettop(L);
	luaL_loadbuffer(L,(const char*)B]],i,[[,sizeof(B]],i,[[),"]],file,[[");
	lua_insert(L,1);
	lua_call(L,arg,1);
	return 1;
}
]])

end

outh:write([[

#endif /* __]],filename:upper(),[[__ */
]])

outh:close()
outc:close()
