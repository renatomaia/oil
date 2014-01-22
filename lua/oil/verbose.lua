-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.6
-- Title  : Verbose Support
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"
local rawget = _G.rawget
local type = _G.type

local math = require "math"
local ceil = math.ceil
local log10 = math.log10

local string = require "string"
local format = string.format
local byte = string.byte  
local strrep = string.rep

local array = require "table"
local concat = array.concat
local unpack = array.unpack

local coroutine = require "coroutine"
local running = coroutine.running
local yield = coroutine.yield

local Viewer = require "loop.debug.Viewer"
local Verbose = require "loop.debug.Verbose"

local verbose = Verbose{
	viewer = Viewer{
		maxdepth = 1,
		metaonly = true,
	},
	groups = {
		broker = { "acceptor", "dispatcher", "servants", "proxies" },
		communication = { "invoke", "listen", "message", "channels" },
		encoding = { "marshal", "unmarshal" },
		idltypes = { "idl", "repository" },
	},
}

function verbose:output(output)
	self.viewer.output = output
end

verbose:newlevel{ "broker" }
verbose:newlevel{ "interceptors" }
verbose:newlevel{ "invoke", "listen" }
verbose:newlevel{ "channels" }
verbose:newlevel{ "message" }
verbose:newlevel{ "references","encoding" }
verbose:newlevel{ "hexastream" }
verbose:newlevel{ "idltypes" }

function verbose:hexastream(codec, cursor, prefix)
	if self.flags.hexastream then
		local stream = codec:getdata()
		if prefix then stream = string.rep("\0", prefix)..stream end
		local last = #stream
		local opened
		for count = 1, last do
			if cursor[count] ~= nil then
				for count = last, count, -1 do
					if cursor[count] == false then
						last = math.min(last, 16*math.ceil(count/16))
						break
					end
				end
				local base = codec.previousend
				local output = self.viewer.output
				local lines = string.format("\n%%0%dx:", math.ceil(math.log10((base+last)/16))+1)
				local text = {}
				local opnened
				for count = count-(count-1)%16, last do
					local column = (count-1)%16
					-- write line start if necessary
					if column == 0 then
						output:write(lines:format(base+count-1))
					end
					-- write hexadecimal code
					local hexa
					local kind = cursor[count]
					if kind == nil then
						hexa = " %02x "
					elseif kind == true then
						opened = true
						hexa = "[%02x "
					elseif opened then
						opened = nil
						hexa = " %02x]"
					else
						hexa = "[%02x]"
					end
					local code = stream:byte(count, count)
					output:write(hexa:format(code))
					if code == 0 then
						text[#text+1] = "."
					elseif code == 255 then
						text[#text+1] = "#"
					elseif stream:match("^[%w%p ]", count) then
						text[#text+1] = stream:sub(count, count)
					else
						text[#text+1] = "?"
					end
					-- write blank if reached the end of the stream
					if count == last or cursor[count+1] == "end" then
						output:write(string.rep("    ", 15-column))
						text[#text+1] = string.rep(" ", 15-column)
						if column < 8 then output:write("  ") end
						column = 15
					end
					-- write ASCII text if last column, or a blank space if middle column
					if column == 15 then
						output:write("  |"..concat(text).."|")
						text = {}
					elseif column == 7 then
						output:write("  ")
					end
					if cursor[count+1] == "end" then break end
				end
				break
			end
		end
	end
end

--------------------------------------------------------------------------------

-- [[DEBUG]] local inspector = _G.require("inspector")
-- [[DEBUG]] local inspect = inspector.activate
-- [[DEBUG]] 
-- [[DEBUG]] verbose:flag("debug", true)
--[[DEBUG]] verbose:flag("print", true)
-- [[DEBUG]] 
-- [[DEBUG]] inspector.showsource = true
-- [[DEBUG]] function verbose.pause:debug()
-- [[DEBUG]] 	if running() then
-- [[DEBUG]] 		yield("inspect")
-- [[DEBUG]] 	else
-- [[DEBUG]] 		inspect(4)
-- [[DEBUG]] 	end
-- [[DEBUG]] end

return verbose
