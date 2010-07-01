-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.5
-- Title  : Verbose Support
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local rawget = _G.rawget
local type = _G.type
local unpack = _G.unpack

local math = require "math"
local ceil = math.ceil
local log10 = math.log10

local string = require "string"
local format = string.format
local byte = string.byte  
local strrep = string.rep

local table = require "table"
local concat = table.concat

local coroutine = require "coroutine"
local running = coroutine.running
local yield = coroutine.yield

local Viewer = require "loop.debug.Viewer"
local Verbose = require "loop.debug.Verbose"

module(..., Verbose)

viewer = Viewer{ maxdepth = 1 }

function output(self, output)
	self.viewer.output = output
end

groups.broker = { "acceptor", "dispatcher", "servants", "proxies" }
groups.communication = { "mutex", "invoke", "listen", "message", "channels" }
groups.transport = { "marshal", "unmarshal" }
groups.idltypes = { "idl", "repository" }

_M:newlevel{ "broker" }
_M:newlevel{ "invoke", "listen" }
_M:newlevel{ "mutex" }
_M:newlevel{ "message" }
_M:newlevel{ "channels" }
_M:newlevel{ "transport" }
_M:newlevel{ "hexastream" }
_M:newlevel{ "idltypes" }

function _M:hexastream(codec, cursor)
	if self.flags.hexastream then
		local stream = codec:getdata()
		local base = codec.previousend
		local viewer = self.viewer
		local output = viewer.output
		local lines = format("%%0%dx:", ceil(log10((base+#stream)/16)+1))
		local count = 0
		local text = {}
		for char in stream:gmatch("(.)") do
			column = count % 16
			if column == 0 then
				output:write(format(lines, base+count))
			end
			local hexa
			if cursor[count+1]
				then hexa = "[%02x]"
				else hexa = " %02x "
			end
			output:write(format(hexa, byte(char)))
			if char == "\0" then
				text[#text+1] = "?"
			elseif char:match("[%w%p ]") then
				text[#text+1] = char
			else
				text[#text+1] = "."
			end
			count = count + 1
			if count == #stream then
				output:write(strrep("    ", 15-column))
				text[#text+1] = strrep(" ", 15-column)
				if column < 8 then output:write("  ") end
				column = 15
			end
			if column == 15 then
				output:write("  |"..concat(text).."|\n")
				text = {}
			elseif column == 7 then
				output:write("  ")
			end
		end
	end
end

--------------------------------------------------------------------------------

--[[DEBUG]] local inspector = _G.require("inspector")
--[[DEBUG]] local inspect = inspector.activate
--[[DEBUG]] 
--[[DEBUG]] _M:flag("debug", true)
--[[DEBUG]] _M:flag("print", true)
--[[DEBUG]] 
--[[DEBUG]] inspector.showsource = true
--[[DEBUG]] function pause:debug()
--[[DEBUG]] 	if running() then
--[[DEBUG]] 		yield("inspect")
--[[DEBUG]] 	else
--[[DEBUG]] 		inspect(4)
--[[DEBUG]] 	end
--[[DEBUG]] end
