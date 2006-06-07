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
-- Title  : Event Service                                                     --
-- Authors: Leonardo S. A. Maciel <leonardo@maciel.org>                       --
--------------------------------------------------------------------------------
-- Interface:                                                                 --
--   new() Creates a new instance of a CORBA Event Channel                    --
--------------------------------------------------------------------------------
-- Notes:                                                                     --
--   This implementation currently does not support typed events.             --
--   This implementation currently does not support pull event model.         --
--------------------------------------------------------------------------------

local require   = require
local loadidl   = oil.loadidl
local scheduler = scheduler

module "oil.cos.event"                                                          --[[VERBOSE]] local verbose = require "oil.verbose"

--------------------------------------------------------------------------------
-- Dependencies ----------------------------------------------------------------

local os              = require "os"
local oo              = require "loop.base"
local assert          = require "oil.assert"
local Properties      = require "oil.properties"
local EventReaper     = require "oil.cos.event.Reaper"
local EventFactory    = require "oil.cos.event.Factory"
local EventDispatcher = require "oil.cos.event.Dispatcher"
local OrderedSet      = require "loop.collection.OrderedSet"

--------------------------------------------------------------------------------
-- Key constants ---------------------------------------------------------------

--------------------------------------------------------------------------------
-- Configuration properties ----------------------------------------------------

-- @field PROP_MAX_CONSUMERS number Maximum number of simultaneous consumers
-- allowed in the channel. The default value is 0, which disables this property.
-- @field PROP_MAX_SUPPLIERS number Maximum number of simultaneous suppliers 

PROP_MAX_CONSUMERS           = "oil.cos.event.max_consumers"
PROP_MAX_SUPPLIERS           = "oil.cos.event.max_suppliers"

--------------------------------------------------------------------------------
-- ProxyPushConsumer interface implementation ----------------------------------

local ProxyPushConsumer = oo.class()

function ProxyPushConsumer:__init(admin)                                        --[[VERBOSE]] verbose.server({"ProxyPushConsumer:__init ", "entering"})
    return oo.rawnew(self, {
                            admin = admin,
                            connected = false,
                            push_supplier = nil,
                            idle_since = os.time(),
                           })
end

function ProxyPushConsumer:push(data)                                           --[[VERBOSE]] verbose.server({"ProxyPushConsumer:push ", "entering"})
    if not self.connected then
        assert.raise{"IDL:omg.org/CosEventComm/Disconnected:1.0"}
    end
    local event = self.admin.channel.factory:create(data)
    self.admin.channel:addEvent(event)
    self.idle_since = os.time()
end

function ProxyPushConsumer:connect_push_supplier(push_supplier)                 --[[VERBOSE]] verbose.server({"ProxyPushConsumer:connect_push_supplier ", "entering"})
    if self.connected then
        assert.raise{"IDL:omg.org/CosEventChannelAdmin/AlreadyConnected:1.0"}
    end
    self.push_supplier = push_supplier
    self.admin:addProxy(self)
    self.connected = true
    self.idle_since = os.time()
end

function ProxyPushConsumer:disconnect_push_consumer()                           --[[VERBOSE]] verbose.server({"ProxyPushConsumer:disconnect_push_consumer ", "entering"})
    if not self.connected then
        assert.raise{"IDL:omg.org/CORBA/OBJECT_NOT_EXIST:1.0"}
    elseif self.push_supplier then
        scheduler.pcall(self.push_supplier.disconnect_push_supplier,
                        self.push_supplier)
        self.push_supplier = nil
    end
    self.admin:remProxy(self)
    self.connected = false
end

--------------------------------------------------------------------------------
-- ProxyPushSupplier interface implementation ----------------------------------

local ProxyPushSupplier = oo.class()

function ProxyPushSupplier:__init(admin)                                        --[[VERBOSE]] verbose.server({"ProxyPushSupplier:__init ", "entering"})
    return oo.rawnew(self, {
                            admin = admin,
                            connected = false,
                            push_consumer = nil,
                           })
end

function ProxyPushSupplier:connect_push_consumer(push_consumer)                 --[[VERBOSE]] verbose.server({"ProxyPushSupplier:connect_push_consumer ", "entering"})
    if self.connected then
        assert.raise{"IDL:omg.org/CosEventChannelAdmin/AlreadyConnected:1.0"}
    elseif not push_consumer then
        assert.raise{"IDL:omg.org/CORBA/BAD_PARAM:1.0"}
    elseif not push_consumer:_is_a("IDL:omg.org/CosEventComm/PushConsumer:1.0")
        then assert.raise{"IDL:omg.org/CosEventChannelAdmin/TypeError:1.0"}
    end
    self.push_consumer = push_consumer
    self.admin:addProxy(self)
    self.connected = true
end

function ProxyPushSupplier:disconnect_push_supplier()                           --[[VERBOSE]] verbose.server({"ProxyPushSupplier:disconnect_push_supplier ", "entering"})
    if not self.connected then
        assert.raise{"IDL:omg.org/CORBA/OBJECT_NOT_EXIST:1.0"}
    elseif self.push_consumer then
        scheduler.pcall(self.push_consumer.disconnect_push_consumer,
                        self.push_consumer)
        self.push_consumer = nil
    end
    self.admin:remProxy(self)
    self.connected = false
end

--------------------------------------------------------------------------------
-- ConsumerAdmin interface implementation --------------------------------------

--The ConsumerAdmin interface allows consumers to be connected to the event
--channel.

local ConsumerAdmin = oo.class()

function ConsumerAdmin:__init(channel, props)                                   --[[VERBOSE]] verbose.server({"ConsumerAdmin:__init ", "entering"})
    return oo.rawnew(self, {
                            channel = channel,
                            props = props,
                            proxies = OrderedSet(),
                           })
end

function ConsumerAdmin:addProxy(proxy)                                          --[[VERBOSE]] verbose.server({"ConsumerAdmin:addProxy ", "entering"})
    self.channel:addConsumerProxy(proxy)
    self.proxies:add(proxy)
end

function ConsumerAdmin:remProxy(proxy)                                          --[[VERBOSE]] verbose.server({"ConsumerAdmin:remProxy ", "entering"})
    self.channel:remConsumerProxy(proxy)
    self.proxies:remove(proxy)
end

function ConsumerAdmin:destroy()                                                --[[VERBOSE]] verbose.server({"ConsumerAdmin:destroy ", "entering"})
    if self._deactivate then self:_deactivate() end
    local proxy = self.proxies:pop()
    while proxy do
        proxy:disconnect_push_supplier()
        proxy = self.proxies:pop()
    end
end

-- The obtain_push_supplier operation returns a ProxyPushSupplier object. The
-- ProxyPushSupplier object is then used to connect a push-style consumer.

function ConsumerAdmin:obtain_push_supplier()                                   --[[VERBOSE]] verbose.server({"ConsumerAdmin:obtain_push_supplier ", "entering"})
    return ProxyPushSupplier(self, self.props)
end

--------------------------------------------------------------------------------
-- SupplierAdmin interface implementation --------------------------------------

--The SupplierAdmin interface allows suppliers to be connected to the event
--channel.

local SupplierAdmin = oo.class()

function SupplierAdmin:__init(channel, props)                                   --[[VERBOSE]] verbose.server({"SupplierAdmin:__init ", "entering"})
    return oo.rawnew(self, {
                            channel = channel,
                            props = props,
                            proxies = OrderedSet(),
                           })
end

function SupplierAdmin:addProxy(proxy)                                          --[[VERBOSE]] verbose.server({"SupplierAdmin:addProxy ", "entering"})
    self.channel:addSupplierProxy(proxy)
    self.proxies:add(proxy)
end

function SupplierAdmin:remProxy(proxy)                                          --[[VERBOSE]] verbose.server({"SupplierAdmin:remProxy ", "entering"})
    self.channel:remSupplierProxy(proxy)
    self.proxies:remove(proxy)
end

function SupplierAdmin:destroy()                                                --[[VERBOSE]] verbose.server({"SupplierAdmin:destroy ", "entering"})
    if self._deactivate then self:_deactivate() end
    local proxy = self.proxies:pop()
    while proxy do
        proxy:disconnect_push_consumer()
        proxy = self.proxies:pop()
    end
end

--The obtain_push_supplier operation returns a ProxyPushConsumer object. The
--ProxyPushConsumer object is then used to connect a push-style supplier.

function SupplierAdmin:obtain_push_consumer()                                   --[[VERBOSE]] verbose.server({"SupplierAdmin:obtain_push_consumer ", "entering"})
    return ProxyPushConsumer(self, self.props)
end

--------------------------------------------------------------------------------
-- EventChannel interface implementation ---------------------------------------

local EventChannel = oo.class()

-- @param props table [optional] Properties instance.

function EventChannel:__init(props)                                             --[[VERBOSE]] verbose.server({"EventChannel:__init ", "entering"})
    local props = Properties(props, {
                                     [PROP_MAX_CONSUMERS]           = 0,
                                     [PROP_MAX_SUPPLIERS]           = 0,
                                    })
    self = oo.rawnew(self, {
                            props = props,
                            dispatcher = EventDispatcher(props),
                            factory = EventFactory(props),
                            reaper = EventReaper(props),
                            consumer_count = 0,
                            supplier_count = 0,
                           })
    self.consumer_admin = ConsumerAdmin(self)
    self.supplier_admin = SupplierAdmin(self)
    scheduler.new(self.reaper.run, self.reaper)
    return self
end

-- @return 1 table Reference to an object that supports the ConsumerAdmin
-- interface.

function EventChannel:for_consumers()                                           --[[VERBOSE]] verbose.server({"EventChannel:for_consumers ", "entering"})
    return self.consumer_admin
end

-- @return 1 table Reference to object that supports the SupplierAdmin
-- interface.

function EventChannel:for_suppliers()                                           --[[VERBOSE]] verbose.server({"EventChannel:for_suppliers ", "entering"})
    return self.supplier_admin
end

function EventChannel:addConsumerProxy(proxy)                                   --[[VERBOSE]] verbose.server({"EventChannel:addConsumerProxy ", "entering"})
    local max_consumers = self.props[PROP_MAX_CONSUMERS]
    if max_consumers > 0 and self.consumer_count >= max_consumers 
        then assert.raise{"IDL:omg.org/CORBA/IMPL_LIMIT:1.0"}
        else self.consumer_count = self.consumer_count + 1
    end
    self.dispatcher:addConsumerProxy(proxy)
end

function EventChannel:remConsumerProxy(proxy)                                   --[[VERBOSE]] verbose.server({"EventChannel:remConsumerProxy ", "entering"})
    self.consumer_count = self.consumer_count - 1
    self.dispatcher:remConsumerProxy(proxy)
end

function EventChannel:addSupplierProxy(proxy)                                   --[[VERBOSE]] verbose.server({"EventChannel:addSupplierProxy ", "entering"})
    local max_suppliers = self.props[PROP_MAX_SUPPLIERS]
    if max_suppliers > 0 and self.supplier_count >= max_suppliers 
        then assert.raise{"IDL:omg.org/CORBA/IMPL_LIMIT:1.0"}
        else self.supplier_count = self.supplier_count + 1
    end
end

function EventChannel:remSupplierProxy(proxy)                                   --[[VERBOSE]] verbose.server({"EventChannel:remSupplierProxy ", "entering"})
    self.supplier_count = self.supplier_count - 1
end

function EventChannel:addEvent(event)                                           --[[VERBOSE]] verbose.server({"EventChannel:addEvent ", "entering"})
    self.dispatcher:addEvent(event)
end

--The destroy operation destroys the event channel. Destroying an event channel
--destroys all ConsumerAdmin and SupplierAdmin objects that were created via
--that channel. Destruction of a ConsumerAdmin or SupplierAdmin object causes
--the implementation to invoke the disconnect operation on all proxies that were
--created via that ConsumerAdmin or SupplierAdmin object.

function EventChannel:destroy()                                                 --[[VERBOSE]] verbose.server({"EventChannel:destroy ", "entering"})
    if self._deactivate then self:_deactivate() end
    self.supplier_admin:destroy()
    self.supplier_admin = nil
    self.supplier_count = nil
    self.consumer_admin:destroy()
    self.consumer_admin = nil
    self.consumer_count = nil
    self.reaper:destroy()
    self.reaper = nil
    self.dispatcher = nil
    self.factory = nil
    self.queue = nil
    self.props = nil
end

--------------------------------------------------------------------------------
-- Creates a new instance of a CORBA Event Channel -----------------------------

-- @param props table [optional] Properties instance.

-- @return 1 table CORBA object which is an untyped Event Channel.
-- @return 2 string Repository ID of interface supported by the Event Channel.
-- @return 3 string Default Event Channel object key.

function new(props)
    return EventChannel(props),
           "IDL:omg.org/CosEventChannelAdmin/EventChannel:1.0",
           "DefaultEventChannel"
end

