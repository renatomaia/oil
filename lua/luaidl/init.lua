--
-- Project:  LuaIDL
-- Version:  0.5.4b
-- Author:   Ricardo Calheiros <rcosme@tecgraf.puc-rio.br>
-- Last modification: 25/05/2006
-- Filename: init.lua
-- 

local assert  = assert
local error   = error
local pcall   = pcall
local require = require
local type    = type
local unpack  = unpack

local io      = require "io"
local os      = require "os"
local string  = require "string"

module 'luaidl'

local _pre    = require 'luaidl.pre'
local sin     = require 'luaidl.sin'

--- Preprocesses an IDL code. 
-- 
-- @param idl String with IDL code.
-- @param options (optional)Table with preprocessor options, the available keys are:
-- 'incpath', a table with include paths;
-- 'filename', the IDL filename.
-- @return String with the given IDL preprocessed.
function pre( idl, options )
  return _pre.run( idl, options )
end

--- Preprocesses an IDL file.
-- 
-- @param filename The IDL filename.
-- @param options (optional)Table with preprocessor options, the available keys are:
-- 'incpath', a table with include paths.
-- @return String with the given IDL preprocessed.
-- @see pre
function prefile( filename, options )
  local t = type( filename )
  if t ~= 'string' then
    error( string.format( "bad argument #1 to 'prefile' (filename expected, got %s)", t ), 2 )
  end --if
  local fh, msg = io.open( filename )
  if not fh then
    error( msg, 2 )
  end --if
  if not options then
    options = { }
  end --if
  options.filename = filename
  local str = pre( fh:read( '*a' ), options )
  fh:close()
  return str
end

function parseAux( idl, options )
  local callbacks
  if options then
    callbacks = options.callbacks
  end --if
  local status, tab_output = pcall( sin.parse, idl, callbacks )
  if status then
    return unpack( tab_output )
  else
    return nil, tab_output
  end --if
end

--- Parses an IDL code.
-- 
-- @param idl String with IDL code.
-- @param options (optional)Table with parser and preprocessor options, the available keys are:
-- 'callbacks', a table of callback methods;
-- 'incpath', a table with include paths;
-- 'filename',the IDL filename.
-- @return A graph(lua table),
-- that represents an IDL definition in Lua, for each IDL definition found.
function parse(idl, options)
  idl = pre(idl, options)
  return parseAux(idl, options)
end

--- Parses an IDL file.
-- Calls the method 'prefile' with 
-- the given arguments, and so it parses the output of 'prefile'
-- calling the method 'parse'. 
-- @param filename The IDL filename.
-- @param options (optional)Table with parser and preprocessor options, the available keys are:
-- 'callbacks', a table of callback methods;
-- 'incpath', a table with include paths.
-- @return A graph(lua table),
-- that represents an IDL definition in Lua, for each IDL definition found.
-- @see prefile 
-- @see parse
function parsefile( filename, options )
  local t = type( filename )
  if t ~= 'string' then
    error( string.format( "bad argument #1 to 'parsefile' (filename expected, got %s)", t ), 2 )
  end --if
  local stridl = prefile( filename, options )
  return parseAux( stridl, options )
end
