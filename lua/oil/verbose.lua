local tostring = tostring
local type     = type
local debug_flag = true

local string = require "string"
local math   = require "math"

local Verbose = require "loop.debug.Verbose"
local Inspector = require "loop.debug.Inspector"

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local verbose = Verbose{
	groups = {
		--
		-- aspect selections
		--
		ir        = {"ir_manager","ir_classes","ir_cache"},
		orb       = {"servant","broker"},
		iiop      = {"open","close","transport"},
		open      = {"connect","listen"},
		transport = {"send","receive"},
		cdr       = {"marshal","unmarshal"},
		idl       = {"null","void","short","long","ushort","ulong","float",
		             "double","boolean","char","octet","any","TypeCode",
		             "string","Object","struct","union","enum","sequence",
		             "array","typedef","except","operation"},

		--
		-- architectural levels
		--
		{"server","client","debug"},       -- API level
		{"proxy","manager"},       -- object level
		{"invoke","orb"},          -- ORB level
		{"iiop","ior","giop"},     -- protocol level
		{"cdr","tcode"},           -- marshalling level
		{"idl"},                   -- definition level
	},
}

package.loaded["oil.verbose"] = verbose
oil = oil or {}
oil.verbose = package.loaded["oil.verbose"]

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function verbose.custom:idl(def)
	local viewer  = self.viewer
	local output  = self.viewer.output

	output:write("defining new ", def._type)

	if def.name then output:write(": ", tostring(def.name)) end
	output:write("\ndefinition: ")
	viewer:write(def)
end

function verbose.custom:debug(msg)
	local output  = self.viewer.output
	if not msg then msg = 'nil' end 
	output:write(msg, "\n")
	if debug_flag then
		Inspector:breakpoint(4)
	end
end
--------------------------------------------------------------------------------

local pos
local count
local function readable_hexa(char)
	count = count + 1
	if count == pos
		then format = "[%02x]"
		else format = " %02x "
	end
	column = math.mod(count, 8)
	if column == 0 then
		format = format.."\n"
	elseif column == 1 then
		local cols = count.."-"..(count + 7)
		format = gettabs()..cols..string.rep(" ", 7 - string.len(cols))..format
	end
	return (string.format(format, string.byte(char)))
end
local function format_rawdata(rawdata, cursor)
	count = 0
	pos = cursor
	return string.gsub(rawdata, "(.)", readable_hexa)
end

function verbose.custom:marshal(tcode, value, buffer)
	if type(tcode) == "string" then return true end

	local viewer  = self.viewer
	local output  = self.viewer.output
	local name = tcode.name or tcode.repID

	output:write("marshal of ", tcode._type)
	if name then
		output:write(" ", name)
	end
	if value then
		output:write(" (got ")
		viewer:write(value)
		output:write(")")
	end

	if self.flags.marshalstream then
		output:write("\n", format_rawdata(buffer:getdata(), buffer.cursor))
	end
end

function verbose.custom:unmarshal(tcode, value, buffer)
	if type(tcode) == "string" then return true end

	local viewer  = self.viewer
	local output  = self.viewer.output
	local name = tcode.name or tcode.repID

	output:write("unmarshal of ", tcode._type)
	if name then
		output:write(" ", name)
	end
	if value then
		output:write(" (got ")
		viewer:write(value)
		output:write(")")
	end

	if self.flags.marshalstream then
		output:write("\n", format_rawdata(buffer:getdata(), buffer.cursor))
	end
end
