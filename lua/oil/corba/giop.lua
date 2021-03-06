-- Project: OiL - ORB in Lua: An Object Request Broker in Lua
-- Release: 0.6
-- Title  : General Inter-ORB Protocol (GIOP) IDL specifications
-- Authors: Renato Maia <maia@inf.puc-rio.br>
-- Notes  :
--   See in section 15.4 of CORBA 3.0 specification.

local setfenv = _VERSION=="Lua 5.1" and setfenv -- Lua 5.1 compatibility

local idl = require "oil.corba.idl"

local _ENV = {}

if setfenv then setfenv(1,_ENV) end -- Lua 5.1 compatibility

--------------------------------------------------------------------------------
-- Interoperable Object Reference ----------------------------------------------

TaggedProfile = idl.struct{
	{name = "tag"         , type = idl.ulong   },
	{name = "profile_data", type = idl.OctetSeq},
}

IOR = idl.struct{
	{name = "type_id" , type = idl.string                 },
	{name = "profiles", type = idl.sequence{TaggedProfile}},
}

--------------------------------------------------------------------------------
-- Object basic operations -----------------------------------------------------

ObjectOperations = {
	_interface = idl.operation{
		defined_in = idl.object,
		name = "_interface",
		result = idl.Object{
			repID = "IDL:omg.org/CORBA/InterfaceDef:1.0",
			name = "InterfaceDef",
		},
	},
	_component = idl.operation{
		defined_in = idl.object,
		name = "_component",
		result = idl.object,
	},
	_is_a = idl.operation{
		defined_in = idl.object,
		name = "_is_a",
		result = idl.boolean,
		parameters = {{ type = idl.string, name = "interface" }},
	},
	_non_existent = idl.operation{
		defined_in = idl.object,
		name = "_non_existent",
		result = idl.boolean,
	},
	_is_equivalent = idl.operation{
		defined_in = idl.object,
		name = "_is_equivalent",
		parameters = {{ type = idl.object, name = "reference" }},
		result = idl.boolean,
	},
	-- TODO:[maia] add other basic operations
}

--------------------------------------------------------------------------------
-- System Exception Structure --------------------------------------------------

CompletionStatus = idl.enum{
	"COMPLETED_YES",
	"COMPLETED_NO",
	"COMPLETED_MAYBE",
}
SystemExceptionIDL = idl.struct{
	{name = "minor"    , type = idl.ulong },
	{name = "completed", type = CompletionStatus },
}

SystemExceptionIDs = {
	UNKNOWN                 = "IDL:omg.org/CORBA/UNKNOWN:1.0"                , -- the unknown exception
	BAD_PARAM               = "IDL:omg.org/CORBA/BAD_PARAM:1.0"              , -- an invalid parameter was passed
	NO_MEMORY               = "IDL:omg.org/CORBA/NO_MEMORY:1.0"              , -- dynamic memory allocation failure
	IMP_LIMIT               = "IDL:omg.org/CORBA/IMP_LIMIT:1.0"              , -- violated implementation limit
	COMM_FAILURE            = "IDL:omg.org/CORBA/COMM_FAILURE:1.0"           , -- communication failure
	INV_OBJREF              = "IDL:omg.org/CORBA/INV_OBJREF:1.0"             , -- invalid object reference
	NO_PERMISSION           = "IDL:omg.org/CORBA/NO_PERMISSION:1.0"          , -- no permission for attempted op.
	INTERNAL                = "IDL:omg.org/CORBA/INTERNAL:1.0"               , -- ORB internal error
	MARSHAL                 = "IDL:omg.org/CORBA/MARSHAL:1.0"                , -- error marshaling param/result
	INITIALIZE              = "IDL:omg.org/CORBA/INITIALIZE:1.0"             , -- ORB initialization failure
	NO_IMPLEMENT            = "IDL:omg.org/CORBA/NO_IMPLEMENT:1.0"           , -- operation implementation unavailable
	BAD_TYPECODE            = "IDL:omg.org/CORBA/BAD_TYPECODE:1.0"           , -- bad typecode
	BAD_OPERATION           = "IDL:omg.org/CORBA/BAD_OPERATION:1.0"          , -- invalid operation
	NO_RESOURCES            = "IDL:omg.org/CORBA/NO_RESOURCES:1.0"           , -- insufficient resources for req.
	NO_RESPONSE             = "IDL:omg.org/CORBA/NO_RESPONSE:1.0"            , -- response to req. not yet available
	PERSIST_STORE           = "IDL:omg.org/CORBA/PERSIST_STORE:1.0"          , -- persistent storage failure
	BAD_INV_ORDER           = "IDL:omg.org/CORBA/BAD_INV_ORDER:1.0"          , -- routine invocations out of order
	TRANSIENT               = "IDL:omg.org/CORBA/TRANSIENT:1.0"              , -- transient failure - reissue request
	FREE_MEM                = "IDL:omg.org/CORBA/FREE_MEM:1.0"               , -- cannot free memory
	INV_IDENT               = "IDL:omg.org/CORBA/INV_IDENT:1.0"              , -- invalid identifier syntax
	INV_FLAG                = "IDL:omg.org/CORBA/INV_FLAG:1.0"               , -- invalid flag was specified
	INTF_REPOS              = "IDL:omg.org/CORBA/INTF_REPOS:1.0"             , -- error accessing interface repository
	BAD_CONTEXT             = "IDL:omg.org/CORBA/BAD_CONTEXT:1.0"            , -- error processing context object
	OBJ_ADAPTER             = "IDL:omg.org/CORBA/OBJ_ADAPTER:1.0"            , -- failure detected by object adapter
	DATA_CONVERSION         = "IDL:omg.org/CORBA/DATA_CONVERSION:1.0"        , -- data conversion error
	OBJECT_NOT_EXIST        = "IDL:omg.org/CORBA/OBJECT_NOT_EXIST:1.0"       , -- non-existent object, delete reference
	TRANSACTION_REQUIRED    = "IDL:omg.org/CORBA/TRANSACTION_REQUIRED:1.0"   , -- transaction required
	TRANSACTION_ROLLEDBACK  = "IDL:omg.org/CORBA/TRANSACTION_ROLLEDBACK:1.0" , -- transaction rolled back
	INVALID_TRANSACTION     = "IDL:omg.org/CORBA/INVALID_TRANSACTION:1.0"    , -- invalid transaction
	INV_POLICY              = "IDL:omg.org/CORBA/INV_POLICY:1.0"             , -- invalid policy
	CODESET_INCOMPATIBLE    = "IDL:omg.org/CORBA/CODESET_INCOMPATIBLE:1.0"   , -- incompatible code set
	REBIND                  = "IDL:omg.org/CORBA/REBIND:1.0"                 , -- rebind needed
	TIMEOUT                 = "IDL:omg.org/CORBA/TIMEOUT:1.0"                , -- operation timed out
	TRANSACTION_UNAVAILABLE = "IDL:omg.org/CORBA/TRANSACTION_UNAVAILABLE:1.0", -- no transaction
	TRANSACTION_MODE        = "IDL:omg.org/CORBA/TRANSACTION_MODE:1.0"       , -- invalid transaction mode
	BAD_QOS                 = "IDL:omg.org/CORBA/BAD_QOS:1.0"                , -- bad quality of service
	INVALID_ACTIVITY        = "IDL:omg.org/CORBA/INVALID_ACTIVITY:1.0"       , -- bad quality of service
	ACTIVITY_COMPLETED      = "IDL:omg.org/CORBA/ACTIVITY_COMPLETED:1.0"     , -- bad quality of service
	ACTIVITY_REQUIRED       = "IDL:omg.org/CORBA/ACTIVITY_REQUIRED:1.0"      , -- bad quality of service
}

--------------------------------------------------------------------------------
-- Message Header Commom to All GIOP Messages ----------------------------------

HeaderSize = 12               -- TODO:[maia] Calculate from IDL specification
MagicTag = "\071\073\079\080" -- "GIOP" encoded in ISO Latin-1 (8859.1)

Magicn = idl.array{idl.char; length = 4}

Header_v1_ = { -- Common message header for each GIOP version
	[0] = idl.struct{ -- GIOP 1.0
		{name = "magic"       , type = Magicn     },
		{name = "GIOP_version", type = idl.Version},
		{name = "byte_order"  , type = idl.boolean},
		{name = "message_type", type = idl.octet  },
		{name = "message_size", type = idl.ulong  },
	},
	[1] = idl.struct{ -- GIOP 1.1
		{name = "magic"       , type = Magicn     },
		{name = "GIOP_version", type = idl.Version},
		{name = "flags"       , type = idl.octet  }, -- changed field
		{name = "message_type", type = idl.octet  },
		{name = "message_size", type = idl.ulong  },
	},
}
Header_v1_[2] = Header_v1_[1] -- GIOP 1.2, same as GIOP 1.1
Header_v1_[3] = Header_v1_[2] -- GIOP 1.3, same as GIOP 1.2

--------------------------------------------------------------------------------
-- Message Header of GIOP Messages ---------------------------------------------

RequestID         = 0
ReplyID           = 1
CancelRequestID   = 2
LocateRequestID   = 3
LocateReplyID     = 4
CloseConnectionID = 5
MessageErrorID    = 6
FragmentID        = 7

--------------------------------------------------------------------------------

MessageType = {
	[RequestID        ] = "Request"        ,
	[ReplyID          ] = "Reply"          ,
	[CancelRequestID  ] = "CancelRequest"  ,
	[LocateRequestID  ] = "LocateRequest"  ,
	[LocateReplyID    ] = "LocateReply"    ,
	[CloseConnectionID] = "CloseConnection",
	[MessageErrorID   ] = "MessageError"   ,
	[FragmentID       ] = "Fragment"       ,
}

--------------------------------------------------------------------------------

local ServiceContextList = idl.sequence{idl.struct{
	{name = "context_id"  , type = idl.ulong   },
	{name = "context_data", type = idl.OctetSeq},
}}

MessageHeader_v1_ = {} -- Message headers for each GIOP version

--------------------------------------------------------------------------------

local ReplyStatusType_1_0 = idl.enum{
	"NO_EXCEPTION", "USER_EXCEPTION", "SYSTEM_EXCEPTION", "LOCATION_FORWARD",
}
local LocateStatusType_1_0 = idl.enum{
	"UNKNOWN_OBJECT", "OBJECT_HERE", "OBJECT_FORWARD",
}

MessageHeader_v1_[0] = { -- GIOP 1.0
	[RequestID] = idl.struct{
		{name = "service_context"     , type = ServiceContextList},
		{name = "request_id"          , type = idl.ulong         },
		{name = "response_expected"   , type = idl.boolean       },
		{name = "object_key"          , type = idl.OctetSeq      },
		{name = "operation"           , type = idl.string        },
		{name = "requesting_principal", type = idl.OctetSeq      },
	},
	[ReplyID] = idl.struct{
		{name = "service_context", type = ServiceContextList },
		{name = "request_id"     , type = idl.ulong          },
		{name = "reply_status"   , type = ReplyStatusType_1_0},
	},
	[CancelRequestID] = idl.struct{
		{name = "request_id", type = idl.ulong},
	},
	[LocateRequestID] = idl.struct{
		{name = "request_id", type = idl.ulong   },
		{name = "object_key", type = idl.OctetSeq},
	},
	[LocateReplyID] = idl.struct{
		{name = "request_id"   , type = idl.ulong           },
		{name = "locate_status", type = LocateStatusType_1_0},
	},
	[CloseConnectionID] = false, -- empty header
	[MessageErrorID   ] = false, -- empty header
}

--------------------------------------------------------------------------------

local RequestReserved = idl.array{idl.octet; length = 3}

MessageHeader_v1_[1] = { -- GIOP 1.1
	[RequestID] = idl.struct{
		{name = "service_context"     , type = ServiceContextList},
		{name = "request_id"          , type = idl.ulong         },
		{name = "response_expected"   , type = idl.boolean       },
		{name = "reserved"            , type = RequestReserved   }, -- added field
		{name = "object_key"          , type = idl.OctetSeq      },
		{name = "operation"           , type = idl.string        },
		{name = "requesting_principal", type = idl.OctetSeq      },
	},
	[ReplyID          ] = MessageHeader_v1_[0][ReplyID          ],
	[CancelRequestID  ] = MessageHeader_v1_[0][CancelRequestID  ],
	[LocateRequestID  ] = MessageHeader_v1_[0][LocateRequestID  ],
	[LocateReplyID    ] = MessageHeader_v1_[0][LocateReplyID    ],
	[CloseConnectionID] = MessageHeader_v1_[0][CloseConnectionID],
	[MessageErrorID   ] = MessageHeader_v1_[0][MessageErrorID   ],
	[FragmentID       ] = false, -- empty header, introduced in GIOP 1.1
}

--------------------------------------------------------------------------------

local ReplyStatusType_1_2 = idl.enum{
	"NO_EXCEPTION", "USER_EXCEPTION", "SYSTEM_EXCEPTION", "LOCATION_FORWARD",
	"LOCATION_FORWARD_PERM", "NEEDS_ADDRESSING_MODE", -- added values
}
local LocateStatusType_1_2 = idl.enum{
	"UNKNOWN_OBJECT", "OBJECT_HERE", "OBJECT_FORWARD",
	"OBJECT_FORWARD_PERM", "LOC_SYSTEM_EXCEPTION", "LOC_NEEDS_ADDRESSING_MODE",
}
AddressingDisposition = idl.short
KeyAddr = 0
ProfileAddr = 1
ReferenceAddr = 2

local IORAddressingInfo = idl.struct{
	{type = idl.ulong, name = "selected_profile_index"},
	{type = IOR      , name = "ior"                   },
}
local TargetAddress = idl.union{
	switch = AddressingDisposition,
	options = {
		{label = 0, name = "object_key", type = idl.OctetSeq     },
		{label = 1, name = "profile"   , type = TaggedProfile    },
		{label = 2, name = "ior"       , type = IORAddressingInfo},
	}
}

MessageHeader_v1_[2] = { -- GIOP 1.2
	[RequestID] = idl.struct{
		{name = "request_id"     , type = idl.ulong         },
		{name = "response_flags" , type = idl.octet         }, -- changed field
		{name = "reserved"       , type = RequestReserved   },
		{name = "target"         , type = TargetAddress     }, -- changed field
		{name = "operation"      , type = idl.string        },
		{name = "service_context", type = ServiceContextList}, -- was first field
		-- no more field 'requesting_principal'
	},
	[ReplyID] = idl.struct{
		{name = "request_id"     , type = idl.ulong          },
		{name = "reply_status"   , type = ReplyStatusType_1_2}, -- changed field
		{name = "service_context", type = ServiceContextList }, -- was first field
	},
	[CancelRequestID] = MessageHeader_v1_[1][CancelRequestID],
	[LocateRequestID] = idl.struct{
		{name = "request_id", type = idl.ulong    },
		{name = "target"    , type = TargetAddress}, -- changed field
	},
	[LocateReplyID] = idl.struct{
		{name = "request_id"   , type = idl.ulong           },
		{name = "locate_status", type = LocateStatusType_1_2}, -- changed field
	},
	[CloseConnectionID] = MessageHeader_v1_[1][CloseConnectionID],
	[MessageErrorID   ] = MessageHeader_v1_[1][MessageErrorID   ],
	[FragmentID       ] = idl.struct{
		{name = "request_id", type = idl.ulong}, -- added field
	},
}

--------------------------------------------------------------------------------

MessageHeader_v1_[3] = MessageHeader_v1_[2] -- GIOP 1.3, same as GIOP 1.2

--------------------------------------------------------------------------------

return _ENV
