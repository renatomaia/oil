-- $Id$
--******************************************************************************
-- Copyright 2002 Noemi Rodriquez & Roberto Ierusalimschy. All rights reserved. 
--******************************************************************************

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
-- Release: 0.3 alpha                                                         --
-- Title  : General Inter-ORB Protocol (GIOP) IDL specifications              --
-- Authors: Noemi Rodriquez       <noemi@inf.puc-rio.br>                      --
--          Roberto Ierusalimschy <roberto@inf.puc-rio.br>                    --
--          Renato Cerqueira      <rcerq@inf.puc-rio.br>                      --
--          Pedro Miller          <miller@inf.puc-rio.br>                     --
--          Reinaldo Mello        <rmello@inf.puc-rio.br>                     --
--          Luiz Nogara           <nogara@inf.puc-rio.br>                     --
--          Renato Maia           <maia@inf.puc-rio.br>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   IOR               Interoperable Object Reference (IOR) specification     --
--   TaggedProfile     IOR Tagged Profile specification                       --
--   GIOPHeaderSize    Size of messages common header                         --
--   GIOPMagicTag      Magic tag that identify message boudaries              --
--   GIOPHeader_v1_    Messages common header for each minor version          --
--                                                                            --
--   MessageHeader_v1_ Message headers for each minor version                 --
--   MessageType       Maps of message tags into its name                     --
--                                                                            --
--   RequestID         Tag of GIOP request message                            --
--   ReplyID           Tag of GIOP reply message                              --
--   CancelRequestID   Tag of GIOP cancel request message                     --
--   LocateRequestID   Tag of GIOP locate request message                     --
--   LocateReplyID     Tag of GIOP locate reply message                       --
--   CloseConnectionID Tag of GIOP close connection message                   --
--   MessageErrorID    Tag of GIOP message error message                      --
--   FragmentID        Tag of GIOP fragment message                           --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--   See in section 15.4 of CORBA 3.0 specification.                          --
--------------------------------------------------------------------------------

local require = require

module "oil.giop"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local IDL = require "oil.idl"

--------------------------------------------------------------------------------
-- List of supported protocols -------------------------------------------------

Protocols = {}

--------------------------------------------------------------------------------
-- Interoperable Object Reference ----------------------------------------------

TaggedProfile = IDL.struct{
	{name = "tag"         , type = IDL.ulong   },
	{name = "profile_data", type = IDL.OctetSeq},
}
                  -- underscore character allows using IOR as proxy objects
IOR = IDL.struct{ -- because it avoids name clashes with object members.
	{name = "_type_id" , type = IDL.string                 },
	{name = "_profiles", type = IDL.sequence{TaggedProfile}},
}

--------------------------------------------------------------------------------
-- Object basic operations -----------------------------------------------------

ObjectOperations = {
	_interface = IDL.operation{
		name = "_interface",
		result = IDL.Object("IDL:omg.org/CORBA/InterfaceDef:1.0"),
	},
	_component = IDL.operation{
		name = "_component",
		result = IDL.Object("IDL:omg.org/CORBA/Object:1.0"),
	},
	_is_a = IDL.operation{
		name = "_is_a",
		result = IDL.boolean,
		parameters = {{ type = IDL.string, name = "interface" }},
	},
	_non_existent = IDL.operation{
		name = "_non_existent",
		result = IDL.boolean,
	},
	-- TODO:[maia] add other basic operations
}

--------------------------------------------------------------------------------
-- System Exception Structure --------------------------------------------------

SystemExceptionIDL = IDL.struct{
	{name = "exception_id"     , type = IDL.string},
	{name = "minor_code_value" , type = IDL.ulong },
	{name = "completion_status", type = IDL.ulong },
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

GIOPHeaderSize = 12   -- TODO:[maia] Calculate from IDL specification
GIOPMagicTag = "GIOP" -- TODO:[maia] Garantee that the string "GIOP" is
                      --             encoded in ISO Latin-1 (8859.1).
                      --             How can I do this in Lua?!

GIOPHeader_v1_ = { -- Common message header for each GIOP version
	[0] = IDL.struct{ -- GIOP 1.0
		{name = "magic"       , type = IDL.array{IDL.char; length = 4}},
		{name = "GIOP_version", type = IDL.Version                    },
		{name = "byte_order"  , type = IDL.boolean                    },
		{name = "message_type", type = IDL.octet                      },
		{name = "message_size", type = IDL.ulong                      },
	},
	[1] = IDL.struct{ -- GIOP 1.1
		{name = "magic"       , type = IDL.array{IDL.char; length = 4}},
		{name = "GIOP_version", type = IDL.Version                    },
		{name = "flags"       , type = IDL.octet                      },
		{name = "message_type", type = IDL.octet                      },
		{name = "message_size", type = IDL.ulong                      },
	},
}
GIOPHeader_v1_[2] = GIOPHeader_v1_[1] -- GIOP 1.2, same as GIOP 1.1
GIOPHeader_v1_[3] = GIOPHeader_v1_[1] -- GIOP 1.3, same as GIOP 1.1

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

local ServiceContextList = IDL.sequence{IDL.struct{
	{name = "context_id"  , type = IDL.ulong   },
	{name = "context_data", type = IDL.OctetSeq},
}}

MessageHeader_v1_ = {} -- Message headers for each GIOP version

--------------------------------------------------------------------------------

local ReplyStatusType_1_0 = IDL.enum{
	"NO_EXCEPTION", "USER_EXCEPTION", "SYSTEM_EXCEPTION", "LOCATION_FORWARD",
}
local LocateStatusType_1_0 = IDL.enum{
	"UNKNOWN_OBJECT", "OBJECT_HERE", "OBJECT_FORWARD",
}

MessageHeader_v1_[0] = { -- GIOP 1.0
	[RequestID] = IDL.struct{
		{name = "service_context"     , type = ServiceContextList},
		{name = "request_id"          , type = IDL.ulong         },
		{name = "response_expected"   , type = IDL.boolean       },
		{name = "object_key"          , type = IDL.OctetSeq      },
		{name = "operation"           , type = IDL.string        },
		{name = "requesting_principal", type = IDL.OctetSeq      },
	},
	[ReplyID] = IDL.struct{
		{name = "service_context", type = ServiceContextList },
		{name = "request_id"     , type = IDL.ulong          },
		{name = "reply_status"   , type = ReplyStatusType_1_0},
	},
	[CancelRequestID] = IDL.struct{
		{name = "request_id", type = IDL.ulong},
	},
	[LocateRequestID] = IDL.struct{
		{name = "request_id", type = IDL.ulong   },
		{name = "object_key", type = IDL.OctetSeq},
	},
	[LocateReplyID] = IDL.struct{
		{name = "request_id"   , type = IDL.ulong           },
		{name = "locate_status", type = LocateStatusType_1_0},
	},
	[CloseConnectionID] = false, -- empty header
	[MessageErrorID   ] = false, -- empty header
}

--------------------------------------------------------------------------------

MessageHeader_v1_[1] = { -- GIOP 1.1
	[RequestID] = IDL.struct{
		{name = "service_context"     , type = ServiceContextList              },
		{name = "request_id"          , type = IDL.ulong                       },
		{name = "response_expected"   , type = IDL.boolean                     },
		{name = "reserved"            , type = IDL.array{IDL.octet; length = 3}},
		{name = "object_key"          , type = IDL.OctetSeq                    },
		{name = "operation"           , type = IDL.string                      },
		{name = "requesting_principal", type = IDL.OctetSeq                    },
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

local ReplyStatusType_1_2 = IDL.enum{
	"NO_EXCEPTION", "USER_EXCEPTION", "SYSTEM_EXCEPTION", "LOCATION_FORWARD",
	"LOCATION_FORWARD_PERM", "NEEDS_ADDRESSING_MODE",
}
local LocateStatusType_1_2 = IDL.enum{
	"UNKNOWN_OBJECT", "OBJECT_HERE", "OBJECT_FORWARD",
	"OBJECT_FORWARD_PERM", "LOC_SYSTEM_EXCEPTION", "LOC_NEEDS_ADDRESSING_MODE",
}

local IORAddressingInfo = IDL.struct{
	{type = IDL.ulong, name = "selected_profile_index"},
	{type = IOR      , name = "ior"                   },
}
local TargetAddress = IDL.union{
	switch = IDL.short,     
	options = {             
		{label = 0, name = "object_key", type = IDL.OctetSeq     },
		{label = 1, name = "profile"   , type = TaggedProfile    },
		{label = 2, name = "ior"       , type = IORAddressingInfo},
	}
}

MessageHeader_v1_[2] = { -- GIOP 1.2
	[RequestID] = IDL.struct{
		{name = "request_id"     , type = IDL.ulong                       },
		{name = "response_flags" , type = IDL.octet                       },
		{name = "reserved"       , type = IDL.array{IDL.octet; length = 3}},
		{name = "target"         , type = TargetAddress                   },
		{name = "operation"      , type = IDL.string                      },
		{name = "service_context", type = ServiceContextList              },
	},
	[ReplyID] = IDL.struct{
		{name = "request_id"     , type = IDL.ulong          },
		{name = "reply_status"   , type = ReplyStatusType_1_2},
		{name = "service_context", type = ServiceContextList },
	},
	[CancelRequestID] = MessageHeader_v1_[1][CancelRequestID],
	[LocateRequestID] = IDL.struct{
		{name = "request_id", type = IDL.ulong    },
		{name = "target"    , type = TargetAddress},
	},
	[LocateReplyID] = IDL.struct{
		{name = "request_id"   , type = IDL.ulong           },
		{name = "locate_status", type = LocateStatusType_1_2},
	},
	[CloseConnectionID] = MessageHeader_v1_[1][CloseConnectionID],
	[MessageErrorID   ] = MessageHeader_v1_[1][MessageErrorID   ],
	[FragmentID       ] = MessageHeader_v1_[1][FragmentID       ],
}

--------------------------------------------------------------------------------

MessageHeader_v1_[3] = MessageHeader_v1_[2] -- GIOP 1.3, same as GIOP 1.2
