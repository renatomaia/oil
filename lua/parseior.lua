#!/usr/bin/env lua

local oil = require "oil"

orb = oil.init{ flavor = "corba.ssl" }
ref = assert(orb.ObjectReferrer.references:decodestring(io.read()))

local function hexastream(output, stream, prefix)
	local cursor = {}
	local last = #stream
	local opened
	for count = 1, last do
		local base = 0
		local lines = string.format("\n%s%%0%dx: ", prefix or "", math.ceil(math.log((base+last)/16, 10))+1)
		local text = {}
		local opnened
		for count = count-(count-1)%16, last do
			local column = (count-1)%16
			-- write line start if necessary
			if column == 0 then
				output:write(lines:format(base+count-1))
			end
			-- write hexadecimal code
			local code = stream:byte(count, count)
			output:write(string.format(" %02x", code))
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
			if count == last then
				output:write(string.rep("   ", 15-column))
				text[#text+1] = string.rep(" ", 15-column)
				if column < 8 then output:write(" ") end
				column = 15
			end
			-- write ASCII text if last column, or a blank space if middle column
			if column == 15 then
				output:write(" |"..table.concat(text).."|")
				text = {}
			elseif column == 7 then
				output:write(" ")
			end
		end
		break
	end
end

--corbaloc::1.2@10.0.64.144:0/3978213568%2f%00%01%10%01%3e%25%22%16%1f%0a%2b%0a%10%060F8%14%14%1bHL%1b
--corbaloc::1.2@10.0.64.144:0/3978213568 / %00%01%10%01%3e%25%22%16%1f%0a + %0a%10%060F8%14%14%1bHL%1b

local Escaped = "[^ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789%-_%.~]"
local function ecapeurlchar(char)
	return "%"..string.format("%02x", string.byte(char))
end
local function corbaloc(profile)
	return string.format("corbaloc::%d.%d@%s:%s/%s",
		profile.iiop_version.major,
		profile.iiop_version.minor,
		profile.host,
		profile.port,
		profile.object_key:gsub(Escaped, ecapeurlchar))
end

local AssociationOptions = {
	"NoProtection",
	"Integrity",
	"Confidentiality",
	"DetectReplay",
	"DetectMisordering",
	"EstablishTrustInTarget",
	"EstablishTrustInClient",
	"NoDelegation",
	"SimpleDelegation",
	"CompositeDelegation",
}
local function assotiationoptions(value)
	local result = {}
	for index, name in ipairs(AssociationOptions) do
		if bit32.band(value, bit32.lshift(1, index-1)) ~= 0 then
			result[#result+1] = name
		end
	end
	return string.format("(0x%02x) %s", value, table.concat(result, " "))
end

print("Repo Id: "..ref.type_id)
print("Profiles:")
for _, profile in ipairs(ref.profiles) do
	if profile.tag == orb.IIOPProfiler.tag then
		profile = assert(orb.IIOPProfiler.profiler:decode(profile.profile_data))
		print("  IIOP:")
		print("    URI: "..corbaloc(profile))
		print("    Version: "..profile.iiop_version.major.."."..profile.iiop_version.minor)
		print("    Address: inet:"..profile.host..":"..profile.port)
		io.write("    Object Key:")
		hexastream(io.stdout, profile.object_key, "      ")
		print()
		if #profile.components > 0 then
			print("    Components:")
			for _, component in ipairs(profile.components) do
				if component.tag == orb.SSLIOPComponentCodec.tag then
					component = assert(orb.SSLIOPComponentCodec.compcodec:decode(component.component_data, profile))
					print("      SSLIOP:")
					print("        SSL Port: "..profile.ssl.port)
					print("        Supports: "..assotiationoptions(profile.ssl.target_supports))
					print("        Requires: "..assotiationoptions(profile.ssl.target_requires))
				else
					io.write("      Unknown (tag="..component.tag..")")
					hexastream(io.stdout, component.component_data, "        ")
					print()
				end
			end
		end
	else
		io.write("  Unknown (tag="..profile.tag..") ")
		hexastream(io.stdout, profile.profile_data, "    ")
		print()
	end
end
