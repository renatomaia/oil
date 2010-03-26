--------------------------------------------------------------------------------
------------------------------  #####      ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------ ##   ## ##  ##     ------------------------------
------------------------------ ##   ##  #  ##     ------------------------------
------------------------------  #####  ### ###### ------------------------------
--------------------------------                --------------------------------
----------------------- An Object Request Broker in Lua ------------------------
--------------------------------------------------------------------------------
-- Project: OiL - ORB in Lua: An Object Request Broker in Lua                 --
-- Release: 0.5                                                              --
-- Title  : Verbose Support                                                   --
-- Authors: Renato Maia <maia@inf.puc-rio.br>                                 --
--------------------------------------------------------------------------------

local rawget = rawget
local type   = type
local unpack = unpack

local math   = require "math"
local string = require "string"
local table  = require "table"
local coroutine  = require "coroutine"

local Viewer      = require "loop.debug.Viewer"
local Verbose     = require "loop.debug.Verbose"
local inspector   = require "inspector"

module("oil.verbose", Verbose)

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
		local lines = string.format("%%0%dx:", math.ceil(math.log10((base+#stream)/16)+1))
		local count = 0
		local text = {}
		for char in stream:gmatch("(.)") do
			column = math.mod(count, 16)
			if column == 0 then
				output:write(lines:format(base+count))
			end
			local hexa
			if cursor[count+1]
				then hexa = "[%02x]"
				else hexa = " %02x "
			end
			output:write(hexa:format(string.byte(char)))
			if char == "\0" then
				text[#text+1] = "?"
			elseif char:match("[%w%p ]") then
				text[#text+1] = char
			else
				text[#text+1] = "."
			end
			count = count + 1
			if count == #stream then
				output:write(string.rep("    ", 15-column))
				text[#text+1] = string.rep(" ", 15-column)
				if column < 8 then output:write("  ") end
				column = 15
			end
			if column == 15 then
				output:write("  |"..table.concat(text).."|\n")
				text = {}
			elseif column == 7 then
				output:write("  ")
			end
		end
	end
end

--------------------------------------------------------------------------------

_M:flag("debug", true)
_M:flag("print", true)

inspector.showsource = true
function pause:debug()
	if coroutine.running() then
		coroutine.yield("inspect")
	else
		inspector.activate(4)
	end
end
