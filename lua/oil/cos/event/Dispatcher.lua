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
-- Title  : Event dispatcher for the Event Service                            --
-- Authors: Leonardo S. A. Maciel <leonardo@maciel.org>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   enqueue(event)                                                           --
--   addConsumer(consumer)                                                    --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--------------------------------------------------------------------------------

local scheduler = scheduler
local require   = require
local oo        = require "loop.base"

module("oil.cos.event.Dispatcher", oo.class)                                    --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local os              = require "os"
local oo              = require "loop.base"
local Properties      = require "oil.properties"
local EventQueue      = require "oil.cos.event.Queue"
local OrderedSet      = require "loop.collection.OrderedSet"

--------------------------------------------------------------------------------
-- Key constants ---------------------------------------------------------------

local QITER   = "QITER"
local THREAD  = "THREAD"
local DATA    = "DATA"

--------------------------------------------------------------------------------
-- Configuration properties ----------------------------------------------------

-- @field PROP_MAX_RETRIES number Maximum number of retries before disconnecting
-- the proxy. The default value is 3. The value 0 disables this property.
-- @field PROP_RETRY_TIMEOUT number Initial number of seconds to wait between
-- each successive retry. The default value is 1.
-- @field PROP_RETRY_MULTIPLIER number Factor by which the retry timeout
-- should be multiplied for each successive retry. The default value is 2.0.
-- @field PROP_MAX_RETRY_TIMEOUT number Maximum number of seconds to wait 
-- between each successive retry. The default value is 60. The value 0 disables 
-- this property.

PROP_MAX_RETRIES             = "oil.cos.event.max_retries"
PROP_RETRY_TIMEOUT           = "oil.cos.event.retry_timeout"
PROP_RETRY_MULTIPLIER        = "oil.cos.event.retry_multiplier"
PROP_MAX_RETRY_TIMEOUT       = "oil.cos.event.max_retry_timeout"

--------------------------------------------------------------------------------
-- EventDispatcherThread implementation ----------------------------------------

local EventDispatcherThread = oo.class()

-- @param props table [optional] Properties instance.

function EventDispatcherThread:__init(dispatcher)                               --[[VERBOSE]] verbose.server({"EventDispatcherThread:__init ", "entering."})
    return oo.rawnew(self, {
                            dispatcher = dispatcher,
                            max_retries = dispatcher.props[PROP_MAX_RETRIES],
                            max_retry_timeout = dispatcher.props[PROP_MAX_RETRY_TIMEOUT],
                            retry_multiplier = dispatcher.props[PROP_RETRY_MULTIPLIER],
                            retry_timeout = dispatcher.props[PROP_RETRY_TIMEOUT],
                           })
end

function EventDispatcherThread:wait()                                           --[[VERBOSE]] verbose.server({"EventDispatcherThread:wait ", "entering."})
    self.dispatcher:waiting(self)
    scheduler.sleep()
end

-- @param proxy table ProxyPushSupplier instance.

function EventDispatcherThread:setProxy(proxy)                                  --[[VERBOSE]] verbose.server({"EventDispatcherThread:setProxy ", "entering."})
    self.proxy = proxy
    self.qiter = proxy[QITER]
    self.consumer = proxy.push_consumer
end

function EventDispatcherThread:pending()                                        --[[VERBOSE]] verbose.server({"EventDispatcherThread:pending ", "entering. ", scheduler:current()})
    self.current = self.qiter:current()
    return self.current
end

function EventDispatcherThread:step()                                           --[[VERBOSE]] verbose.server({"EventDispatcherThread:step ", "entering. ", scheduler:current()})
    local consumer = self.consumer
    local max_retry_timeout = self.max_retry_timeout
    local max_retries = self.max_retries
    local retry_timeout = self.retry_timeout
    local retry_multiplier = self.retry_multiplier
    local retries = 0
    local success, except
    repeat
        success, except = scheduler.pcall(consumer.push,
                                          consumer,
                                          self.current[DATA])
        if not success then
            retries = retries + 1                                               --[[VERBOSE]] verbose.server({"EventDispatcherThread:step ", "push failed. ", retries, " times ", scheduler:current()})
            if max_retries > 0 and retries > max_retries then                   --[[VERBOSE]] verbose.server({"EventDispatcherThread:step ", "giving up. ", scheduler:current()})
                return false
            else                                                                --[[VERBOSE]] verbose.server({"EventDispatcherThread:step ", "sleeping for ", retry_timeout, " secs before retry. ", scheduler:current()})
                scheduler.sleep(retry_timeout)
                if retry_timeout > max_retry_timeout
                    then retry_timeout = max_retry_timeout
                    else retry_timeout = retry_timeout * retry_multiplier
                end
            end
        end
    until success                                                               --[[VERBOSE]] verbose.server({"EventDispatcherThread:step ", "push successful. ", retries, " retries ", scheduler:current()})
    return true
end

function EventDispatcherThread:run()                                            --[[VERBOSE]] verbose.server({"EventDispatcherThread:run ", "entering. ", scheduler:current()})
    self.thread = scheduler:current()
    while self.thread do
        self:wait()
        while self.thread and self:pending() do
            if self:step() then
                if self.thread then self.qiter:advance() end
            else
                self.proxy:disconnect_push_supplier()
                break
            end
        end
    end                                                                         --[[VERBOSE]] verbose.server({"EventDispatcherThread:run ", "leaving. ", scheduler:current()})
end

function EventDispatcherThread:destroy()                                        --[[VERBOSE]] verbose.server({"EventDispatcherThread:destroy ", "entering. ", self.thread})
    scheduler.wake(self.thread)
    self.thread = nil
end

--------------------------------------------------------------------------------
-- Dispatcher implementation ---------------------------------------------------

-- @param props table [optional] Properties instance.

function __init(self, props)                                                    --[[VERBOSE]] verbose.server({"EventDispatcher:__init ", "entering."})
    local props = Properties(props, {
                                     [PROP_RETRY_TIMEOUT]           = 1,
                                     [PROP_RETRY_MULTIPLIER]        = 2.0,
                                     [PROP_MAX_RETRY_TIMEOUT]       = 60,
                                     [PROP_MAX_RETRIES]             = 3,
                                    })
    return oo.rawnew(self, {
                            props = props,
                            queue = EventQueue(props),
                            waiting_pool = OrderedSet(),
                            running_pool = OrderedSet(),
                           })
end

function notify(self, thread)                                                   --[[VERBOSE]] verbose.server({"EventDispatcher:notify ", "entering."})
    waiting_pool:remove(thread)
    running_pool:add(thread)
    scheduler.wake(thread.thread)
end

function notifyAll(self)                                                        --[[VERBOSE]] verbose.server({"EventDispatcher:notifyAll ", "entering."})
    local waiting_pool = self.waiting_pool
    local running_pool = self.running_pool
    local thread = waiting_pool:pop()
    while thread do
        running_pool:add(thread)
        scheduler.wake(thread.thread)
        thread = waiting_pool:pop()
    end
end

function waiting(self, thread)                                                  --[[VERBOSE]] verbose.server({"EventDispatcher:waiting ", "entering."})
    self.running_pool:remove(thread)
    self.waiting_pool:add(thread)
end

function addEvent(self, event)                                                  --[[VERBOSE]] verbose.server({"EventDispatcher:addEvent ", "entering."})
    self.queue:enqueue(event)
    self:notifyAll()
end

function addThread(self)                                                        --[[VERBOSE]] verbose.server({"EventDispatcher:addThread ", "entering."})
    local thread = EventDispatcherThread(self)
    self.running_pool:add(thread)
    scheduler.new(thread.run, thread)
    return thread
end

function addConsumerProxy(self, proxy)                                          --[[VERBOSE]] verbose.server({"EventDispatcher:addConsumerProxy ", "entering."})
    local thread = self:addThread()
    proxy[QITER] = self.queue:iterator()
    proxy[THREAD] = thread
    thread:setProxy(proxy)
end

function remConsumerProxy(self, proxy)                                          --[[VERBOSE]] verbose.server({"EventDispatcher:remConsumerProxy ", "entering."})
    self.waiting_pool:remove(proxy[THREAD])
    self.running_pool:remove(proxy[THREAD])
    proxy[THREAD]:destroy()
    proxy[THREAD] = nil
    proxy[QITER]:destroy()
    proxy[QITER] = nil
end

