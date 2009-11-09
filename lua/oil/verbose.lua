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

local ObjectCache = require "loop.collection.ObjectCache"
local Viewer      = require "loop.debug.Viewer"
local Verbose     = require "loop.debug.Verbose"
local Inspector   = require "loop.debug.Inspector"

module("oil.verbose", Verbose)

viewer = Viewer{
	maxdepth = 1,
	labels = ObjectCache(),
}
function viewer.labels:retrieve(value)
  local type = type(value)
  local id = rawget(self, type) or 0
  self[type] = id + 1
  local label = {}
  repeat
    label[#label + 1] = string.byte("A") + (id % 26)
    id = math.floor(id / 26)
  until id <= 0
  return string.format("%s:%s", type, string.char(unpack(label)))
end

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

function custom:hexastream(codec)
	local stream = codec:getdata()
	local cursor = codec.cursor
	local base = codec.previousend
	local viewer = self.viewer
	local output = viewer.output
	local lines = string.format("%%0%dx:", math.ceil(math.log10((base+#stream)/16)+1))
	local count = 0
	local text = {}
	for char in stream:gmatch("(.)") do
		column = math.mod(count, 16)
		if column == 0 then
			output:write("\n", lines:format(base+count))
		end
		local hexa
		if count == cursor-1
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
		if column == 15 then
			output:write("  |"..table.concat(text).."|")
			text = {}
		elseif column == 7 then
			output:write("  ")
		end
		count = count + 1
	end
end

--------------------------------------------------------------------------------

_M:flag("debug", true)
_M:flag("print", true)

I = Inspector{ viewer = viewer }
function inspect:debug() self.I:stop(4) end
