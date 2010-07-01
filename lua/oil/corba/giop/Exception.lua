local oo = require "oil.oo"
local class = oo.class

local Exception = require "oil.Exception"

local giop = require "oil.corba.giop"                                           --[[VERBOSE]] local verbose = require "oil.verbose"
local SystemExceptionIDs = giop.SystemExceptionIDs

module(...); local _ENV = _M

class(_ENV)

OiLEx2SysEx = {
	badinitialize = "INITIALIZE",
	badsocket     = "NO_RESOURCES",
	badaddress    = "NO_RESOURCES",
	badconnect    = "TRANSIENT",
	badchannel    = "COMM_FAILURE",
	badvalue      = "BAD_PARAM",
	badstream     = "MARSHAL",
	badexception  = "UNKNOWN",
	badmessage    = "INTERNAL",
	badversion    = "IMP_LIMIT",
	badgiopimpl   = "IMP_LIMIT",
	badcorbaloc   = "INV_OBJREF",
	badobjref     = "INV_OBJREF",
	badobjimpl    = "NO_IMPLEMENT",
	badobjop      = "BAD_OPERATION",
	badobjkey     = "OBJECT_NOT_EXIST",
	timeout       = "TIMEOUT",
}

__concat   = Exception.__concat
__tostring = Exception.__tostring

minor = 0
completed = "COMPLETED_MAYBE"

function _ENV:__new(except, ...)
	if except then
		local error = except.error
		local sysex = SystemExceptionIDs[error]
		if sysex then
			except[1] = sysex
		end
	end
	return Exception.__new(self, except, ...)
end

assert.Exception = _M -- use GIOP exception as the default exception
