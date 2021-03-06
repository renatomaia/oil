local pcall = pcall

local oil               = require "oil"
local oo                = require "oil.oo"
local assert            = require "oil.assert"
local UnorderedArrayedSet = require "loop.collection.ArrayedSet"
local ProxyPushConsumer = require "oil.corba.services.event.ProxyPushConsumer"

local SupplierAdmin = oo.class()

function SupplierAdmin.__new(class, channel)
  return oo.rawnew(class, {
    channel = channel,
    proxypushconsumers = UnorderedArrayedSet()
  })
end

-- The obtain_push_consumer operation returns a ProxyPushConsumer object.
-- The ProxyPushConsumer object is then used to connect a push-style supplier.

function SupplierAdmin:obtain_push_consumer()
  return ProxyPushConsumer(self)
end

-- invoked by ProxyPushConsumer to signal it's connected

function SupplierAdmin:add_push_supplier(proxy, push_supplier)
  self.proxypushconsumers:add(proxy)
  self.channel:add_push_supplier(push_supplier)
end

-- invoked by ProxyPushConsumer to signal it's connected

function SupplierAdmin:rem_push_supplier(proxy, push_supplier)
  assert.results(self.proxypushconsumers:contains(proxy))
  self.proxypushconsumers:remove(proxy)
  self.channel:rem_push_supplier(push_supplier)
end

-- invoked by the channel to disconnect all proxies of the admin
-- must reverse iterate over proxypushconsumers because the disconnection
-- removes the supplier from the array.

function SupplierAdmin:destroy()
  for i=#self.proxypushconsumers,1,-1 do
    local proxy = self.proxypushconsumers[i]
    pcall(proxy.disconnect_push_consumer, proxy)
  end
  self.proxypushconsumers = nil
  self.channel = nil
end

return SupplierAdmin
