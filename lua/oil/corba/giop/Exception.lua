local oo = require "oil.oo"
local class = oo.class

local assert = require "oil.assert"
local Exception = require "oil.Exception"

local giop = require "oil.corba.giop"                                           --[[VERBOSE]] local verbose = require "oil.verbose"
local SystemExceptionIDs = giop.SystemExceptionIDs

local OiLEx2SysEx = {
	badinitialize = { SystemExceptionIDs.INITIALIZE      ,nil},
	badsocket     = { SystemExceptionIDs.NO_RESOURCES    ,nil},
	badaddress    = { SystemExceptionIDs.NO_RESOURCES    ,nil},
	badconnect    = { SystemExceptionIDs.TRANSIENT       , 2 },
	badchannel    = { SystemExceptionIDs.COMM_FAILURE    ,nil},
	badvalue      = { SystemExceptionIDs.MARSHAL         ,nil},
	badstream     = { SystemExceptionIDs.MARSHAL         ,nil},
	badexception  = { SystemExceptionIDs.UNKNOWN         ,nil},
	badmessage    = { SystemExceptionIDs.INTERNAL        ,nil},
	badversion    = { SystemExceptionIDs.IMP_LIMIT       ,nil},
	badgiopimpl   = { SystemExceptionIDs.IMP_LIMIT       ,nil},
	badcorbaloc   = { SystemExceptionIDs.INV_OBJREF      ,nil},
	badobjref     = { SystemExceptionIDs.INV_OBJREF      ,nil},
	badobjimpl    = { SystemExceptionIDs.NO_IMPLEMENT    ,nil},
	badobjop      = { SystemExceptionIDs.BAD_OPERATION   ,nil},
	badobjkey     = { SystemExceptionIDs.OBJECT_NOT_EXIST,nil},
	terminated    = { SystemExceptionIDs.COMM_FAILURE    ,nil},
	timeout       = { SystemExceptionIDs.TIMEOUT         ,nil},
}

local GIOPException = class({
	"CORBA Exception: $_repid",
	-- default attribute values
	_repid = SystemExceptionIDs.UNKNOWN,
	minor = 0,
	completed = "COMPLETED_MAYBE",
	-- inherited behavior from Exception
	__concat   = Exception.__concat,
	__tostring = Exception.__tostring,
}, Exception)

function GIOPException:__new(except, ...)
	if except then
		local sysex = SystemExceptionIDs[except[1]]
		if sysex ~= nil then
			except._repid = sysex
		else
			local error = except.error
			sysex = OiLEx2SysEx[error] or SystemExceptionIDs[error]
			if sysex ~= nil then
				except._repid = sysex[1]
				except.minor = sysex[2]
			end
		end
	end
	return Exception.__new(self, except, ...)
end

assert.Exception = GIOPException

return GIOPException
