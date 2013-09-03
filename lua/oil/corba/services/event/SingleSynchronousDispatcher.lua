local oil             = require "oil"
local oo              = require "oil.oo"
local assert          = require "oil.assert"
local pairs           = pairs
local pcall           = pcall

local SingleSynchronousDispatcher = oo.class()

local function dispatch(consumer, event)
  local b,e = pcall(consumer.push, consumer, event.data)
  assert.results(b)
end

function SingleSynchronousDispatcher.__new(class, event_queue, consumers)
  assert.type(event_queue, "table")
  local self = oo.rawnew(class, {
    event_queue = event_queue,
    consumers = consumers or {},
  })
  oil.newthread(self.run, self)
  return self
end

function SingleSynchronousDispatcher:add_consumer(push_consumer)
  self.consumers[push_consumer] = true
end

function SingleSynchronousDispatcher:rem_consumer(push_consumer)
  self.consumers[push_consumer] = nil
end

function SingleSynchronousDispatcher:run()
  while true do
    local e = self.event_queue:dequeue()
    for c in pairs(self.consumers) do
      dispatch(c, e)
    end
  end
end

return SingleSynchronousDispatcher
