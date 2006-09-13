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
-- Title  : No priority queue for the Event Service                           --
-- Authors: Leonardo S. A. Maciel <leonardo@maciel.org>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   __init([props])                                                          --
--   length                                                                   --
--   enqueue(event)                                                           --
--   iterator                                                                 --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--------------------------------------------------------------------------------

local require    = require
local oo         = require "loop.base"

module("oil.cos.event.Queue", oo.class)                                         --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local os         = require "os"
local assert     = require "oil.assert"
local Properties = require "oil.properties"

--------------------------------------------------------------------------------
-- Key constants ---------------------------------------------------------------

local QITERS  = "QITERS"
local NEXT    = "NEXT"

--------------------------------------------------------------------------------
-- Configuration Properties ----------------------------------------------------

-- @field PROP_MAX_QUEUE_LENGTH number Maximum number of events that can be
-- queued before queue starts rejecting new events. Defaults to 0, which means 
-- unlimited length.
-- @field PROP_MAX_EVENTS_PER_CONSUMER number Maximum number of events that
-- can be in queue for a given proxy. The default value is 0, which disables
-- this property.


PROP_MAX_QUEUE_LENGTH = "oil.cos.event.max_queue_length"
PROP_MAX_EVENTS_PER_CONSUMER = "oil.cos.event.max_events_per_consumer"

--------------------------------------------------------------------------------
-- EventQueueIterator implementation -------------------------------------------

-- This class should be used by event dispatchers to keep track of the current
-- event to be sent. Every time an event is successfully sent dispatchers
-- should flag them as sent by advancing the iterator. Also when a dispatcher
-- is no longer active, it should destroy this object by invoking the destroy
-- method. By following these simple rules we can guarantee optimal usage of the
-- event queue.

-- @see EventQueue

local EventQueueIterator = oo.class()

-- @param queue table EventQueue that instantiated this object.

function EventQueueIterator:__init(queue)                                       --[[VERBOSE]] verbose.server({"EventQueueIterator:__init ", "entering"})
    return oo.rawnew(self, {
                            queue = queue,
                            last = queue.last,
                            idle_since = os.time(),
                           })
end

-- @return 1 table Current event to be sent or nil if no events in queue.

function EventQueueIterator:current()                                           --[[VERBOSE]] verbose.server({"EventQueueIterator:current ", "entering"})
    return self.last[NEXT]
end

-- flags the current event as sent.
-- @return 1 table Next event to be sent or nil if no events in queue.

function EventQueueIterator:advance()                                           --[[VERBOSE]] verbose.server({"EventQueueIterator:advance ", "entering"})
    local next = self.last[NEXT]
    self.queue:flag_as_sent(next)
    self.last = next
    self.idle_since = os.time()
    return next[NEXT]
end

-- flags all pending events as sent and unregisters this proxy from the queue.
function EventQueueIterator:destroy()                                           --[[VERBOSE]] verbose.server({"EventQueueIterator:destroy ", "entering"})
    local queue = self.queue
    local next = self.last[NEXT]
    while next do
        queue:flag_as_sent(next)
        next = next[NEXT]
    end
    queue.qiters = queue.qiters - 1
    self.idle_since = nil
    self.queue = nil
    self.last = nil
end

--------------------------------------------------------------------------------
-- EventQueue implementation ---------------------------------------------------

-- This class implements a no priority event queue to be used by EventChannel's.

-- @usage EventQueue = require "oil.cos.event.queue"
--        Properties = require "oil.properties"
--        props = Properties()
--        props[EventQueue.PROP_MAX_QUEUE_LENGTH] = 3
--        queue = EventQueue(props)                                            .

-- @see Properties
-- @see EventChannel

local dummyevent = {
                    [QITERS] = 0,
                    [NEXT] = nil,
                   }

-- @param props table [optional] Configuration properties.

function __init(self, props)                                                    --[[VERBOSE]] verbose.server({"EventQueue:__init ", "entering"})
    local props = Properties(props, {
                                     [PROP_MAX_QUEUE_LENGTH] = 0,
                                     [PROP_MAX_EVENTS_PER_CONSUMER] = 0,
                                    })
    return oo.rawnew(self, {
                            first = dummyevent,
                            last = dummyevent,
                            qiters = 0,
                            length = 0,
                            props = props,
                           })
end

-- Since this is a no priority queue, inserts element at the end of the queue.
-- If the queue is full, a CORBA IMPL_LIMIT exception is raised.
-- Note that if there are no EventQueueProxy's registered in this queue, we
-- don't bother adding it to the queue.

-- @param event table Event to be queued.

function enqueue(self, event)                                                   --[[VERBOSE]] verbose.server({"EventQueue:enqueue ", "entering"})
    if self.qiters > 0 then
        local max_queue_length = self.props[PROP_MAX_QUEUE_LENGTH]
        if max_queue_length and self.length >= max_queue_length and
           max_queue_length > 0
             then return--assert.raise{"IDL:omg.org/CORBA/IMPL_LIMIT:1.0"}
        end
        event[QITERS] = self.qiters
        self.last[NEXT] = event
        self.last = event
        self.length = self.length + 1
    end
end

-- @return 1 table EventQueueIterator for this EventQueue.

function iterator(self)                                                         --[[VERBOSE]] verbose.server({"EventQueue:iterator ", "entering"})
    self.qiters = self.qiters + 1
    return EventQueueIterator(self)
end

-- protected

function flag_as_sent(self, event)
    event[QITERS] = event[QITERS] - 1
    if event[QITERS] == 0 then
        self.length = self.length - 1                                           --[[VERBOSE]] verbose.server({"EventQueue:flag_as_sent ", "length ", self.length})
        self.first = event
    end
end

