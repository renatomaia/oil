-- Project: OiL - ORB in Lua
-- Release: 0.6
-- Title  : Factory of outgoing (client-side) channels
-- Authors: Renato Maia <maia@inf.puc-rio.br>


local _G = require "_G"                                                         --[[VERBOSE]] local verbose = require "oil.verbose"
local pairs = _G.pairs

local coroutine = require "coroutine"
local running = coroutine.running
local yield = coroutine.yield

local oo = require "oil.oo"
local class = oo.class

local Connector = require "oil.kernel.base.Connector"
local connectto = Connector.connectto

local CoConnector = class({}, Connector)

function CoConnector:__init()
	self.pending = {}
end

function CoConnector:connectto(connid, ...)
	if connid == nil then return nil, (...) end
	local pending = self.pending
	local threads = pending[connid]
	if threads ~= nil then                                                        --[[VERBOSE]] verbose:channels("connection to channel in progress, wait completion")
		threads[running()] = true
		return yield("suspend")
	end
	threads = {}
	pending[connid] = threads
	local socket, except = connectto(self, connid, ...)
	pending[connid] = nil
	for thread in pairs(threads) do
		yield("next", thread, socket, except)
	end
	return socket, except
end

return CoConnector
