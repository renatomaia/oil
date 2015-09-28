-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Server-side CORBA GIOP Protocol
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                       --[[VERBOSE]] local verbose = require "oil.verbose"
local assert = _G.assert
local ipairs = _G.ipairs
local pairs = _G.pairs
local pcall = _G.pcall
local select = _G.select
local tostring = _G.tostring
local type = _G.type

local array = require "table"
local unpack = array.unpack

local table = require "loop.table"
local memoize = table.memoize

local oo = require "oil.oo"
local class = oo.class

local idl = require "oil.corba.idl"

local giop = require "oil.corba.giop"
local RequestID = giop.RequestID
local ReplyID = giop.ReplyID
local LocateRequestID = giop.LocateRequestID
local LocateReplyID = giop.LocateReplyID
local CancelRequestID = giop.CancelRequestID
local MessageErrorID = giop.MessageErrorID
local MessageType = giop.MessageType
local SystemExceptionIDs = giop.SystemExceptionIDs

local Exception = require "oil.corba.giop.Exception"
local Listener = require "oil.protocol.Listener"

local GIOPListener = class({}, Listener)

function GIOPListener:addbidirchannel(channel)                                --[[VERBOSE]] verbose:listen("add bidirectional channel as incoming request channel")
	self:getaccess():register(channel)
end

return GIOPListener
