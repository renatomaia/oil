local pcall = pcall

local oil = require "oil"
local oo = require "oil.oo"
local assert = require "oil.assert"
local ArrayedSet = require "loop.collection.ArrayedSet"
local ProxyPushSupplier = require "oil.corba.services.event.ProxyPushSupplier"

local ConsumerAdmin = oo.class()

function ConsumerAdmin.__new(class, channel)
  return oo.rawnew(class, {
    channel = channel,
    proxypushsuppliers = ArrayedSet()
  })
end

-- The obtain_push_supplier operation returns a ProxyPushSupplier object. The
-- ProxyPushSupplier object is then used to connect a push-style consumer.

function ConsumerAdmin:obtain_push_supplier()
  return ProxyPushSupplier(self)
end

-- invoked by ProxyPushSupplier to signal it's connected

function ConsumerAdmin:add_push_consumer(proxy, push_consumer)
  self.proxypushsuppliers:add(proxy)
  self.channel:add_push_consumer(push_consumer)
end

-- invoked by ProxyPushSupplier to signal it's disconnected

function ConsumerAdmin:rem_push_consumer(proxy, push_consumer)
  assert.results(self.proxypushsuppliers:contains(proxy))
  self.proxypushsuppliers:remove(proxy)
  self.channel:rem_push_consumer(push_consumer)
end

-- invoked by the channel to disconnect all proxies of the admin.
-- must reverse iterate over proxypushsuppliers because the disconnection
-- removes the consumer from the array.

function ConsumerAdmin:destroy()
  for i=#self.proxypushsuppliers,1,-1 do
    local proxy = self.proxypushsuppliers[i]
    pcall(proxy.disconnect_push_supplier, proxy) 
  end
  self.proxypushsuppliers = nil
  self.channel = nil
end

return ConsumerAdmin
