local tostring = tostring
local type     = type

local string = require "string"
local math   = require "math"

local verbose = require "loop.debug.verbose"

oil = oil or {}
oil.verbose = verbose
package.loaded["oil.verbose"] = verbose
setfenv(1, verbose)

Viewer.maxdepth = 2

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--
-- aspect selections
--
addgroup("ir"       , "ir_manager","ir_classes","ir_cache")

addgroup("orb"      , "servant","broker")
addgroup("iiop"     , "open","close","transport")
addgroup("open"     , "connect","listen")
addgroup("transport", "send","receive")
addgroup("cdr"      , "marshall","unmarshall")
addgroup("idl"      , "null","void","short","long","ushort","ulong","float",
                      "double","boolean","char","octet","any","TypeCode",
                      "string","Object","struct","union","enum","sequence",
                      "array","typedef","except","operation")
--
-- architectural levels
--
addgroup(1, "server","client")       -- API level
addgroup(2, "proxy","manager")       -- object level
addgroup(3, "invoke","orb")          -- ORB level
addgroup(4, "iiop","ior","giop")     -- protocol level
addgroup(5, "cdr","tcode")           -- marshalling level
addgroup(6, "idl")                   -- definition level

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function newIDL(kind, name, from, to)
	if Flags[kind] then
		write(kind, {"defining new ", kind, ": ", name,
			from = from,
			to   = to  ,
		})
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
function format_rawdata(rawdata, cursor)
	count = 0
	pos = cursor
	return "\n"..string.gsub(rawdata, "(.)", readable_hexa)
end

function marshallOf(tcode, value, buffer, final)
	if Flags.marshall then
		local formated = ""
		if type(Details) == "table" and Details.marshall or Details == true then
			formated = format_rawdata(buffer:getdata(), buffer.cursor)
		end
		marshall{"marshall of ", tcode._type, " ",
		         tcode.name or tcode.repID,
		         value and " (got "..tostring(value)..")" or "",
		         formated,
			value = value,
			--tcode = tcode,
		}
		if not final then addtab() end
	end
end

function unmarshallOf(tcode, value, buffer, final)
	if Flags.unmarshall then
		local formated = ""
		if type(Details) == "table" and Details.unmarshall or Details == true then
			formated = format_rawdata(buffer:getdata(), buffer.cursor)
		end
		unmarshall{"unmarshall of ", tcode._type, " ",
		           tcode.name or tcode.repID or "",
		           value and " (got "..tostring(value)..")" or "",
		           formated,
			value = value,
			--tcode = tcode,
		}
		if not final then addtab() end
	end
end

--------------------------------------------------------------------------------

local GIOPMessageTypeName = {
	[0] = "Request",
	[1] = "Reply",
	[2] = "CancelRequest",
	[3] = "LocateRequest",
	[4] = "LocateReply",
	[5] = "CloseConnection",
	[6] = "MessageError",
	[7] = "Fragment",
}

function newMsg(message_type, giop_version)
	if Flags.send then
		send({"create GIOP 1.", giop_version, " ",
		      GIOPMessageTypeName[message_type], " message"
		}, true)
	end
end

function newHead(giop, header, body)
	if Flags.send then
		send({"create GIOP ", giop.GIOP_version.major, ".", 
		     giop.GIOP_version.minor, " header for ",
		     GIOPMessageTypeName[giop.message_type],
			giop   = giop,
			header = header,
			body   = body,
		}, true)
	end
end

function gotMsg(magic, version, order, message_type, message_size, stream)
	if Flags.receive then
		removetab()
		receive{"got ", magic or "no message", " ",
		        version and (version.major.."."..version.minor.." ") or " ",
		        GIOPMessageTypeName[message_type],
			order  = (order~=nil) and (order and "little" or "big").."-endian" or nil,
			size   = message_size,
			--stream = stream,
		}
	end
end
